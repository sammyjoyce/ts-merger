const std = @import("std");
const posix = std.posix;
const c = std.c;
const mod = @import("mod.zig");
const Logger = @import("../utils/log.zig").Logger;

const EVENTS_MAX = 32;

pub const InotifyWatcher = struct {
    allocator: std.mem.Allocator,
    inotify_fd: i32,
    watched_paths: std.StringHashMap(*WatchedPath),
    thread: ?std.Thread,
    running: std.atomic.Value(bool),
    callback: ?mod.WatchCallback,

    const WatchedPath = struct {
        path: []const u8,
        fd: i32,
        is_dir: bool,
        sub_dirs: std.ArrayList([]const u8),
        path: []const u8,
        wd: i32,
        is_dir: bool,
        sub_dirs: std.ArrayList([]const u8),
    };

    pub fn init(allocator: std.mem.Allocator) !InotifyWatcher {
        const inotify_fd = try posix.inotify_init1(posix.IN.CLOEXEC | posix.IN.NONBLOCK);
        errdefer posix.close(inotify_fd);

        return InotifyWatcher{
            .allocator = allocator,
            .inotify_fd = inotify_fd,
            .watched_paths = std.StringHashMap(*WatchedPath).init(allocator),
            .thread = null,
            .running = std.atomic.Value(bool).init(false),
            .callback = null,
        };
    }

    pub fn deinit(self: *InotifyWatcher) void {
        if (self.running.load(.acquire)) {
            self.stop();
        }

        var it = self.watched_paths.iterator();
        while (it.next()) |entry| {
            _ = posix.inotify_rm_watch(self.inotify_fd, entry.value_ptr.*.wd);
            self.allocator.free(entry.value_ptr.*.path);
            entry.value_ptr.*.sub_dirs.deinit();
            for (entry.value_ptr.*.sub_dirs.items) |sub| {
                self.allocator.free(sub);
            }
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.watched_paths.deinit();
        posix.close(self.inotify_fd);
    }

    pub fn watch(self: *InotifyWatcher, path: []const u8) !void {
        const st = try std.fs.cwd().statFile(path);
        const is_dir = st.kind == .directory;

        const flags = posix.IN{
            .MODIFY = true,
            .CREATE = true,
            .DELETE = true,
            .DELETE_SELF = true,
            .MOVE = true,
            .MOVE_SELF = true,
            .CLOSE_WRITE = true,
            .ONLYDIR = is_dir,
            .ISDIR = is_dir,
        };

        const wd = try posix.inotify_add_watch(self.inotify_fd, path, flags);
        errdefer _ = posix.inotify_rm_watch(self.inotify_fd, wd);

        var dir = if (is_dir)
            std.fs.openDirAbsolute(path, .{ .access_sub_paths = true }) catch |err| {
                Logger.scoped(.Warning, "watcher").err("Failed to open directory {s}: {s}", .{ path, @errorName(err) });
                return err;
            }
        else
            null;
        defer if (dir) |d| d.close();
        var watched = try self.allocator.create(WatchedPath);
        errdefer self.allocator.destroy(watched);

        watched.* = .{
            .path = try self.allocator.dupe(u8, path),
            .wd = wd,
            .is_dir = dir != null,
            .sub_dirs = std.ArrayList([]const u8).init(self.allocator),
        };

        if (dir) |d| {
            var it = d.iterate();
            while (try it.next()) |entry| {
                if (entry.kind == .directory) {
                    const full_path = try std.fs.path.join(self.allocator, &.{ path, entry.name });
                    try watched.sub_dirs.append(full_path);
                }
            }
            d.close();
        }

        try self.watched_paths.put(path, watched);
    }

    // Rest of the implementation remains the same
    pub fn unwatch(self: *InotifyWatcher, path: []const u8) void {
        if (self.watched_paths.get(path)) |watched| {
            _ = posix.inotify_rm_watch(self.inotify_fd, watched.wd);
            self.allocator.free(watched.path);
            watched.sub_dirs.deinit(); // Added deinit for sub_dirs
            self.allocator.destroy(watched);
            _ = self.watched_paths.remove(path);
        }
    }

    // Remaining methods stay the same
    pub fn start(self: *InotifyWatcher) !void {
        if (self.running.load(.acquire)) return;

        self.running.store(true, .release);
        self.thread = try std.Thread.spawn(.{}, watcherThread, .{self});
    }

    pub fn stop(self: *InotifyWatcher) void {
        if (!self.running.load(.acquire)) return;

        self.running.store(false, .release);
        if (self.thread) |thread| {
            thread.join();
            self.thread = null;
        }
    }

    pub fn setCallback(self: *InotifyWatcher, callback: mod.WatchCallback) void {
        self.callback = callback;
    }

    fn watcherThread(self: *InotifyWatcher) void {
        // Existing implementation remains the same
        var buf: [4096]u8 align(@alignOf(posix.InotifyEvent)) = undefined;

        while (self.running.load(.acquire)) {
            const bytes_read = posix.read(self.inotify_fd, &buf) catch continue;
            if (bytes_read < @sizeOf(posix.InotifyEvent)) continue;

            var offset: usize = 0;
            while (offset < bytes_read) {
                const event = @as(*align(1) posix.InotifyEvent, @ptrCast(&buf[offset]));
                const name_len = if (event.len > 0) event.len else 0;
                const name = if (name_len > 0) buf[offset + @sizeOf(posix.InotifyEvent) ..][0 .. name_len - 1] else "";

                var it = self.watched_paths.iterator();
                while (it.next()) |entry| {
                    if (entry.value_ptr.*.wd == event.wd) {
                        const kind = if (event.mask.DELETE or event.mask.DELETE_SELF)
                            mod.WatchEvent.EventKind.delete
                        else if (event.mask.MODIFY or event.mask.CLOSE_WRITE)
                            mod.WatchEvent.EventKind.modify
                        else if (event.mask.MOVED_FROM or event.mask.MOVED_TO or event.mask.MOVE_SELF)
                            mod.WatchEvent.EventKind.rename
                        else
                            continue;

                        const watch_event = mod.WatchEvent{
                            .path = if (name.len > 0)
                                std.fs.path.join(self.allocator, &.{ entry.value_ptr.*.path, name }) catch |err| {
                                    Logger.scoped(.Error, "watcher").err("Path join failed: {s}", .{@errorName(err)});
                                    continue;
                                }
                            else
                                entry.value_ptr.*.path,
                            .kind = kind,
                        };
                        defer {
                            if (name.len > 0 and watch_event.path.ptr != entry.value_ptr.*.path.ptr) {
                                self.allocator.free(watch_event.path);
                            }
                        }

                        if (self.callback) |cb| {
                            cb(watch_event);
                        }
                    }
                }

                offset += @sizeOf(posix.InotifyEvent) + name_len;
            }
        }
    }
};
