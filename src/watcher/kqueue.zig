const std = @import("std");
const posix = std.posix;
const c = std.c;
const mod = @import("mod.zig");

const EVENTS_MAX = 32;

pub const KqueueWatcher = struct {
    allocator: std.mem.Allocator,
    kq: i32,
    watched_paths: std.StringHashMap(*WatchedPath),
    thread: ?std.Thread,
    running: std.atomic.Value(bool),
    callback: ?mod.WatchCallback,
    dir_scan_time: std.StringHashMap(i64),

    const WatchedPath = struct {
        path: []const u8,
        fd: i32,
        is_dir: bool,
    };

    pub fn init(allocator: std.mem.Allocator) !KqueueWatcher {
        const kq = try posix.kqueue();
        errdefer posix.close(kq);

        return KqueueWatcher{
            .allocator = allocator,
            .kq = kq,
            .watched_paths = std.StringHashMap(*WatchedPath).init(allocator),
            .thread = null,
            .running = std.atomic.Value(bool).init(false),
            .callback = null,
            .dir_scan_time = std.StringHashMap(i64).init(allocator),
        };
    }

    pub fn deinit(self: *KqueueWatcher) void {
        if (self.running.load(.acquire)) {
            self.stop();
        }

        var it = self.watched_paths.iterator();
        while (it.next()) |entry| {
            posix.close(entry.value_ptr.*.fd);
            self.allocator.free(entry.value_ptr.*.path);
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.watched_paths.deinit();

        var dir_it = self.dir_scan_time.keyIterator();
        while (dir_it.next()) |key| {
            self.allocator.free(key.*);
        }
        self.dir_scan_time.deinit();

        posix.close(self.kq);
    }

    fn watchSingleFile(self: *KqueueWatcher, path: []const u8) !void {
        // Skip if already watched
        if (self.watched_paths.contains(path)) return;

        const flags = std.fs.File.OpenFlags{
            .mode = .read_only,
            .lock_nonblocking = true,
        };

        const fd = try std.fs.openFileAbsolute(path, flags);
        errdefer fd.close();

        var watched = try self.allocator.create(WatchedPath);
        errdefer self.allocator.destroy(watched);

        watched.path = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(watched.path);
        watched.fd = fd.handle;
        watched.is_dir = false;

        // SAFETY: This array is only used within this function for temporary storage of kqueue events
        var kevs: [1]posix.Kevent = undefined;
        const flags_note = c.NOTE_DELETE | c.NOTE_WRITE | c.NOTE_RENAME | c.NOTE_EXTEND;

        kevs[0] = posix.Kevent{
            .ident = @intCast(fd.handle),
            .filter = c.EVFILT_VNODE,
            .flags = c.EV_ADD | c.EV_CLEAR,
            .fflags = flags_note,
            .data = 0,
            .udata = 0,
        };

        _ = try posix.kevent(self.kq, &kevs, &[0]posix.Kevent{}, null);
        try self.watched_paths.put(watched.path, watched);
    }

    fn scanDirectory(self: *KqueueWatcher, dir_path: []const u8) !void {
        // Check if we've scanned this directory recently
        const now = std.time.milliTimestamp();
        if (self.dir_scan_time.get(dir_path)) |last_scan| {
            if (now - last_scan < 1000) return; // Don't scan more than once per second
        }

        // Update scan time
        try self.dir_scan_time.put(dir_path, now);

        var dir = try std.fs.openDirAbsolute(dir_path, .{ .access_sub_paths = true });
        defer dir.close();

        var dir_it = dir.iterate();
        while (try dir_it.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".ts")) continue;

            const abs_path = try std.fs.path.join(self.allocator, &.{ dir_path, entry.name });
            defer self.allocator.free(abs_path);

            try self.watchSingleFile(abs_path);
        }
    }

    fn watchDirectory(self: *KqueueWatcher, dir_path: []const u8) !void {
        // Skip if already watched
        if (self.watched_paths.contains(dir_path)) return;

        const flags = std.fs.File.OpenFlags{
            .mode = .read_only,
            .lock_nonblocking = true,
        };

        const fd = try std.fs.openFileAbsolute(dir_path, flags);
        errdefer fd.close();

        var watched = try self.allocator.create(WatchedPath);
        errdefer self.allocator.destroy(watched);

        watched.path = try self.allocator.dupe(u8, dir_path);
        errdefer self.allocator.free(watched.path);
        watched.fd = fd.handle;
        watched.is_dir = true;

        // SAFETY: This array is only used within this function for temporary storage of kqueue events
        var kevs: [1]posix.Kevent = undefined;
        const flags_note = c.NOTE_DELETE | c.NOTE_WRITE | c.NOTE_RENAME | c.NOTE_EXTEND | c.NOTE_ATTRIB;

        kevs[0] = posix.Kevent{
            .ident = @intCast(fd.handle),
            .filter = c.EVFILT_VNODE,
            .flags = c.EV_ADD | c.EV_CLEAR,
            .fflags = flags_note,
            .data = 0,
            .udata = 0,
        };

        _ = try posix.kevent(self.kq, &kevs, &[0]posix.Kevent{}, null);
        try self.watched_paths.put(watched.path, watched);

        // Scan for TypeScript files
        try self.scanDirectory(dir_path);
    }

    pub fn watch(self: *KqueueWatcher, path: []const u8) !void {
        // Check if it's a directory
        const stat = try std.fs.cwd().statFile(path);
        const is_dir = stat.kind == .directory;

        if (is_dir) {
            try self.watchDirectory(path);
        } else {
            try self.watchSingleFile(path);
        }
    }

    pub fn unwatch(self: *KqueueWatcher, path: []const u8) void {
        if (self.watched_paths.get(path)) |watched| {
            posix.close(watched.fd);
            self.allocator.free(watched.path);
            self.allocator.destroy(watched);
            _ = self.watched_paths.remove(path);
        }
    }

    pub fn start(self: *KqueueWatcher) !void {
        if (self.running.load(.acquire)) return;

        self.running.store(true, .release);
        self.thread = try std.Thread.spawn(.{}, watcherThread, .{self});
    }

    pub fn stop(self: *KqueueWatcher) void {
        if (!self.running.load(.acquire)) return;

        self.running.store(false, .release);
        if (self.thread) |thread| {
            thread.join();
            self.thread = null;
        }
    }

    pub fn setCallback(self: *KqueueWatcher, callback: mod.WatchCallback) void {
        self.callback = callback;
    }

    fn watcherThread(self: *KqueueWatcher) void {
        // SAFETY: This array is only used within this function for temporary storage of kqueue events
        var events: [EVENTS_MAX]posix.Kevent = undefined;

        while (self.running.load(.acquire)) {
            const n = posix.kevent(
                self.kq,
                &[0]posix.Kevent{},
                &events,
                null,
            ) catch continue;

            for (events[0..@intCast(n)]) |event| {
                const fd = @as(i32, @intCast(event.ident));
                var it = self.watched_paths.iterator();
                while (it.next()) |entry| {
                    if (entry.value_ptr.*.fd == fd) {
                        // For directories, we need to handle new files
                        if (entry.value_ptr.*.is_dir and (event.fflags & c.NOTE_WRITE) != 0) {
                            self.scanDirectory(entry.value_ptr.*.path) catch continue;
                            continue;
                        }

                        const kind = if ((event.fflags & c.NOTE_DELETE) != 0)
                            mod.WatchEvent.EventKind.delete
                        else if ((event.fflags & c.NOTE_WRITE) != 0)
                            mod.WatchEvent.EventKind.modify
                        else if ((event.fflags & c.NOTE_RENAME) != 0)
                            mod.WatchEvent.EventKind.rename
                        else
                            continue;

                        const watch_event = mod.WatchEvent{
                            .path = entry.value_ptr.*.path,
                            .kind = kind,
                        };

                        if (self.callback) |cb| {
                            cb(watch_event);
                        }

                        // If the file was deleted or renamed, remove it from watched paths
                        if (kind == .delete or kind == .rename) {
                            self.unwatch(entry.value_ptr.*.path);
                        }
                    }
                }
            }
        }
    }
};
