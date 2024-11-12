const std = @import("std");

pub const Config = struct {
    arena: std.heap.ArenaAllocator,
    target_dir: []const u8,
    output_name: ?[]const u8,
    recursive: bool,
    exclude_patterns: []const []const u8,
    preserve_comments: bool,
    sort_imports: bool,

    pub fn deinit(self: *Config) void {
        self.arena.deinit();
    }
};
