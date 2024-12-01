const std = @import("std");
const tree_sitter = @import("../bindings/tree_sitter.zig");
const ast = @import("../ast_types.zig");
const log = @import("../utils/log.zig");
const parser_mod = @import("mod.zig");

pub const TypeScriptParser = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    parser: ?*tree_sitter.Parser,
    source: ?[]const u8,
    logger: log.Logger,
    nodes: std.ArrayList(*ast.Node),

    pub fn init(allocator: std.mem.Allocator) !*Self {
        const parser = tree_sitter.ts_parser_new() orelse return error.ParserCreationFailed;
        errdefer tree_sitter.ts_parser_delete(parser);

        if (!tree_sitter.ts_parser_set_language(parser, tree_sitter.ts_typescript.language())) {
            tree_sitter.ts_parser_delete(parser);
            return error.LanguageSetFailed;
        }

        const self = try allocator.create(Self);
        errdefer allocator.destroy(self);
        
        self.* = .{
            .allocator = allocator,
            .parser = parser,
            .source = null,
            .logger = log.Logger.init(.Info),
            .nodes = std.ArrayList(*ast.Node).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Self) void {
        if (self.source) |source| {
            self.allocator.free(source);
        }
        for (self.nodes.items) |node| {
            node.deinit();
            self.allocator.destroy(node);
        }
        self.nodes.deinit();

        if (self.parser) |parser| {
            tree_sitter.ts_parser_delete(parser);
        }
        self.allocator.destroy(self);
    }

    pub fn parse(self: *Self, source: []const u8) !void {
        if (source.len == 0) {
            self.logger.err("Empty source", .{});
            return error.EmptySource;
        }

        // Clear any existing nodes
        for (self.nodes.items) |node| {
            node.deinit();
            self.allocator.destroy(node);
        }
        self.nodes.clearRetainingCapacity();

        if (self.source) |old_source| {
            self.allocator.free(old_source);
        }

        const new_source = try self.allocator.dupe(u8, source);
        errdefer self.allocator.free(new_source);

        self.source = new_source;

        // Parse source
        const tree = tree_sitter.ts_parser_parse_string(
            self.parser.?,
            null,  // old_tree
            source.ptr,
            @intCast(source.len)
        ) orelse {
            self.logger.err("Failed to parse source", .{});
            return error.ParseFailed;
        };
        defer tree_sitter.ts_tree_delete(tree);

        // Get root node
        const root_node = tree_sitter.ts_tree_root_node(tree);
        if (tree_sitter.ts_node_is_null(root_node)) {
            return error.RootNodeNull;
        }

        // Create cursor for traversal
        var cursor = tree_sitter.ts_tree_cursor_new(root_node);
        defer tree_sitter.ts_tree_cursor_delete(&cursor);

        // Process root node and build AST
        const ast_root = try self.processNode(self.allocator, root_node, &cursor);
        errdefer ast_root.deinit();

        try self.nodes.append(ast_root);
    }

    pub fn processNode(self: *Self, allocator: std.mem.Allocator, node: tree_sitter.Node, cursor: *tree_sitter.TreeCursor) parser_mod.ParseError!*ast.Node {
        const node_type = tree_sitter.ts_node_type(node);
        if (node_type) |type_str| {
            self.logger.debug("Processing node type: {s}", .{type_str});
        } else {
            self.logger.warn("Unknown node type encountered", .{});
        }

        // Create AST node
        const ast_node = try ast.Node.init(allocator);
        errdefer ast_node.deinit();

        // Set node type
        if (node_type) |type_str| {
            const type_slice = std.mem.span(type_str);
            ast_node.kind = .{
                .kind = try ast.nodeKindFromString(type_slice),
                .source = try allocator.dupe(u8, type_slice),
            };
        } else {
            return error.InvalidNodeType;
        }

        // Get node text for all nodes
        const start = tree_sitter.ts_node_start_byte(node);
        const end = tree_sitter.ts_node_end_byte(node);
        if (start < end and self.source != null) {
            const source = self.source.?;
            if (start < source.len and end <= source.len) {
                const node_text = source[start..end];
                std.debug.print("Node text for {s}: '{s}'\n", .{ node_type.?, node_text });
                
                // Store the node text
                ast_node.value = try allocator.dupe(u8, node_text);
            } else {
                std.debug.print("Warning: Node bounds out of range. start: {}, end: {}, source len: {}\n", 
                    .{ start, end, source.len });
            }
        }

        // Process children
        const child_count = tree_sitter.ts_node_named_child_count(node);
        if (child_count > 0) {
            try ast_node.children.ensureTotalCapacity(child_count);

            var success = tree_sitter.ts_tree_cursor_goto_first_child(cursor);
            while (success) : (success = tree_sitter.ts_tree_cursor_goto_next_sibling(cursor)) {
                const child_node = tree_sitter.ts_tree_cursor_current_node(cursor);
                if (!tree_sitter.ts_node_is_null(child_node)) {
                    const ast_child = try self.processNode(allocator, child_node, cursor);
                    try ast_node.children.append(ast_child);
                }
            }
            _ = tree_sitter.ts_tree_cursor_goto_parent(cursor);
        }

        return ast_node;
    }
};
