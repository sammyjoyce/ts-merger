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

    var cli_config = try @import("commands/cli.zig").parse(allocator) catch |err| {
        if (err == error.HelpRequested) {
            try @import("commands/cli.zig").printHelp();
            return;
        }
        return err;
    };
    defer cli_config.deinit(allocator);

    switch (cli_config.command) {
        .merge => try mergeCommand(allocator, cli_config),
        .watch => {
            Logger.init(.Error).err("Watch command not yet implemented", .{});
            return error.NotImplemented;
        },
    }
}

fn mergeCommand(allocator: std.mem.Allocator, config: @import("commands/cli.zig").Config) !void {
    const target_file = config.target_path orelse {
        Logger.init(.Error).err("Error: Target path required for merge command", .{});
        return error.NoTargetPath;
    };

    if (!std.fs.path.isAbsolute(target_file)) {
        Logger.scoped(.Error, "merge").err("Target path must be absolute: {s}", .{target_file});
        return error.InvalidPath;
    }

    if (config.source_paths.len == 0) {
        Logger.init(.Error).err("Error: No source files specified", .{});
        return error.NoSourcePaths;
    }

    Logger.scoped(.Info, "merge").info("Starting merge command...", .{});
    Logger.scoped(.Info, "merge").info("Target: {s}", .{target_file});
    Logger.scoped(.Info, "merge").info("Source files:", .{});
    for (config.source_paths) |file| {
        Logger.scoped(.Info, "merge").info("  - {s}", .{file});
    }

    var project_instance = try Project.init(allocator);
    defer project_instance.deinit();

    const logger = Logger.scoped(.Info, "merge");

    logger.info("Processing source files...", .{});
    for (config.source_paths) |file| {
        logger.info("Processing {s}", .{file});
        try project_instance.parseFile(file);
    }

    logger.info("Writing to {s}...", .{target_file});
    try project_instance.writeToFile(target_file);

    Logger.scoped(.Info, "merge").info("Merge command completed successfully.", .{});
}
