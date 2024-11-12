const std = @import("std");
const testing = std.testing;
const watcher = @import("watcher");

test "create and initialize watcher" {
    const allocator = testing.allocator;
    var w = try watcher.Watcher.init(allocator);
    defer w.deinit();
}

test "add watch path" {
    const allocator = testing.allocator;
    var w = try watcher.Watcher.init(allocator);
    defer w.deinit();

    // Create a temporary file
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const file = try tmp_dir.dir.createFile("test.ts", .{});
    file.close();

    try w.watch(tmp_dir.dir.realpathAlloc(allocator, "test.ts") catch unreachable);
}

test "watcher event handling" {
    const allocator = testing.allocator;
    var w = try watcher.Watcher.init(allocator);
    defer w.deinit();

    // Create a temporary file
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const file_path = "test.ts";
    const file = try tmp_dir.dir.createFile(file_path, .{});
    file.close();

    const real_path = try tmp_dir.dir.realpathAlloc(allocator, file_path);
    defer allocator.free(real_path);

    // Set up event handler
    const TestContext = struct {
        var received_event: bool = false;

        pub fn onEvent(event: watcher.WatchEvent) void {
            received_event = true;
            _ = event;
        }
    };

    w.setCallback(TestContext.onEvent);
    TestContext.received_event = false;

    // Add watch path
    try w.watch(real_path);

    // Modify file to trigger event
    const content = "test content";
    var file_out = try tmp_dir.dir.createFile(file_path, .{});
    defer file_out.close();
    try file_out.writeAll(content);

    // Poll for events
    try w.start();
    std.time.sleep(100 * std.time.ns_per_ms);
    try testing.expect(TestContext.received_event);
}

test "watcher cleanup" {
    const allocator = testing.allocator;
    var w = try watcher.Watcher.init(allocator);

    // Create a temporary file
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const file_path = "test.ts";
    const file = try tmp_dir.dir.createFile(file_path, .{});
    file.close();

    const real_path = try tmp_dir.dir.realpathAlloc(allocator, file_path);
    defer allocator.free(real_path);

    try w.watch(real_path);
    w.deinit();
}

test "watcher multiple paths" {
    const allocator = testing.allocator;
    var w = try watcher.Watcher.init(allocator);
    defer w.deinit();

    // Create temporary files
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const files = [_][]const u8{ "test1.ts", "test2.ts", "test3.ts" };
    for (files) |path| {
        const file = try tmp_dir.dir.createFile(path, .{});
        file.close();
        const real_path = try tmp_dir.dir.realpathAlloc(allocator, path);
        defer allocator.free(real_path);
        try w.watch(real_path);
    }
}
