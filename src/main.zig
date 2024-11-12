const std = @import("std");
const Project = @import("project.zig").Project;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("Error: Not enough arguments\n", .{});
        return error.NotEnoughArguments;
    }

    const command = args[1];
    const command_args = args[2..];

    if (std.mem.eql(u8, command, "merge")) {
        try mergeCommand(allocator, command_args);
    } else {
        std.debug.print("Error: Unknown command '{s}'\n", .{command});
        return error.UnknownCommand;
    }
}

fn mergeCommand(allocator: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        std.debug.print("Error: Not enough arguments\n", .{});
        return error.NotEnoughArguments;
    }

    const target_file = args[0];
    const source_files = args[1..];

    std.debug.print("Command: merge\n", .{});
    std.debug.print("Target: {s}\n", .{target_file});
    std.debug.print("Source files:\n", .{});
    for (source_files) |file| {
        std.debug.print("  - {s}\n", .{file});
    }

    std.debug.print("Starting merge command...\n", .{});

    var project_instance = try Project.init(allocator);
    defer project_instance.deinit();

    std.debug.print("Processing source files...\n", .{});
    for (source_files) |file| {
        try project_instance.parseFile(file);
    }

    std.debug.print("Writing to file...\n", .{});
    try project_instance.writeToFile(target_file);

    std.debug.print("Done!\n", .{});
}
