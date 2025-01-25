const std = @import("std");
const windows = std.os.windows;
const mod = @import("mod.zig");

const EVENTS_MAX = 32;
const FILE_NOTIFY_BUFFER_SIZE = 4096;

pub const WindowsWatcher = struct {
    allocator: std.mem.Allocator,
    watched_paths: std.StringHashMap(*WatchedPath),
    thread: ?std.Thread,
    running: std.atomic.Value(bool),
    callback: ?mod.WatchCallback,
    completion_port: windows.HANDLE,

    const WatchedPath = struct {
        path: []const u8,
        handle: windows.HANDLE,
        overlapped: windows.OVERLAPPED,
        // SAFETY: This buffer is properly aligned for FILE_NOTIFY_INFORMATION and is initialized before any I/O operations
        buffer: [FILE_NOTIFY_BUFFER_SIZE]u8 align(@alignOf(windows.FILE_NOTIFY_INFORMATION)) = undefined,
    };

    pub fn init(allocator: std.mem.Allocator) !WindowsWatcher {
        const completion_port = try windows.CreateIoCompletionPort(
            windows.INVALID_HANDLE_VALUE,
            null,
            0,
            0,
        );
        errdefer windows.CloseHandle(completion_port);

        return WindowsWatcher{
            .allocator = allocator,
            .watched_paths = std.StringHashMap(*WatchedPath).init(allocator),
            .thread = null,
            .running = std.atomic.Value(bool).init(false),
            .callback = null,
            .completion_port = completion_port,
        };
    }

    pub fn deinit(self: *WindowsWatcher) void {
        if (self.running.load(.acquire)) {
            self.stop();
        }

        var it = self.watched_paths.iterator();
        while (it.next()) |entry| {
            _ = windows.kernel32.CancelIo(entry.value_ptr.*.handle);
            windows.CloseHandle(entry.value_ptr.*.handle);
            self.allocator.free(entry.value_ptr.*.path);
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.watched_paths.deinit();
        windows.CloseHandle(self.completion_port);
    }

    pub fn watch(self: *WindowsWatcher, path: []const u8) !void {
        const handle = try windows.OpenFileW(
            try windows.sliceToPrefixedFileW(null, path),
            .{
                .dir = true,
                .access_mask = windows.FILE_LIST_DIRECTORY | windows.SYNCHRONIZE | windows.FILE_FLAG_BACKUP_SEMANTICS,
                .share_access = windows.FILE_SHARE_READ | windows.FILE_SHARE_WRITE | windows.FILE_SHARE_DELETE,
            },
        );
        errdefer windows.CloseHandle(handle);

        var watched = try self.allocator.create(WatchedPath);
        errdefer self.allocator.destroy(watched);

        watched.path = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(watched.path);
        watched.handle = handle;
        watched.overlapped = std.mem.zeroes(windows.OVERLAPPED);

        _ = try windows.CreateIoCompletionPort(
            handle,
            self.completion_port,
            @intFromPtr(watched),
            0,
        );

        try self.watched_paths.put(path, watched);
        try self.startWatching(watched);
    }

    pub fn unwatch(self: *WindowsWatcher, path: []const u8) void {
        if (self.watched_paths.get(path)) |watched| {
            _ = windows.kernel32.CancelIo(watched.handle);
            windows.CloseHandle(watched.handle);
            self.allocator.free(watched.path);
            self.allocator.destroy(watched);
            _ = self.watched_paths.remove(path);
        }
    }

    pub fn start(self: *WindowsWatcher) !void {
        if (self.running.load(.acquire)) return;

        self.running.store(true, .release);
        self.thread = try std.Thread.spawn(.{}, watcherThread, .{self});
    }

    pub fn stop(self: *WindowsWatcher) void {
        if (!self.running.load(.acquire)) return;

        self.running.store(false, .release);
        if (self.thread) |thread| {
            thread.join();
            self.thread = null;
        }
    }

    pub fn setCallback(self: *WindowsWatcher, callback: mod.WatchCallback) void {
        self.callback = callback;
    }

    fn startWatching(watched: *WatchedPath) !void {
        _ = try windows.ReadDirectoryChangesW(
            watched.handle,
            &watched.buffer,
            windows.FILE_NOTIFY_INFORMATION,
            false,
            windows.FILE_NOTIFY_CHANGE_FILE_NAME |
                windows.FILE_NOTIFY_CHANGE_DIR_NAME |
                windows.FILE_NOTIFY_CHANGE_ATTRIBUTES |
                windows.FILE_NOTIFY_CHANGE_SIZE |
                windows.FILE_NOTIFY_CHANGE_LAST_WRITE |
                windows.FILE_NOTIFY_CHANGE_CREATION |
                windows.FILE_NOTIFY_CHANGE_SECURITY,
            null,
            &watched.overlapped,
            null,
        );
    }

    fn watcherThread(self: *WindowsWatcher) !void {
        // SAFETY: This array is only used within this function for temporary storage of Windows events
        var events: [EVENTS_MAX]windows.OVERLAPPED_ENTRY = undefined;

        while (self.running.load(.acquire)) {
            var entries: windows.ULONG = 0;
            const success = windows.kernel32.GetQueuedCompletionStatusEx(
                self.completion_port,
                &events,
                events.len,
                &entries,
                windows.INFINITE,
                windows.FALSE,
            );
            if (success == windows.FALSE) continue;

            for (events[0..entries]) |event| {
                const watched = @as(*WatchedPath, @ptrFromInt(event.lpCompletionKey));
                var file_info: *windows.FILE_NOTIFY_INFORMATION = @ptrCast(&watched.buffer);

                while (true) {
                    const file_name = @as([*]u16, @ptrCast(&file_info.FileName))[0 .. file_info.FileNameLength / 2];
                    // SAFETY: This buffer is only used temporarily for UTF-16 to UTF-8 conversion
                    var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
                    const file_path = std.unicode.utf16leToUtf8(&path_buf, file_name) catch continue;

                    const kind = switch (file_info.Action) {
                        windows.FILE_ACTION_REMOVED => mod.WatchEvent.EventKind.delete,
                        windows.FILE_ACTION_MODIFIED => mod.WatchEvent.EventKind.modify,
                        windows.FILE_ACTION_RENAMED_OLD_NAME,
                        windows.FILE_ACTION_RENAMED_NEW_NAME,
                        => mod.WatchEvent.EventKind.rename,
                        else => continue,
                    };

                    const watch_event = mod.WatchEvent{
                        .path = std.fs.path.join(self.allocator, &[_][]const u8{ watched.path, file_path }) catch continue,
                        .kind = kind,
                    };

                    if (self.callback) |cb| {
                        cb(watch_event);
                        self.allocator.free(watch_event.path);
                    }

                    if (file_info.NextEntryOffset == 0) break;
                    file_info = @as(*windows.FILE_NOTIFY_INFORMATION, @ptrFromInt(@intFromPtr(file_info) + file_info.NextEntryOffset));
                }

                try self.startWatching(watched);
            }
        }
    }
};
