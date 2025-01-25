const std = @import("std");
const libxev = @import("libxev");

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

/// File system watcher
pub const Watcher = struct {
    allocator: std.mem.Allocator,
    loop: *libxev.Loop,
    comp: libxev.Completion,
    callback: ?WatchCallback,
    watched: std.StringHashMap(*libxev.FileEvent),

    pub fn init(allocator: std.mem.Allocator) !Watcher {
        return Watcher{
            .allocator = allocator,
            .loop = try libxev.Loop.init(.{}),
            .comp = undefined,
            .callback = null,
            .watched = std.StringHashMap(*libxev.FileEvent).init(allocator),
        };
    }

    pub fn deinit(self: *Watcher) void {
        var it = self.watched.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
            self.allocator.destroy(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.watched.deinit();
        self.loop.deinit();
    }

    pub fn watch(self: *Watcher, path: []const u8) !void {
        const w = try self.allocator.create(libxev.FileEvent);
        errdefer self.allocator.destroy(w);
        w.* = try libxev.FileEvent.init();

        const path_copy = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(path_copy);

        try w.add(
            self.loop,
            &self.comp,
            .{
                .path = path_copy,
                .flags = .{
                    .delete = true,
                    .write = true,
                    .rename = true,
                    .attrib = true,
                },
            },
            void,
            null,
            handleEvent,
            self,
        );

        try self.watched.put(path_copy, w);
    }

    pub fn unwatch(self: *Watcher, path: []const u8) void {
        if (self.watched.get(path)) |w| {
            w.deinit();
            self.allocator.destroy(w);
            _ = self.watched.remove(path);
        }
    }

    pub fn start(self: *Watcher) !void {
        _ = try std.Thread.spawn(.{}, runLoop, .{self});
    }

    pub fn stop(self: *Watcher) void {
        self.loop.stop();
    }

    fn runLoop(self: *Watcher) void {
        self.loop.run(.until_done) catch |err| {
            std.log.err("Watcher loop failed: {}", .{err});
        };
    }

    fn handleEvent(
        userdata: ?*anyopaque,
        loop: *libxev.Loop,
        comp: *libxev.Completion,
        res: libxev.FileEvent.Result,
    ) libxev.CallbackAction {
        _ = loop;
        _ = comp;
        const self = @as(*Watcher, @ptrCast(@alignCast(userdata.?)));

        const kind: WatchEvent.EventKind = if (res.err) |err| switch (err) {
            error.FileDeleted => .delete,
            else => .modify,
        } else .modify;

        if (self.callback) |cb| {
            cb(.{
                .path = res.path,
                .kind = kind,
            });
        }
        return .rearm;
    }

    pub fn setCallback(self: *Watcher, callback: WatchCallback) void {
        self.callback = callback;
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

    // Add proper synchronization
    var done = std.Thread.ResetEvent{};
    defer done.deinit();

    w.setCallback(struct {
        fn cb(event: WatchEvent) void {
            TestContext.onEvent(event);
            done.set();
        }
    }.cb);

    try w.start();

    try tmp_dir.dir.writeFile("test.ts", "test content");

    // Wait for event or timeout
    try testing.expect(try done.wait(std.time.ns_per_s * 2));
    try testing.expect(TestContext.findEvent(.modify));

    w.stop();
}
