const std = @import("std");
const cli = @import("../commands/cli");
const watcher = @import("watcher");
const parser_mod = @import("../parser/mod.zig");
const typescript = @import("../parser/typescript.zig");
const flow = @import("core/flow");

const WatchContext = struct {
    parser: *parser_mod.Parser, // Use generic parser interface
    flow_graph: *flow.FlowGraph,
    config: *const cli.Config,
    verbose: bool,
    source_files: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, config: *const cli.Config) !*WatchContext {
        var ctx = try allocator.create(WatchContext);
        errdefer allocator.destroy(ctx);

        const ts_parser_impl = try typescript.TypeScriptParser.init(allocator);
        errdefer ts_parser_impl.deinit();
        // Initialize generic parser with TypeScript implementation
        ctx.parser = parser_mod.Parser.init(allocator, ts_parser_impl);
        errdefer ctx.parser.deinit();

        ctx.flow_graph = try flow.FlowGraph.init(allocator);
        ctx.config = config;
        ctx.verbose = config.verbose;
        ctx.source_files = std.ArrayList([]const u8).init(allocator);
        ctx.allocator = allocator;

        // Find all TypeScript files in source paths
        for (config.source_paths) |path| {
            try ctx.findTypeScriptFiles(path);
        }

        return ctx;
    }

    pub fn deinit(self: *WatchContext, allocator: std.mem.Allocator) void {
        for (self.source_files.items) |path| {
            allocator.free(path);
        }
        self.source_files.deinit();
        self.parser.deinit(); // Deinit generic parser, which will deinit the impl
        self.flow_graph.deinit();
        allocator.destroy(self);
    }

    fn findTypeScriptFiles(self: *WatchContext, path: []const u8) !void {
        const allocator = self.allocator;

        // First check if it's a TypeScript file
        if (std.mem.endsWith(u8, path, ".ts")) {
            const abs_path = try std.fs.cwd().realpathAlloc(allocator, path);
            try self.source_files.append(abs_path);
            return;
        }

        // Then try to open as directory
        var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".ts")) {
                const rel_path = try std.fs.path.join(allocator, &.{ path, entry.name });
                const abs_path = try std.fs.cwd().realpathAlloc(allocator, rel_path);
                allocator.free(rel_path);
                try self.source_files.append(abs_path);
            }
        }
    }

    pub fn handleFileChange(self: *WatchContext, event: watcher.WatchEvent) void {
        if (self.verbose) {
            std.debug.print("File changed: {s} ({s})\n", .{ event.path, @tagName(event.kind) });
        }

        // Skip if file was deleted
        if (event.kind == .delete) return;

        // Re-parse all files on any change
        // Create a new TypeScript parser instance
        const ts_parser_impl = typescript.TypeScriptParser.init(self.allocator) catch |err| {
            std.debug.print("Error creating TypeScript parser: {s}\n", .{@errorName(err)});
            return;
        };
        defer ts_parser_impl.deinit();
        self.parser.deinit(); // Deinit old parser

        // Initialize generic parser with new TypeScript implementation
        self.parser = parser_mod.Parser.init(self.allocator, ts_parser_impl);

        // Clear and rebuild flow graph
        self.flow_graph.clear();

        // Parse and add nodes for each source file
        for (self.source_files.items) |path| {
            const file = std.fs.cwd().openFile(path, .{}) catch |err| {
                std.debug.print("Error opening file '{s}': {s}\n", .{ path, @errorName(err) });
                continue; // Skip to next file
            };
            defer file.close();
            const source = file.readAllAlloc(self.allocator, 1024 * 1024 * 10) catch |err| { // 10MB limit
                std.debug.print("Error reading file '{s}': {s}\n", .{ path, @errorName(err) });
                continue; // Skip to next file
            };
            defer self.allocator.free(source);

            const root_node = self.parser.parse(source) catch |err| {
                std.debug.print("Error parsing file '{s}': {s}\n", .{ path, @errorName(err) });
                continue; // Skip to next file
            };
            if (root_node == null) {
                std.debug.print("Error: Parsing file '{s}' returned null root node.\n", .{path});
                continue; // Skip to next file
            }
            self.flow_graph.addNode(root_node) catch |err| {
                std.debug.print("Error adding node to flow graph: {s}\n", .{@errorName(err)});
                root_node.deinit(); // Clean up node on error
                self.allocator.destroy(root_node);
                continue; // Skip to next file
            };
        }

        // Merge flows if target is specified
        if (self.config.target_path) |target| {
            self.flow_graph.mergeFlows(target) catch |err| {
                std.debug.print("Error merging flows to '{s}': {s}\n", .{ target, @errorName(err) });
                return;
            };
            if (self.verbose) {
                std.debug.print("Successfully merged to {s}\n", .{target});
            }
        }
    }
};

pub fn execute(allocator: std.mem.Allocator, config: *const cli.Config) !void {
    const stderr = std.io.getStdErr().writer();

    if (config.source_paths.len == 0) {
        try stderr.writeAll("Error: No source files or directories specified for watching\n\n");
        cli.printHelp();
        return error.NoSourcePaths;
    }

    if (config.target_path == null) {
        try stderr.writeAll("Error: No target file specified for merge. Use -t or --target option.\n\n");
        cli.printHelp();
        return error.NoTargetPath;
    }

    // Initialize watch context
    var ctx = try WatchContext.init(allocator, config);
    defer ctx.deinit(allocator);

    var w = try watcher.Watcher.init(allocator);
    defer w.deinit();

    // Set up file change callback
    const Callback = struct {
        // SAFETY: This is initialized before any callbacks are registered
        var context: *WatchContext = undefined;
        fn onFileChange(event: watcher.WatchEvent) void {
            context.handleFileChange(event);
        }
    };
    Callback.context = ctx;
    w.setCallback(Callback.onFileChange);

    // Do initial merge
    ctx.handleFileChange(.{ .path = "", .kind = .modify });

    const cwd = std.fs.cwd();
    for (config.source_paths) |rel_path| {
        // Convert relative path to absolute
        const abs_path = try cwd.realpathAlloc(allocator, rel_path);
        defer allocator.free(abs_path);

        try w.watch(abs_path);
        if (config.verbose) {
            std.debug.print("Watching {s}\n", .{abs_path});
        }
    }

    if (config.verbose) {
        std.debug.print("Starting file watcher with {d}ms delay\n", .{config.watch_delay_ms});
        std.debug.print("Press Ctrl+C to stop watching\n", .{});
    }

    // Start the watcher and wait for SIGINT
    try w.start();

    // Set up signal handler for graceful shutdown
    var running = true;
    const handler = struct {
        // SAFETY: This is initialized before the signal handler is registered
        var running_ptr: *bool = undefined;
        fn handle(_: c_int) callconv(.C) void {
            running_ptr.* = false;
        }
    };
    handler.running_ptr = &running;

    const act = std.posix.Sigaction{
        .handler = .{ .handler = handler.handle },
        .mask = std.posix.empty_sigset,
        .flags = 0,
    };
    try std.posix.sigaction(std.posix.SIG.INT, &act, null);

    while (running) {
        std.time.sleep(@as(u64, config.watch_delay_ms) * std.time.ns_per_ms);
    }

    if (config.verbose) {
        std.debug.print("\nStopping file watcher...\n", .{});
    }
    w.stop();
}
