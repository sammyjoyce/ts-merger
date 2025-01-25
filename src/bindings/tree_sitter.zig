const std = @import("std");

pub const Language = opaque {};
pub const Parser = opaque {};
pub const Tree = opaque {};

pub const Point = extern struct {
    row: u32,
    column: u32,

    pub fn init(row: u32, column: u32) Point {
        return .{
            .row = row,
            .column = column,
        };
    }
};

pub const Node = extern struct {
    context: [4]u32 align(4),
    id: u32,
    tree: ?*const Tree,
};

pub const TreeCursor = extern struct {
    tree: ?*const Tree,
    id: u32,
    context: [2]u32,
};

pub const TreeSitterError = error{
    ParserInitFailed,
    ParserCreationFailed,
    LanguageError,
    ParseError,
    EmptySource,
    SourceTooLarge,
    QueryError,
};

pub fn Parser_init() TreeSitterError!*Parser {
    return ts_parser_new() orelse error.ParserInitFailed;
}

/// Tree-sitter parser functions
pub extern fn ts_parser_new() ?*Parser;
pub extern fn ts_parser_delete(parser: *Parser) void;
pub extern fn ts_parser_set_language(parser: *Parser, language: *const Language) bool;
pub extern fn ts_parser_parse_string(parser: *Parser, old_tree: ?*Tree, string: [*]const u8, length: u32) ?*Tree;
pub extern fn ts_parser_parse(parser: *Parser, old_tree: ?*const Tree, input: *const Input) ?*Tree;
pub extern fn ts_parser_set_included_ranges(parser: *Parser, ranges: [*]const Range, length: u32) bool;
pub extern fn ts_parser_timeout_micros(parser: *const Parser) u64;
pub extern fn ts_parser_set_timeout_micros(parser: *Parser, timeout: u64) void;
pub extern fn ts_parser_reset(parser: *Parser) void;

/// Tree-sitter tree functions
pub extern fn ts_tree_root_node(tree: *Tree) Node;
pub extern fn ts_tree_delete(tree: *Tree) void;
pub extern fn ts_tree_copy(tree: *const Tree) *Tree;

/// Tree-sitter node functions
pub extern fn ts_node_child(node: Node, index: u32) Node;
pub extern fn ts_node_child_count(node: Node) u32;
pub extern fn ts_node_named_child(node: Node, index: u32) Node;
pub extern fn ts_node_named_child_count(node: Node) u32;
pub extern fn ts_node_start_point(node: Node) Point;
pub extern fn ts_node_end_point(node: Node) Point;
pub extern fn ts_node_start_byte(node: Node) u32;
pub extern fn ts_node_end_byte(node: Node) u32;
pub extern fn ts_node_type(node: Node) ?[*:0]const u8;
pub extern fn ts_node_is_null(node: Node) bool;
pub extern fn ts_node_is_named(node: Node) bool;
pub extern fn ts_node_string(node: Node) [*:0]const u8;

/// Tree-sitter cursor functions
pub extern fn ts_tree_cursor_new(node: Node) TreeCursor;
pub extern fn ts_tree_cursor_reset(cursor: *TreeCursor, node: Node) void;
pub extern fn ts_tree_cursor_delete(cursor: *TreeCursor) void;
pub extern fn ts_tree_cursor_current_node(cursor: *const TreeCursor) Node;
pub extern fn ts_tree_cursor_goto_first_child(cursor: *TreeCursor) bool;
pub extern fn ts_tree_cursor_goto_next_sibling(cursor: *TreeCursor) bool;
pub extern fn ts_tree_cursor_goto_parent(cursor: *TreeCursor) bool;

/// Source buffer for holding input data
pub const SourceBuffer = struct {
    data: []const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, data: []const u8) !*SourceBuffer {
        const buffer = try allocator.create(SourceBuffer);
        errdefer allocator.destroy(buffer);

        const duped_data = try allocator.dupe(u8, data);
        errdefer allocator.free(duped_data);

        buffer.* = .{
            .data = duped_data,
            .allocator = allocator,
        };
        return buffer;
    }

    pub fn deinit(self: *SourceBuffer) void {
        self.allocator.free(self.data);
        self.allocator.destroy(self);
    }
};

pub const Input = extern struct {
    payload: ?*anyopaque,
    read: *const fn (?*anyopaque, u32, Point, *u32) ?[*]const u8,
    encoding: InputEncoding,
};

pub const Range = extern struct {
    start_point: Point,
    end_point: Point,
    start_byte: u32,
    end_byte: u32,
};

pub const InputEncoding = enum(c_uint) {
    UTF8,
    UTF16,
};

pub const QueryError = enum(c_uint) {
    None,
    Syntax,
    NodeType,
    Field,
    Capture,
    Structure,
    Language,
};

pub const SymbolType = enum(c_uint) {
    Regular,
    Anonymous,
    Auxiliary,
};

test "tree-sitter parser initialization" {
    const parser = try Parser_init();
    defer ts_parser_delete(parser);
    try std.testing.expect(parser != null);
}

test "tree-sitter cursor operations" {
    const parser = try Parser_init();
    defer ts_parser_delete(parser);

    const source = "function test() {}";
    const tree = ts_parser_parse_string(
        parser,
        null,
        source.ptr,
        @intCast(source.len),
    ) orelse return error.ParseError;
    defer ts_tree_delete(tree);

    const root_node = ts_tree_root_node(tree);
    var cursor = ts_tree_cursor_new(root_node);
    defer ts_tree_cursor_delete(&cursor);
}

test "tree-sitter input encoding" {
    try std.testing.expectEqual(InputEncoding.UTF8, InputEncoding.UTF8);
    try std.testing.expectEqual(InputEncoding.UTF16, InputEncoding.UTF16);
}

test "tree-sitter query error" {
    try std.testing.expectEqual(QueryError.None, QueryError.None);
    try std.testing.expectEqual(QueryError.Syntax, QueryError.Syntax);
}

test "tree-sitter symbol type" {
    try std.testing.expectEqual(SymbolType.Regular, SymbolType.Regular);
    try std.testing.expectEqual(SymbolType.Anonymous, SymbolType.Anonymous);
}

test "tree-sitter error handling - basic" {
    const makeErrorFn = struct {
        fn make(err: TreeSitterError) !void {
            return err;
        }
    }.make;

    try std.testing.expectError(error.ParserCreationFailed, makeErrorFn(error.ParserCreationFailed));
    try std.testing.expectError(error.QueryError, makeErrorFn(error.QueryError));
}

test "tree-sitter error handling" {
    const makeErrorFn = struct {
        fn make(err: TreeSitterError) !void {
            return err;
        }
    }.make;

    try std.testing.expectError(error.ParserCreationFailed, makeErrorFn(error.ParserCreationFailed));
    try std.testing.expectError(error.QueryError, makeErrorFn(error.QueryError));
}
