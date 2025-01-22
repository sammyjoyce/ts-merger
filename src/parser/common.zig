const std = @import("std");
const Node = @import("../ast/ast_types.zig").Node;

pub const Error = parser_mod.ParseError || error {
    InvalidSyntax,
    UnsupportedFeature,
    CircularDependency,
    FileNotFound,
    ParseFailure,
    ConflictingExports,
    InvalidNodeStructure,
    LanguageVersionMismatch,
    ParserCreationFailed
} || std.mem.Allocator.Error;

pub fn Parser(comptime ParseFn: type, comptime FormatFn: type) type {
    return struct {
        parse: ParseFn,
        format: FormatFn,

        pub fn init(parse_impl: ParseFn, format_impl: FormatFn) @This() {
            return .{
                .parse = parse_impl,
                .format = format_impl,
            };
        }
    };
}
    pub const ParseFn = *const fn ([]const u8) ParseError!*Node;
    pub const FormatFn = *const fn (*Node) ParseError![]const u8;

    parse_fn: ParseFn,
    format_fn: FormatFn,

    pub fn init(parse_func: ParseFn, format_func: FormatFn) Parser {
        return .{
            .parse_fn = parse_func,
            .format_fn = format_func,
        };
    }

    pub fn parse(self: *const Parser, source: []const u8) ParseError!*Node {
        return self.parse_fn(source);
    }

    pub fn format(self: *const Parser, node: *Node) ParseError![]const u8 {
        return self.format_fn(node);
    }
};
