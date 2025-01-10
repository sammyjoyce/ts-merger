const std = @import("std");

pub const LogLevel = enum {
    Debug,
    Info,
    Warning,
    Error,
};

pub const Logger = struct {
    level: LogLevel,
    scope: []const u8,

    pub fn init(level: LogLevel) Logger {
        return .{
            .level = level,
            .scope = "default",
        };
    }

    pub fn scoped(level: LogLevel, scope: []const u8) Logger {
        return .{
            .level = level,
            .scope = scope,
        };
    }

    pub fn LogLevelOrder(value: LogLevel) u8 {
        return switch (value) {
            .Debug => 0,
            .Info => 1,
            .Warning => 2,
            .Error => 3,
        };
    }

    pub fn debug(self: Logger, comptime format: []const u8, args: anytype) void {
        if (LogLevelOrder(self.level) <= LogLevelOrder(.Debug)) {
            std.log.debug("[{s}] " ++ format, .{self.scope} ++ args);
        }
    }

    pub fn info(self: Logger, comptime format: []const u8, args: anytype) void {
        if (@intFromEnum(self.level) <= @intFromEnum(LogLevel.Info)) {
            std.log.info("[{s}] " ++ format, args);
        }
    }

    pub fn warn(self: Logger, comptime format: []const u8, args: anytype) void {
        if (@intFromEnum(self.level) <= @intFromEnum(LogLevel.Warning)) {
            std.log.warn("[{s}] " ++ format, args);
        }
    }

    pub fn err(self: Logger, comptime format: []const u8, args: anytype) void {
        if (@intFromEnum(self.level) <= @intFromEnum(LogLevel.Error)) {
            std.log.err("[{s}] " ++ format, args);
        }
    }
};
