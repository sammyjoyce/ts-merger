const std = @import("std");
const Project = @import("project.zig").Project;
const Logger = @import("utils/log.zig").Logger;

pub fn main() !void {
    // NOTE: Keep this main.zig minimal. We only parse CLI args and dispatch commands here.
    // We don't embed domain logic or watchers directly in main.

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        Logger.init(.Error).err("Error: Not enough arguments", .{});
        return error.NotEnoughArguments;
    }

    const command = args[1];
    const command_args = args[2..];

    if (std.mem.eql(u8, command, "merge")) {
        return mergeCommand(allocator, command_args) catch |err| handleMergeError(err, command_args);
    } else {
        Logger.init(.Error).err("Error: Unknown command '{s}'", .{command});
        return error.UnknownCommand;
    }
    return error.Unreachable;
}

fn handleMergeError(err: anyerror, args: []const []const u8) noreturn {
    Logger.scoped(.Error, "merge").err("Merge failed: {s} with args:", .{@errorName(err)});
    for (args) |arg| {
        Logger.scoped(.Error, "merge").err("  {s}", .{arg});
    }
    std.process.exit(1);
}

fn mergeCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        Logger.init(.Error).err("Error: Not enough arguments for merge command", .{});
        return error.NotEnoughArguments;
    }

    const target_file = args[0];
    const source_files = args[1..];

    if (!std.fs.path.isAbsolute(target_file)) {
        Logger.scoped(.Error, "merge").err("Target path must be absolute: {s}", .{target_file});
        return error.InvalidPath;
    }

    Logger.scoped(.Info, "merge").info("Starting merge command...", .{});
    Logger.scoped(.Info, "merge").info("Target: {s}", .{target_file});
    Logger.scoped(.Info, "merge").info("Source files:", .{});
    for (source_files) |file| {
        Logger.scoped(.Info, "merge").info("  - {s}", .{file});
    }

    var project_instance = try Project.init(allocator);
    defer project_instance.deinit();

    const logger = Logger.scoped(.Info, "merge");

    logger.info("Processing source files...", .{});
    for (source_files) |file| {
        logger.info("Processing {s}", .{file});
        try project_instance.parseFile(file);
    }

    logger.info("Writing to {s}...", .{target_file});
    try project_instance.writeToFile(target_file);

    Logger.scoped(.Info, "merge").info("Merge command completed successfully.", .{});
}
