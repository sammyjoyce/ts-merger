const std = @import("std");
const clap = @import("clap");
const testing = std.testing;

pub const Command = enum { merge, watch };

const main_params = comptime clap.parseParamsComptime(
    \\-h, --help         Display this help and exit
    \\-v, --verbose      Enable verbose output
    \\<command>          Command to run (merge|watch)
    \\
);

const merge_params = comptime clap.parseParamsComptime(
    \\-h, --help         Display merge help
    \\-t, --target <str> Target output file (required)
    \\<str>...           Source files to merge
    \\
);

const watch_params = comptime clap.parseParamsComptime(
    \\-h, --help         Display watch help
    \\-t, --target <str> Target output file (required) 
    \\-d, --delay <u64>  Watch delay in milliseconds (default: 100)
    \\-r, --recursive    Watch directories recursively
    \\<str>...           Paths to watch
    \\
);

pub const Config = struct {
    command: Command,
    source_paths: []const []const u8,
    target_path: []const u8,
    watch_delay_ms: u64,
    verbose: bool,
    recursive: bool,

    pub fn deinit(self: *Config, allocator: std.mem.Allocator) void {
        for (self.source_paths) |path| {
            allocator.free(path);
        }
        allocator.free(self.source_paths);
        allocator.free(self.target_path);
    }
};

pub fn parse(allocator: std.mem.Allocator) !Config {
    var diag = clap.Diagnostic{};
    var args = clap.parseEx(clap.Help, &main_params, clap.parsers.default, .{
        .allocator = allocator,
        .diagnostic = &diag,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer args.deinit();

    const command_str = args.positionals[0] orelse return error.MissingCommand;
    const command = std.meta.stringToEnum(Command, command_str) orelse return error.InvalidCommand;
    
    var sub_args = try clap.parseEx(clap.Help, switch (command) {
        .merge => &merge_params,
        .watch => &watch_params,
    }, clap.parsers.default, .{
        .allocator = allocator,
        .diagnostic = &diag,
    });
    defer sub_args.deinit();

    const target_path = sub_args.args.target orelse return error.MissingTargetPath;
    
    return Config{
        .command = command,
        .target_path = try allocator.dupe(u8, target_path),
        .source_paths = try dupeStrings(allocator, sub_args.positionals),
        .watch_delay_ms = sub_args.args.delay orelse 100,
        .verbose = args.args.verbose > 0,
        .recursive = sub_args.args.recursive > 0,
    };
}

fn dupeStrings(allocator: std.mem.Allocator, strings: []const []const u8) ![]const []const u8 {
    const copy = try allocator.alloc([]const u8, strings.len);
    for (strings, 0..) |s, i| {
        copy[i] = try allocator.dupe(u8, s);
    }
    return copy;
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
