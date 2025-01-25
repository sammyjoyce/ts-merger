const std = @import("std");
const builtin = @import("builtin");

/// Represents a file system event
pub const WatchEvent = struct {
    path: []const u8,
    kind: EventKind,

    pub const EventKind = enum {
        create,
        modify,
        delete,
        rename,
    };
};

/// Callback function type for watch events
pub const WatchCallback = *const fn (event: WatchEvent) void;

/// Platform-specific watcher implementation
const kqueue = @import("kqueue.zig");
const inotify = @import("inotify.zig");
const windows = @import("windows.zig");

const PlatformWatcher = switch (builtin.target.os.tag) {
    .macos => kqueue.KqueueWatcher,
    .linux => inotify.InotifyWatcher,
    .windows => windows.WindowsWatcher,
    else => @compileError("Unsupported operating system"),
};

/// File system watcher
pub const Watcher = struct {
    allocator: std.mem.Allocator,
    impl: PlatformWatcher,
    callback: ?WatchCallback,

    pub fn init(allocator: std.mem.Allocator) !Watcher {
        return Watcher{
            .allocator = allocator,
            .impl = try PlatformWatcher.init(allocator),
            .callback = null,
        };
    }

    pub fn deinit(self: *Watcher) void {
        self.impl.deinit();
    }

    pub fn watch(self: *Watcher, path: []const u8) !void {
        try self.impl.watch(path);
    }

    pub fn unwatch(self: *Watcher, path: []const u8) void {
        self.impl.unwatch(path);
    }

    pub fn setCallback(self: *Watcher, callback: WatchCallback) void {
        self.callback = callback;
        self.impl.setCallback(callback);
    }

    pub fn start(self: *Watcher) !void {
        try self.impl.start();
    }

    pub fn stop(self: *Watcher) void {
        self.impl.stop();
    }
};

const testing = std.testing;

const WATCHER_INIT_WAIT_MS = 100;
const EVENT_WAIT_MS = 200;

const TestContext = struct {
    var received_events = std.ArrayList(WatchEvent).init(testing.allocator);

    pub fn onEvent(event: WatchEvent) void {
        received_events.append(event) catch return;
    }

    pub fn reset() void {
        received_events.clearAndFree();
    }

    pub fn deinit() void {
        received_events.deinit();
    }

    pub fn findEvent(kind: WatchEvent.EventKind) bool {
        for (received_events.items) |event| {
            if (event.kind == kind) return true;
        }
        return false;
    }
};

test "watcher - create and initialize" {
    const allocator = testing.allocator;
    var w = try Watcher.init(allocator);
    defer w.deinit();
}

test "watcher - add watch path" {
    const allocator = testing.allocator;
    var w = try Watcher.init(allocator);
    defer w.deinit();

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const file = try tmp_dir.dir.createFile("test.ts", .{});
    file.close();

    try w.watch(tmp_dir.dir.realpathAlloc(allocator, "test.ts") catch unreachable);
}

test "watcher - event handling - modify" {
    const allocator = testing.allocator;
    var w = try Watcher.init(allocator);
    defer w.deinit();

    TestContext.reset();
    defer TestContext.deinit();

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const file = try tmp_dir.dir.createFile("test.ts", .{});
    file.close();

    const path = try tmp_dir.dir.realpathAlloc(allocator, "test.ts");
    defer allocator.free(path);

    try w.watch(path);
    w.setCallback(TestContext.onEvent);
    try w.start();

    std.time.sleep(WATCHER_INIT_WAIT_MS * std.time.ns_per_ms);

    try tmp_dir.dir.writeFile("test.ts", "test content");

    std.time.sleep(EVENT_WAIT_MS * std.time.ns_per_ms);

    try testing.expect(TestContext.findEvent(.modify));

    w.stop();
}
