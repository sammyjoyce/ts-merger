const std = @import("std");
const tree_sitter = @import("tree_sitter");

extern "c" fn tree_sitter_typescript() *const tree_sitter.Language;

pub const Language = tree_sitter.Language;
pub const Parser = tree_sitter.Parser;
pub const Tree = tree_sitter.Tree;
pub const Node = tree_sitter.Node;
pub const TreeSitterError = tree_sitter.TreeSitterError;

pub const TypeScriptParser = struct {
    parser: *Parser,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*TypeScriptParser {
        const parser = try Parser_init();
        errdefer tree_sitter.ts_parser_delete(parser);

        if (!tree_sitter.ts_parser_set_language(parser, tree_sitter_typescript())) {
            return error.LanguageError;
        }

        const self = try allocator.create(TypeScriptParser);
        self.* = .{
            .parser = parser,
            .allocator = allocator,
        };
        return self;
    }

    pub fn deinit(self: *TypeScriptParser) void {
        tree_sitter.ts_parser_delete(self.parser);
        self.allocator.destroy(self);
    }

    pub fn parse(self: *TypeScriptParser, source: []const u8) !*Tree {
        if (source.len == 0) return error.EmptySource;
        if (source.len > std.math.maxInt(u32)) return error.SourceTooLarge;

        const tree = tree_sitter.ts_parser_parse_string(self.parser, null, source.ptr, @intCast(source.len)) orelse return error.ParseError;

        return tree;
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
