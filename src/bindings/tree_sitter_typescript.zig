const std = @import("std");
const tree_sitter = @import("tree_sitter");
const Generated = @import("generated/typescript.zig");

extern "c" fn tree_sitter_typescript() *const tree_sitter.Language;

pub const Language = tree_sitter.Language;
pub const Parser = tree_sitter.Parser;
pub const Tree = tree_sitter.Tree;
pub const Node = tree_sitter.Node;
pub const TreeSitterError = tree_sitter.TreeSitterError;

pub const TypeScriptParser = struct {
    fn mapNodeType(ts_node_type: []const u8) ?Generated.NodeType {
        inline for (@typeInfo(Generated.NodeType).Enum.fields) |field| {
            if (std.mem.eql(u8, ts_node_type, field.name)) {
                return @field(Generated.NodeType, field.name);
            }
        }
        return null;
    }
    parser: Parser,
    language: *const Language,

    pub fn init(allocator: std.mem.Allocator) Error!TypeScriptParser {
        var parser = try Parser.init(allocator);
        errdefer parser.deinit();

        const language = tree_sitter_typescript();
        try parser.setLanguage(language);

        return .{
            .parser = parser,
            .language = language,
        };
    }

    pub fn deinit(self: *TypeScriptParser) void {
        self.parser.deinit();
    }

    pub fn parse(self: *TypeScriptParser, source: []const u8) Error!Tree {
        if (source.len == 0) return Error.InvalidSource;
        if (source.len > std.math.maxInt(u32)) return Error.InvalidSource;

        const tree_ptr = ts_parser_parse_string(self.parser.ptr, null, source.ptr, @intCast(source.len)) orelse return Error.ParseFailure;

        return Tree{ .ptr = tree_ptr, .parser = &self.parser };
    }
};

pub fn Parser_init() !*Parser {
    return tree_sitter.ts_parser_new() orelse error.ParserInitFailed;
}

extern "c" fn ts_parser_new() ?*Parser;
extern "c" fn ts_parser_delete(parser: *Parser) void;
extern "c" fn ts_parser_set_language(parser: *Parser, language: *const Language) bool;
extern "c" fn ts_parser_parse_string(parser: *Parser, old_tree: ?*Tree, string: [*]const u8, length: u32) ?*Tree;
pub const interface = @import("../parser/typescript.zig").interface;
