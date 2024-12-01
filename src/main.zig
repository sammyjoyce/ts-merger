const std = @import("std");
const Project = @import("project.zig").Project;
const Logger = @import("utils/log.zig").Logger;

pub fn main() !void {
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
        try mergeCommand(allocator, command_args);
    } else {
        Logger.init(.Error).err("Error: Unknown command '{s}'", .{command});
        return error.UnknownCommand;
    }
}

fn mergeCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        Logger.init(.Error).err("Error: Not enough arguments for merge command", .{});
        return error.NotEnoughArguments;
    }

    const target_file = args[0];
    const source_files = args[1..];

    Logger.scoped(.Info, "merge").info("Starting merge command...", .{});
    Logger.scoped(.Info, "merge").info("Target: {s}", .{target_file});
    Logger.scoped(.Info, "merge").info("Source files:", .{});
    for (source_files) |file| {
        Logger.scoped(.Info, "merge").info("  - {s}", .{file});
    }

    var project_instance = try Project.init(allocator);
    defer project_instance.deinit();

    Logger.scoped(.Info, "merge").info("Processing source files...", .{});
    for (source_files) |file| {
        try project_instance.parseFile(file);
    }

    Logger.scoped(.Info, "merge").info("Writing to file...", .{});
    try project_instance.writeToFile(target_file);

    Logger.scoped(.Info, "merge").info("Merge command completed successfully.", .{});
}
