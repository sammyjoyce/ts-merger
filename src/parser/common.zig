const std = @import("std");
const Node = @import("../ast/ast_types.zig").Node;
const ParseError = @import("mod.zig").ParseError;

pub const Error = ParseError ||
    error{ EmptySource, InvalidNodeType, NoRootNode, SourceTooLarge, InvalidEncoding, OutOfMemory } || std.mem.Allocator.Error;

pub const LanguageMetadata = struct {
    id: u16,
    name: []const u8,
    extensions: []const []const u8,
    version: struct { major: u16, minor: u16, patch: u16 },
};

pub const ErrorDetails = struct {
    code: u16,
    message: []const u8,
    position: struct {
        line: u32,
        column: u32,
    },
};

pub fn ParserInterface(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,

        parse_fn: *const fn (*T, []const u8) Error!*Node,
        format_fn: *const fn (*T, *Node) Error![]const u8,

        pub const Self = @This();

        pub fn init(allocator: std.mem.Allocator, parse_impl: anytype, format_impl: anytype) Self {
            return .{
                .allocator = allocator,
                .parse_fn = parse_impl,
                .format_fn = format_impl,
            };
        }
    };
}
