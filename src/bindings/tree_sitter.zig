const std = @import("std");
pub const ts_typescript = @import("tree_sitter_typescript.zig");

/// The current version of the Tree-sitter language ABI
pub const LANGUAGE_VERSION = 14;

/// The minimum compatible version of the Tree-sitter language ABI
pub const MIN_COMPATIBLE_LANGUAGE_VERSION = 13;

/// Basic types used throughout the Tree-sitter API
pub const Symbol = u16;
pub const FieldId = u16;
pub const StateId = u16;

/// Point represents a row and column in source code
pub const Point = extern struct {
    row: u32,
    column: u32,
};

/// Input encoding options
pub const InputEncoding = enum(c_uint) {
    UTF8,
    UTF16,
};

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

/// Input structure for Tree-sitter parser
pub const Input = extern struct {
    payload: ?*anyopaque,
    read: fn (?*anyopaque, u32, Point, *u32) callconv(.C) [*:0]const u8,
    encoding: InputEncoding,

    /// Creates an Input from a byte slice
    pub fn fromSlice(allocator: std.mem.Allocator, slice: []const u8) !Input {
        if (slice.len > std.math.maxInt(u32)) {
            return error.LengthTooLarge;
        }

        const buffer = try SourceBuffer.init(allocator, slice);
        return Input{
            .payload = @ptrCast(buffer),
            .read = readFromString,
            .encoding = .UTF8,
        };
    }
};

/// Tree-sitter node range
pub const Range = extern struct {
    start_point: Point,
    end_point: Point,
    start_byte: u32,
    end_byte: u32,
};

/// Tree-sitter node structure
pub const Node = extern struct {
    context: [4]u32 align(4),
    id: u32,
    tree: ?*const Tree,
};

/// Tree cursor for traversing nodes
pub const TreeCursor = extern struct {
    tree: ?*const Tree,
    id: u32,
    context: [2]u32,
};

/// Tree-sitter language type
pub const Language = opaque {};

/// Tree-sitter parser type
pub const Parser = opaque {
    /// Creates a new parser
    pub extern fn ts_parser_new() ?*Parser;

    /// Deletes a parser
    pub extern fn ts_parser_delete(parser: *Parser) void;

    /// Sets the language for a parser
    pub extern fn ts_parser_set_language(parser: *Parser, language: *const Language) bool;

    /// Parses a string into a syntax tree
    pub extern fn ts_parser_parse_string(
        parser: *Parser,
        old_tree: ?*Tree,
        string: [*]const u8,
        length: u32,
    ) ?*Tree;

    /// Parses input into a syntax tree
    pub extern fn ts_parser_parse(parser: *Parser, old_tree: ?*const Tree, input: *const Input) ?*Tree;

    /// Sets the included ranges for a parser
    pub extern fn ts_parser_set_included_ranges(parser: *Parser, ranges: [*]const Range, length: u32) bool;
};

/// Tree-sitter tree type
pub const Tree = opaque {
    /// Deletes a tree
    pub extern fn ts_tree_delete(tree: *Tree) void;

    /// Gets the root node of a tree
    pub extern fn ts_tree_root_node(tree: *Tree) Node;

    /// Copies a tree
    pub extern fn ts_tree_copy(tree: *const Tree) *Tree;
};

/// Tree-sitter parser functions
pub extern fn ts_parser_new() ?*Parser;
pub extern fn ts_parser_delete(parser: *Parser) void;
pub extern fn ts_parser_set_language(parser: *Parser, language: *const Language) bool;
pub extern fn ts_parser_parse_string(parser: *Parser, old_tree: ?*Tree, string: [*]const u8, length: u32) ?*Tree;
pub extern fn ts_parser_parse(parser: *Parser, old_tree: ?*const Tree, input: *const Input) ?*Tree;
pub extern fn ts_parser_set_included_ranges(parser: *Parser, ranges: [*]const Range, length: u32) bool;

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

/// Node functions struct for convenience
pub const NodeFunctions = struct {
    ts_node_child: fn (node: Node, index: u32) Node,
    ts_node_child_count: fn (node: Node) u32,
    ts_node_named_child: fn (node: Node, index: u32) Node,
    ts_node_named_child_count: fn (node: Node) u32,
    ts_node_start_point: fn (node: Node) Point,
    ts_node_end_point: fn (node: Node) Point,
    ts_node_start_byte: fn (node: Node) u32,
    ts_node_end_byte: fn (node: Node) u32,
    ts_node_type: fn (node: Node) ?[*:0]const u8,
    ts_node_is_null: fn (node: Node) bool,
    ts_node_is_named: fn (node: Node) bool,
};

/// Read function for string input
pub export fn readFromString(payload: ?*anyopaque, byte_index: u32, position: Point, bytes_read: *u32) callconv(.C) [*:0]const u8 {
    _ = position; // Unused parameter required by tree-sitter API
    if (payload) |ptr| {
        const buffer = @as(*SourceBuffer, @alignCast(@ptrCast(ptr)));
        if (byte_index >= buffer.data.len) {
            bytes_read.* = 0;
            return "";
        }
        bytes_read.* = @intCast(buffer.data.len - byte_index);
        return @ptrCast(buffer.data.ptr + byte_index);
    }
    bytes_read.* = 0;
    return "";
}
