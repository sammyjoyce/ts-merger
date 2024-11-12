const std = @import("std");
const ast = @import("../ast_types.zig");

pub const ParseError = error{
    OutOfMemory,
    InvalidSyntax,
    UnsupportedFeature,
    ParserInitFailed,
    ParsingFailed,
    InvalidNodeType,
    InvalidNodeRange,
    InvalidRootNode,
    NullPointer,
    LengthTooLarge,
    EmptySource,
    FileReadError,
    FileWriteError,
    AllocationError,
    InvalidEncoding,
    SourceBufferInitFailed,
    TooManyChildren,
};

/// Generic parser interface that can be implemented for different languages
pub const Parser = struct {
    pub const ParseFn = *const fn ([]const u8) ParseError!*ast.Node;
    pub const FormatFn = *const fn (*ast.Node) ParseError![]const u8;

    parse_fn: ParseFn,
    format_fn: FormatFn,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, parse_func: ParseFn, format_func: FormatFn) Parser {
        return .{
            .parse_fn = parse_func,
            .format_fn = format_func,
            .allocator = allocator,
        };
    }

    pub fn parse(self: *const Parser, source: []const u8) ParseError!*ast.Node {
        return self.parse_fn(source);
    }

    pub fn format(self: *const Parser, node: *ast.Node) ParseError![]const u8 {
        return self.format_fn(node);
    }
};
