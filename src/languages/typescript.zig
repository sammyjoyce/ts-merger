const std = @import("std");
const Node = @import("../types.zig").Node;
const common = @import("common.zig");
const ts = @import("../bindings/tree_sitter.zig");

pub const TypeScriptParser = struct {
    allocator: std.mem.Allocator,
    tree_sitter: ts.Parser,

    pub fn init(allocator: std.mem.Allocator) !*TypeScriptParser {
        const parser = try allocator.create(TypeScriptParser);
        errdefer allocator.destroy(parser);

        var ts_parser = try ts.Parser.init(allocator);
        errdefer ts_parser.deinit();

        if (!ts_parser.setLanguage(ts.typescript.language())) {
            return error.LanguageVersionMismatch;
        }

        parser.* = .{
            .allocator = allocator,
            .tree_sitter = ts_parser,
        };
        return parser;
    }

    pub fn deinit(self: *TypeScriptParser) void {
        self.tree_sitter.deinit();
        self.allocator.destroy(self);
    }

    pub fn parse(self: *TypeScriptParser, source: []const u8) common.ParseError!*Node {
        const source_z = try self.allocator.dupeZ(u8, source);
        defer self.allocator.free(source_z);

        const input = ts.Input{
            .payload = @ptrCast(?*anyopaque, source_z.ptr),
            .read = readInput,
            .encoding = .UTF8,
            .decode = null,
        };

        const tree = self.tree_sitter.parseSourceString(source_z, "input.ts") orelse {
            return error.InvalidSyntax;
        };
        defer tree.deinit();

        const root_node = tree.rootNode();
        if (root_node.isNull()) {
            return error.InvalidSyntax;
        }

        return try self.convertNode(root_node);
    }

    fn convertNode(self: *TypeScriptParser, ts_node: ts.Node) !*Node {
        const node_type = try self.getNodeType(ts_node);
        const start_point = ts_node.startPoint();
        const end_point = ts_node.endPoint();

        var node = try Node.init(self.allocator, node_type, start_point.row, end_point.row);
        errdefer node.deinit(self.allocator);

        // Add children
        var i: u32 = 0;
        while (i < ts_node_named_child_count(ts_node)) : (i += 1) {
            const child = ts_node_named_child(ts_node, i);
            if (ts_node_is_null(child)) continue;
            const child_node = try self.convertNode(child);
            try node.addChild(child_node);
        }

        return node;
    }

    fn getNodeType(self: *TypeScriptParser, node: ts.Node) !Node.NodeType {
        const node_type = ts_node_type(node);
        const type_str = if (node_type) |type_ptr| std.mem.cStringUntilNull(type_ptr) else "";

        return switch (std.hash.Wyhash.hash(0, type_str)) {
            std.hash.Wyhash.hash(0, "program") => .Program,
            std.hash.Wyhash.hash(0, "interface_declaration") => .Interface,
            std.hash.Wyhash.hash(0, "class_declaration") => .Class,
            std.hash.Wyhash.hash(0, "function_declaration") => .Function,
            std.hash.Wyhash.hash(0, "variable_declaration") => .Variable,
            std.hash.Wyhash.hash(0, "import_declaration") => .Import,
            std.hash.Wyhash.hash(0, "export_statement") => .Export,
            else => .Unknown,
        };
    }
};

fn readInput(payload: ?*anyopaque, byte_offset: u32, position: ts.Point, bytes_read: *u32) callconv(.C) ?[*]const u8 {
    _ = position;
    const source = @ptrCast([*:0]const u8, @alignCast([*]const u8, payload.?));
    const source_len = std.mem.len(source);

    if (byte_offset >= source_len) {
        bytes_read.* = 0;
        return null;
    }

    bytes_read.* = @intCast(source_len - byte_offset, u32);
    return source + byte_offset;
}
