const std = @import("std");
const ast_types = @import("core/ast/ast_types.zig");
const parser_mod = @import("parser/mod.zig");
const LanguageRegistry = @import("bindings/language.zig").LanguageRegistry;
const Logger = @import("utils/log.zig").Logger;
const Flow = @import("core/flow.zig").Flow;
const ProgressReporter = @import("utils/progress.zig").ProgressReporter;

const MergeRules = @import("core/merge/rules.zig").MergeRules;

pub const Project = struct {
    allocator: std.mem.Allocator,
    lang_registry: *LanguageRegistry,
    ast_root: *ast_types.Node,
    owned_nodes: std.ArrayList(*ast_types.Node),
    flow: *Flow,
    merge_rules: MergeRules,

    pub fn init(allocator: std.mem.Allocator, lang_registry: *LanguageRegistry) !Project {
        return .{
            .allocator = allocator,
            .lang_registry = lang_registry,
            .ast_root = try ast_types.Node.init(allocator, "root", .{ .base = .program, .custom_kind = null, .source = null }),
            .owned_nodes = std.ArrayList(*ast_types.Node).init(allocator),
            .flow = try Flow.init(allocator),
            .merge_rules = .{
                .preserve_comments = true,
                .sort_imports = true,
                .remove_redundancies = true,
                .optimize_import_paths = true,
            },
        };
    }

    pub fn initWithRules(allocator: std.mem.Allocator, lang_registry: *LanguageRegistry, merge_rules: MergeRules) !Project {
        var flow_instance = try Flow.initWithRules(allocator, merge_rules);

        return .{
            .allocator = allocator,
            .lang_registry = lang_registry,
            .ast_root = try ast_types.Node.init(allocator, "root", .{ .base = .program, .custom_kind = null, .source = null }),
            .owned_nodes = std.ArrayList(*ast_types.Node).init(allocator),
            .flow = flow_instance,
            .merge_rules = merge_rules,
        };
    }

    pub fn deinit(self: *Project) void {
        self.ast_root.deinit();
        for (self.owned_nodes.items) |node| {
            node.deinit();
            self.allocator.destroy(node);
        }
        self.owned_nodes.deinit();
        self.flow.deinit();
    }

    pub fn getNodes(self: *Project) []const *ast_types.Node {
        return self.owned_nodes.items;
    }

    pub fn parseFile(self: *Project, file_path: []const u8) !void {
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const max_size = 1024 * 1024 * 10; // 10MB limit
        if (file_size > max_size) {
            Logger.scoped(.Error, "project").err("File too large: {s} (max {})", .{ file_path, max_size });
            return error.FileSizeExceeded;
        }

        const source = try self.allocator.alloc(u8, @as(usize, @intCast(file_size)));
        // Source buffer ownership transferred to nodes

        const bytes_read = try file.readAll(source);
        if (bytes_read != source.len) {
            Logger.scoped(.Error, "project").err("Partial read of {s}: read {}/{} bytes", .{ file_path, bytes_read, source.len });
            std.debug.print("File read error: {s}\n", .{file_path});
            return error.FileReadError;
        }

        // Parse source using the generic parser interface
        var parser = parser_mod.Parser.init(self.allocator, self.lang_registry);
        defer parser.deinit();

        try parser.detectLanguage(source, file_path);
        const root_node = try parser.parse(source);
        try self.mergeAst(root_node);
    }

    fn mergeAst(self: *Project, new_node: *ast_types.Node) !void {
        // Add node to flow for dependency analysis
        try self.flow.nodes.append(new_node);

        // Existing merge logic adapted for language-aware nodes
        try self.ast_root.merge(new_node);
        try self.owned_nodes.append(new_node);
    }

    pub fn writeToFile(self: *Project, file_path: []const u8, progress_reporter: ?*ProgressReporter) !void {
        // Check if we have nodes in the flow graph
        if (self.flow.nodes.items.len > 0) {
            // Use topological sorting for dependency-based ordering
            Logger.scoped(.Info, "project").info("Using dependency-based ordering for output", .{});
            try self.flow.writeToFile(file_path, progress_reporter);
        } else {
            // Fallback to original serialization if no nodes in flow graph
            Logger.scoped(.Info, "project").info("Using standard serialization for output", .{});

            if (progress_reporter) |reporter| {
                reporter.update(reporter.current_step, "Serializing AST");
            }

            const output = try self.ast_root.serialize(self.allocator);
            defer self.allocator.free(output);

            if (progress_reporter) |reporter| {
                reporter.update(reporter.current_step, "Writing to file");
            }

            try std.fs.cwd().writeFile(file_path, output);

            if (progress_reporter) |reporter| {
                reporter.update(reporter.current_step, "File writing complete");
            }
        }
    }
};
