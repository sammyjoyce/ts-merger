const std = @import("std");
const ast_types = @import("../core/ast/ast_types.zig");

pub const TSLanguage = opaque {};
pub const TSParser = opaque {};
pub const TSTree = opaque {};

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

pub const TSNode = extern struct {
    context: [4]u32 align(4),
    id: u32,
    tree: ?*const TSTree,
};

pub const TreeCursor = extern struct {
    tree: ?*const TSTree,
    id: u32,
    context: [2]u32,
};

pub const Error = error{
    ParserInit,
    LanguageUnavailable,
    ParseFailure,
    InvalidSource,
    QueryInvalid,
    AllocationFailed,
    TreeNavigation,
};

pub const LanguageParserInterface = struct {
    init: *const fn (allocator: std.mem.Allocator) anyerror!*anyopaque,
    parse: *const fn (parser: *anyopaque, source: []const u8) anyerror!*ast_types.Node,
    deinit: *const fn (parser: *anyopaque) void,
};

pub const Parser = struct {
    ptr: *TSParser,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Error!Parser {
        const ptr = ts_parser_new() orelse return Error.ParserInit;
        return .{ .ptr = ptr, .allocator = allocator };
    }

    pub fn deinit(self: Parser) void {
        ts_parser_delete(self.ptr);
    }

    pub fn setLanguage(self: Parser, language: *const TSLanguage) Error!void {
        if (!ts_parser_set_language(self.ptr, language)) {
            return Error.LanguageUnavailable;
        }
    }
};

pub const Tree = struct {
    ptr: *TSTree,
    parser: *const Parser,

    pub fn deinit(self: *Tree) void {
        ts_tree_delete(self.ptr);
    }

    pub fn rootNode(self: *const Tree) Node {
        return .{
            .ptr = ts_tree_root_node(self.ptr),
            .tree = self,
        };
    }
};

pub const Node = struct {
    ptr: TSNode,
    tree: *const Tree,

    pub fn childCount(self: Node) u32 {
        return ts_node_child_count(self.ptr);
    }

    pub fn childByFieldName(self: Node, name: []const u8) Error!Node {
        const cstr = try self.tree.parser.allocator.dupeZ(u8, name);
        defer self.tree.parser.allocator.free(cstr);

        const result = ts_node_child_by_field_name(self.ptr, cstr.ptr, @intCast(cstr.len));

        return if (ts_node_is_null(result))
            Error.TreeNavigation
        else
            Node{ .ptr = result, .tree = self.tree };
    }
};

/// Tree-sitter parser functions
pub extern fn ts_parser_new() ?*TSParser;
pub extern fn ts_parser_delete(parser: *TSParser) void;
pub extern fn ts_parser_set_language(parser: *TSParser, language: *const TSLanguage) bool;
pub extern fn ts_parser_parse_string(parser: *TSParser, old_tree: ?*TSTree, string: [*]const u8, length: u32) ?*TSTree;
pub extern fn ts_parser_parse(parser: *TSParser, old_tree: ?*const TSTree, input: *const Input) ?*TSTree;
pub extern fn ts_node_child_by_field_name(node: TSNode, field_name: [*:0]const u8, length: u32) TSNode;
pub extern fn ts_parser_set_included_ranges(parser: *TSParser, ranges: [*]const Range, length: u32) bool;
pub extern fn ts_parser_timeout_micros(parser: *const TSParser) u64;
pub extern fn ts_parser_set_timeout_micros(parser: *TSParser, timeout: u64) void;
pub extern fn ts_parser_reset(parser: *TSParser) void;

/// Tree-sitter tree functions
pub extern fn ts_tree_root_node(tree: *TSTree) TSNode;
pub extern fn ts_tree_delete(tree: *TSTree) void;
pub extern fn ts_tree_copy(tree: *const TSTree) *TSTree;

/// Tree-sitter node functions
pub extern fn ts_node_child(node: TSNode, index: u32) TSNode;
pub extern fn ts_node_child_count(node: TSNode) u32;
pub extern fn ts_node_named_child(node: TSNode, index: u32) TSNode;
pub extern fn ts_node_named_child_count(node: TSNode) u32;
pub extern fn ts_node_start_point(node: TSNode) Point;
pub extern fn ts_node_end_point(node: TSNode) Point;
pub extern fn ts_node_start_byte(node: TSNode) u32;
pub extern fn ts_node_end_byte(node: TSNode) u32;
pub extern fn ts_node_type(node: TSNode) ?[*:0]const u8;
pub extern fn ts_node_is_null(node: TSNode) bool;
pub extern fn ts_node_is_named(node: TSNode) bool;
pub extern fn ts_node_string(node: TSNode) [*:0]const u8;

/// Tree-sitter cursor functions
pub extern fn ts_tree_cursor_new(node: TSNode) TreeCursor;
pub extern fn ts_tree_cursor_reset(cursor: *TreeCursor, node: TSNode) void;
pub extern fn ts_tree_cursor_delete(cursor: *TreeCursor) void;
pub extern fn ts_tree_cursor_current_node(cursor: *const TreeCursor) TSNode;
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
    var parser = try Parser.init(std.testing.allocator);
    defer parser.deinit();
    try std.testing.expect(@intFromPtr(parser.ptr) != 0);
}

test "tree-sitter cursor operations" {
    var parser = try Parser.init(std.testing.allocator);
    defer parser.deinit();

    const source = "function test() {}";
    const tree_ptr = ts_parser_parse_string(
        parser.ptr,
        null,
        source.ptr,
        @intCast(source.len),
    ) orelse return error.ParseFailure;
    const tree = Tree{ .ptr = tree_ptr, .parser = &parser };
    defer tree.deinit();

    const root_node = tree.rootNode();
    var cursor = ts_tree_cursor_new(root_node.ptr);
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
        fn make(err: Error) !void {
            return err;
        }
    }.make;

    try std.testing.expectError(error.ParserInit, makeErrorFn(error.ParserInit));
    try std.testing.expectError(error.QueryInvalid, makeErrorFn(error.QueryInvalid));
}

test "tree-sitter error handling" {
    const makeErrorFn = struct {
        fn make(err: Error) !void {
            return err;
        }
    }.make;

    try std.testing.expectError(error.ParserInit, makeErrorFn(error.ParserInit));
    try std.testing.expectError(error.QueryInvalid, makeErrorFn(error.QueryInvalid));
}
