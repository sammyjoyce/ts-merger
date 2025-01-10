const std = @import("std");
const watcher = @import("watcher");

pub const Command = enum {
    merge,
    watch,
};

pub const Config = struct {
    command: Command,
    source_paths: []const []const u8,
    target_path: ?[]const u8,
    watch_delay_ms: u64,
    show_help: bool,
    verbose: bool,

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        for (self.source_paths) |path| {
            allocator.free(path);
        }
        allocator.free(self.source_paths);
        if (self.target_path) |path| {
            allocator.free(path);
        }
    }
};

const ParseError = error{
    NoCommand,
    InvalidCommand,
    NoSourcePaths,
    NoTargetPath,
    OutOfMemory,
};

pub fn printHelp() void {
    std.debug.print(
        \\Usage: fuze <command> [options] <source_files...>
        \\
        \\Commands:
        \\  merge    Merge TypeScript files
        \\  watch    Watch and merge TypeScript files
        \\
        \\Options:
        \\  -t, --target <file>   Target file for merge output
        \\  -d, --delay <ms>      Delay between file checks in watch mode (default: 100ms)
        \\  -v, --verbose         Enable verbose output
        \\  -h, --help           Show this help message
        \\
        \\Examples:
        \\  fuze merge -t dist/merged.ts src/*.ts
        \\  fuze watch -t dist/merged.ts src/
        \\
    , .{});
}

pub fn printError(err: anyerror, writer: anytype) !void {
    try writer.print("Error: {s}\n\n", .{@errorName(err)});
    printHelp();
}

pub fn parseArgsFromProcess(allocator: std.mem.Allocator) ParseError!Config {
    var args = std.ArrayList([]const u8).init(allocator);
    defer {
        for (args.items) |arg| {
            allocator.free(arg);
        }
        args.deinit();
    }

    var it = try std.process.argsWithAllocator(allocator);
    defer it.deinit();

    // Skip executable name
    _ = it.next();

    // Parse command
    const cmd_str = it.next() orelse return error.NoCommand;
    const cmd = std.meta.stringToEnum(Command, cmd_str) orelse return error.InvalidCommand;

    var source_paths = std.ArrayList([]const u8).init(allocator);
    var target_path: ?[]const u8 = null;
    var watch_delay_ms: u64 = 100;
    var show_help = false;
    var verbose = false;

    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            show_help = true;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--target")) {
            if (target_path != null) allocator.free(target_path.?);
            target_path = try allocator.dupe(u8, it.next() orelse return error.NoTargetPath);
        } else if (std.mem.eql(u8, arg, "-d") or std.mem.eql(u8, arg, "--delay")) {
            const delay_str = it.next() orelse continue;
            watch_delay_ms = std.fmt.parseInt(u64, delay_str, 10) catch continue;
        } else {
            try source_paths.append(try allocator.dupe(u8, arg));
        }
    }

    return Config{
        .command = cmd,
        .source_paths = try source_paths.toOwnedSlice(),
        .target_path = target_path,
        .watch_delay_ms = watch_delay_ms,
        .show_help = show_help,
        .verbose = verbose,
    };
}
