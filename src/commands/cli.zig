const std = @import("std");
const watcher = @import("watcher");
const testing = std.testing;

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
    recursive: bool,

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
    UnknownCommand,
    InvalidNumber,
};

pub fn parseArgs(allocator: std.mem.Allocator, args: []const []const u8) !Config {
    if (args.len < 2) {
        return ParseError.NoCommand;
    }

    var config = Config{
        .command = undefined,
        .source_paths = &[_][]const u8{},
        .target_path = null,
        .watch_delay_ms = 100,
        .show_help = false,
        .verbose = false,
        .recursive = false,
    };

    // Check for help flag first
    if (std.mem.eql(u8, args[1], "-h") or std.mem.eql(u8, args[1], "--help")) {
        config.show_help = true;
        return config;
    }

    // Parse command
    config.command = std.meta.stringToEnum(Command, args[1]) orelse {
        return ParseError.UnknownCommand;
    };

    var source_paths = std.ArrayList([]const u8).init(allocator);
    defer source_paths.deinit();

    var has_target = false;
    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--target")) {
            i += 1;
            if (i >= args.len) return ParseError.NoTargetPath;
            config.target_path = try allocator.dupe(u8, args[i]);
            has_target = true;
        } else if (std.mem.eql(u8, arg, "-d") or std.mem.eql(u8, arg, "--delay")) {
            i += 1;
            if (i >= args.len) return ParseError.InvalidNumber;
            config.watch_delay_ms = std.fmt.parseInt(u64, args[i], 10) catch {
                return ParseError.InvalidNumber;
            };
        } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            config.show_help = true;
        } else if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            config.verbose = true;
        } else if (std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--recursive")) {
            config.recursive = true;
        } else {
            try source_paths.append(try allocator.dupe(u8, arg));
        }
    }

    if (source_paths.items.len == 0 and !config.show_help) {
        return ParseError.NoSourcePaths;
    }

    if (config.command == .merge and !has_target and !config.show_help) {
        return ParseError.NoTargetPath;
    }

    config.source_paths = try source_paths.toOwnedSlice();
    return config;
}

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
test "parse help command" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "ts-merger", "--help" };
    var config = try parseArgs(allocator, &args);
    defer config.deinit(allocator);
    try testing.expect(config.show_help);
}

test "parse watch command" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "ts-merger", "watch", "--recursive", "src/a.ts" };
    var config = try parseArgs(allocator, &args);
    defer config.deinit(allocator);
    try testing.expect(config.recursive);
    try testing.expectEqualStrings("src/a.ts", config.source_paths[0]);
}

test "parse missing target - merge" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "ts-merger", "merge", "src/a.ts" };
    var config = parseArgs(allocator, &args) catch |err| {
        try testing.expectEqual(error.NoTargetPath, err);
        return;
    };
    defer config.deinit(allocator);
    try testing.expect(false); // Should not reach here
}

test "parse missing target - watch" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "ts-merger", "watch", "src/a.ts" };
    try testing.expectError(error.NoTargetPath, parseArgs(allocator, &args));
}

test "parse invalid command" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "fuze", "invalid" };
    try testing.expectError(error.UnknownCommand, parseArgs(allocator, &args));
}

test "parse invalid watch delay" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "fuze", "watch", "-d", "invalid", "src" };
    try testing.expectError(error.InvalidNumber, parseArgs(allocator, &args));
}
