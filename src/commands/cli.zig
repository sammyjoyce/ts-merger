const std = @import("std");
const clap = @import("clap");
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
        allocator.free(self.source_paths);
        if (self.target_path) |path| {
            allocator.free(path);
        }
    }
};

const params = clap.parseParamsComptime(
    \\-h, --help             Display this help and exit
    \\-v, --verbose          Enable verbose output
    \\-r, --recursive        Process directories recursively
    \\-t, --target <STR>     Target output file
    \\-d, --delay <UINT>     Watch delay in milliseconds (default: 100)
    \\<CMD>                  Command to run (merge, watch)
    \\<FILES>...             Source files/directories to process
);

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
    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, args[1..]) catch |err| {
        try clap.usage(std.io.getStdErr().writer(), clap.Help, &params);
        return switch (err) {
            error.InvalidArgument => ParseError.InvalidCommand,
            error.MissingValue => ParseError.NoTargetPath,
            else => ParseError.UnknownCommand,
        };
    };
    defer res.deinit();

    // Handle help flag first
    if (res.args.help != 0) {
        return Config{
            .command = undefined,
            .source_paths = &[_][]const u8{},
            .target_path = null,
            .watch_delay_ms = 100,
            .show_help = true,
            .verbose = false,
            .recursive = false,
        };
    }

    // Parse command
    if (res.positionals.len == 0) {
        return ParseError.NoCommand;
    }

    const cmd = std.meta.stringToEnum(Command, res.positionals[0]) orelse {
        return ParseError.InvalidCommand;
    };

    // Parse source paths
    const sources = if (res.positionals.len > 1)
        try allocator.dupe([]const u8, res.positionals[1..])
    else
        &[_][]const u8{};

    // Build config
    return Config{
        .command = cmd,
        .source_paths = sources,
        .target_path = if (res.args.target) |t| try allocator.dupe(u8, t) else null,
        .watch_delay_ms = res.args.delay orelse 100,
        .show_help = false,
        .verbose = res.args.verbose != 0,
        .recursive = res.args.recursive != 0,
    };
}

pub fn printHelp() !void {
    try clap.usage(std.io.getStdErr().writer(), clap.Help, &params);
    try std.io.getStdErr().writer().writeAll(
        \\
        \\Examples:
        \\  fuze merge -t dist/merged.ts src/*.ts
        \\  fuze watch -t dist/merged.ts src/
        \\
    );
}

pub fn printError(err: anyerror, writer: anytype) !void {
    try writer.print("Error: {s}\n\n", .{@errorName(err)});
    try printHelp();
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
    defer if (config) |cfg| cfg.deinit(allocator);
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
    const config = parseArgs(allocator, &args) catch |err| {
        try testing.expectEqual(error.NoTargetPath, err);
        return;
    };
    defer config.deinit(allocator);
    return error.TestExpectedError;
}

test "parse missing target - watch" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "ts-merger", "watch", "src/a.ts" };
    const config = parseArgs(allocator, &args) catch |err| {
        try testing.expectEqual(error.NoTargetPath, err);
        return;
    };
    defer config.deinit(allocator);
    return error.TestExpectedError;
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
