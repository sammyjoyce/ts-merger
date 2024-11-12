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
