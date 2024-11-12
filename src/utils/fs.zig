const std = @import("std");

pub const FSError = error{
    OutOfMemory,
    FileNotFound,
    AccessDenied,
    IsDirectory,
    SymLinkLoop,
    ProcessFdQuotaExceeded,
    SystemFdQuotaExceeded,
    NoDevice,
    PathTooLong,
};

pub fn readFile(allocator: std.mem.Allocator, path: []const u8) FSError![]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const contents = try file.readToEndAlloc(allocator, stat.size);

    return contents;
}

pub fn writeFile(path: []const u8, contents: []const u8) FSError!void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    try file.writeAll(contents);
}

pub fn listFiles(allocator: std.mem.Allocator, dir_path: []const u8, recursive: bool) FSError!std.ArrayList([]const u8) {
    var list = std.ArrayList([]const u8).init(allocator);
    errdefer list.deinit();

    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (!recursive and entry.dir_fd != -1) continue;
        if (entry.kind != .File) continue;

        const path = try allocator.dupe(u8, entry.path);
        try list.append(path);
    }

    return list;
}
