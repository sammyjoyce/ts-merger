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

    pub fn debug(self: Logger, comptime format: []const u8, args: anytype) void {
        if (@intFromEnum(self.level) <= @intFromEnum(LogLevel.Debug)) {
            std.log.debug("{s}: " ++ format, .{self.scope} ++ args);
        }
    }

    pub fn info(self: Logger, comptime format: []const u8, args: anytype) void {
        if (@intFromEnum(self.level) <= @intFromEnum(LogLevel.Info)) {
            std.log.info("{s}: " ++ format, .{self.scope} ++ args);
        }
    }

    pub fn warn(self: Logger, comptime format: []const u8, args: anytype) void {
        if (@intFromEnum(self.level) <= @intFromEnum(LogLevel.Warning)) {
            std.log.warn("{s}: " ++ format, .{self.scope} ++ args);
        }
    }

    pub fn err(self: Logger, comptime format: []const u8, args: anytype) void {
        if (@intFromEnum(self.level) <= @intFromEnum(LogLevel.Error)) {
            std.log.err("{s}: " ++ format, .{self.scope} ++ args);
        }
    }
};
