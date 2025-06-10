const std = @import("std");
const clap = @import("clap");
const testing = std.testing;

/// Represents the available commands in the application
pub const Command = enum { merge, watch, analyze };

/// Error set for CLI parsing
pub const CliError = error{
    HelpRequested,
    MissingCommand,
    InvalidCommand,
    MissingTargetPath,
    InvalidTargetPath,
    NoSourcePaths,
    InvalidSourcePath,
};

/// Main command parameters
const main_params = clap.parseParamsComptime(
    \\-h, --help         Display this help and exit
    \\-v, --verbose      Enable verbose output
    \\<command>          Command to run (merge|watch)
    \\
);

/// Parameters for the merge command
const merge_params = clap.parseParamsComptime(
    \\-h, --help         Display help for the merge command
    \\-t, --target <str> Target output file path (required)
    \\--remove-redundancies Remove redundant import statements
    \\--eliminate-dead-code Remove unused imports and code
    \\<str>...           Source files to merge (required)
    \\
);

/// Parameters for the watch command
const watch_params = clap.parseParamsComptime(
    \\-h, --help         Display help for the watch command
    \\-t, --target <str> Target output file path (required) 
    \\-d, --delay <u64>  Watch delay in milliseconds (default: 100)
    \\-r, --recursive    Watch directories recursively
    \\<str>...           Paths to watch (required)
    \\
);

/// Parameters for the analyze command
const analyze_params = clap.parseParamsComptime(
    \\-h, --help         Display help for the analyze command
    \\<str>...           Source files to analyze (required)
    \\
);

/// Configuration structure that holds parsed command-line arguments
pub const Config = struct {
    /// The command to execute (merge, watch, or analyze)
    command: Command,
    /// List of source file paths
    source_paths: []const []const u8,
    /// Target output file path (null for analyze command)
    target_path: ?[]const u8,
    /// Delay in milliseconds for watch command
    watch_delay_ms: u64,
    /// Whether verbose output is enabled
    verbose: bool,
    /// Whether to watch directories recursively
    recursive: bool,
    /// Whether to remove redundant import statements
    remove_redundancies: bool,
    /// Whether to eliminate dead code (unused imports and code)
    eliminate_dead_code: bool,
    /// Whether help was requested
    help_requested: bool = false,

    /// Free allocated memory
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

/// Parse command-line arguments and return a Config struct
/// If args_slice is null, use std.process.args
pub fn parse(allocator: std.mem.Allocator, args_slice: ?[]const []const u8) !Config {
    var diag = clap.Diagnostic{};

    // Parse main command
    var args = if (args_slice) |slice|
        try clap.parseEx(clap.Help, &main_params, clap.parsers.default, .{
            .allocator = allocator,
            .diagnostic = &diag,
            .args = slice,
        })
    else
        try clap.parseEx(clap.Help, &main_params, clap.parsers.default, .{
            .allocator = allocator,
            .diagnostic = &diag,
        });
    defer args.deinit();

    // Check if help was requested
    if (args.args.help > 0) {
        return Config{
            .command = .merge, // Default, doesn't matter since help was requested
            .target_path = null,
            .source_paths = try allocator.alloc([]const u8, 0),
            .watch_delay_ms = 100,
            .verbose = false,
            .recursive = false,
            .remove_redundancies = false,
            .eliminate_dead_code = false,
            .help_requested = true,
        };
    }

    // Get and validate command
    const command_str = args.positionals[0] orelse return error.MissingCommand;
    const command = std.meta.stringToEnum(Command, command_str) orelse return error.InvalidCommand;

    // Parse subcommand arguments
    var sub_args = if (args_slice) |slice|
        try clap.parseEx(clap.Help, switch (command) {
            .merge => &merge_params,
            .watch => &watch_params,
            .analyze => &analyze_params,
        }, clap.parsers.default, .{
            .allocator = allocator,
            .diagnostic = &diag,
            .args = slice,
        })
    else
        try clap.parseEx(clap.Help, switch (command) {
            .merge => &merge_params,
            .watch => &watch_params,
            .analyze => &analyze_params,
        }, clap.parsers.default, .{
            .allocator = allocator,
            .diagnostic = &diag,
        });
    defer sub_args.deinit();

    // Check if subcommand help was requested
    if (sub_args.args.help > 0) {
        return Config{
            .command = command,
            .target_path = null,
            .source_paths = try allocator.alloc([]const u8, 0),
            .watch_delay_ms = 100,
            .verbose = false,
            .recursive = false,
            .remove_redundancies = false,
            .eliminate_dead_code = false,
            .help_requested = true,
        };
    }

    // Get and validate target path (not required for analyze command)
    const target_path = if (command == .analyze)
        null
    else
        sub_args.args.target orelse return error.MissingTargetPath;

    // Validate target path (if provided)
    if (target_path != null and !std.fs.path.isAbsolute(target_path.?)) {
        return error.InvalidTargetPath;
    }

    // Get source paths
    const source_paths = try dupeStrings(allocator, sub_args.positionals);

    // Validate source paths
    if (source_paths.len == 0) {
        return error.NoSourcePaths;
    }

    // Create and return config
    return Config{
        .command = command,
        .target_path = if (target_path) |path| try allocator.dupe(u8, path) else null,
        .source_paths = source_paths,
        .watch_delay_ms = sub_args.args.delay orelse 100,
        .verbose = args.args.verbose > 0,
        .recursive = sub_args.args.recursive > 0,
        .remove_redundancies = sub_args.args.@"remove-redundancies" > 0,
        .eliminate_dead_code = sub_args.args.@"eliminate-dead-code" > 0,
    };
}

/// Backward compatibility function for the old API
pub fn parseArgs(allocator: std.mem.Allocator, args_slice: []const []const u8) !Config {
    return parse(allocator, args_slice);
}

fn dupeStrings(allocator: std.mem.Allocator, strings: []const []const u8) ![]const []const u8 {
    const copy = try allocator.alloc([]const u8, strings.len);
    for (strings, 0..) |s, i| {
        copy[i] = try allocator.dupe(u8, s);
    }
    return copy;
}

/// Print help text for the specified command
pub fn printHelp(command: ?Command) !void {
    const stderr = std.io.getStdErr().writer();

    if (command) |cmd| {
        // Print help for specific command
        try clap.help(stderr, clap.Help, switch (cmd) {
            .merge => &merge_params,
            .watch => &watch_params,
            .analyze => &analyze_params,
        }, .{});

        try stderr.writeAll("\nExamples:\n");
        switch (cmd) {
            .merge => try stderr.writeAll("  fuze merge -t /path/to/dist/merged.ts src/*.ts\n"),
            .watch => try stderr.writeAll("  fuze watch -t /path/to/dist/merged.ts -r src/\n"),
            .analyze => try stderr.writeAll("  fuze analyze src/*.ts\n"),
        }
    } else {
        // Print general help
        try clap.help(stderr, clap.Help, &main_params, .{});
        try stderr.writeAll(
            \\
            \\Commands:
            \\  merge    Merge TypeScript files into a single file
            \\  watch    Watch files/directories and merge on changes
            \\  analyze  Analyze TypeScript files without modifying them
            \\
            \\Examples:
            \\  fuze merge -t /path/to/dist/merged.ts src/*.ts
            \\  fuze watch -t /path/to/dist/merged.ts -r src/
            \\  fuze analyze src/*.ts
            \\
            \\For more information on a command, use: fuze <command> --help
            \\
        );
    }
}

/// Print error message and help text
pub fn printError(err: anyerror, writer: anytype, command: ?Command) !void {
    try writer.print("Error: {s}\n\n", .{@errorName(err)});

    // Print more specific error messages
    switch (err) {
        error.MissingCommand => try writer.writeAll("A command must be specified (merge or watch)\n\n"),
        error.InvalidCommand => try writer.writeAll("Invalid command. Valid commands are: merge, watch\n\n"),
        error.MissingTargetPath => try writer.writeAll("Target path is required. Use -t or --target to specify\n\n"),
        error.InvalidTargetPath => try writer.writeAll("Target path must be absolute\n\n"),
        error.NoSourcePaths => try writer.writeAll("At least one source path must be specified\n\n"),
        error.InvalidSourcePath => try writer.writeAll("Invalid source path\n\n"),
        else => {},
    }

    try printHelp(command);
}

test "parse help command" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "ts-merger", "--help" };
    var config = try parse(allocator, &args);
    defer config.deinit(allocator);
    try testing.expect(config.help_requested);
}

test "parse watch command" {
    const allocator = std.testing.allocator;
    // Use absolute path for target to pass validation
    const args = [_][]const u8{ "ts-merger", "watch", "--recursive", "-t", "/tmp/output.ts", "src/a.ts" };
    var config = try parse(allocator, &args);
    defer config.deinit(allocator);
    try testing.expect(config.recursive);
    try testing.expectEqualStrings("src/a.ts", config.source_paths[0]);
}

test "parse missing target - merge" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "ts-merger", "merge", "src/a.ts" };
    const config = parse(allocator, &args) catch |err| {
        try testing.expectEqual(error.MissingTargetPath, err);
        return;
    };
    defer config.deinit(allocator);
    return error.TestExpectedError;
}

test "parse missing target - watch" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "ts-merger", "watch", "src/a.ts" };
    const config = parse(allocator, &args) catch |err| {
        try testing.expectEqual(error.MissingTargetPath, err);
        return;
    };
    defer config.deinit(allocator);
    return error.TestExpectedError;
}

test "parse invalid target path" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "ts-merger", "merge", "-t", "relative/path.ts", "src/a.ts" };
    const config = parse(allocator, &args) catch |err| {
        try testing.expectEqual(error.InvalidTargetPath, err);
        return;
    };
    defer config.deinit(allocator);
    return error.TestExpectedError;
}

test "parse invalid command" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "fuze", "invalid" };
    try testing.expectError(error.InvalidCommand, parse(allocator, &args));
}

test "parse invalid watch delay" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "fuze", "watch", "-d", "invalid", "-t", "/tmp/output.ts", "src" };
    try testing.expectError(error.InvalidNumber, parse(allocator, &args));
}

test "parse no source paths" {
    const allocator = std.testing.allocator;
    const args = [_][]const u8{ "fuze", "merge", "-t", "/tmp/output.ts" };
    try testing.expectError(error.NoSourcePaths, parse(allocator, &args));
}
