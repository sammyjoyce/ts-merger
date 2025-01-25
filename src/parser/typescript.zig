const std = @import("std");
const tree_sitter = @import("../bindings/tree_sitter.zig");
const ast_types = @import("ast_types");
const mod = @import("mod.zig");

pub const TypeScriptParser = struct {
    parser: *tree_sitter.Parser,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*TypeScriptParser {
        const parser = try tree_sitter.Parser_init();
        errdefer tree_sitter.ts_parser_delete(parser);

        if (!tree_sitter.ts_parser_set_language(parser, tree_sitter.ts_typescript.tree_sitter_typescript())) {
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

    pub fn parse(self: *TypeScriptParser, source: []const u8) !*ast_types.Node {
        if (source.len == 0) return error.EmptySource;
        if (source.len > std.math.maxInt(u32)) return error.SourceTooLarge;

        const tree = tree_sitter.ts_parser_parse_string(self.parser, null, source.ptr, @intCast(source.len)) orelse return error.ParseError;
        defer tree_sitter.ts_tree_delete(tree);

        const root = try ast_types.Node.init(self.allocator);
        errdefer root.deinit();

        root.kind = .{ .kind = .Program, .source = null };
        root.children = std.ArrayList(*ast_types.Node).init(self.allocator);

        const root_ts_node = tree_sitter.ts_tree_root_node(tree);
        if (tree_sitter.ts_node_is_null(root_ts_node)) return error.InvalidRootNode;

        var cursor = tree_sitter.ts_tree_cursor_new(root_ts_node);
        defer tree_sitter.ts_tree_cursor_delete(&cursor);

        if (tree_sitter.ts_tree_cursor_goto_first_child(&cursor)) {
            while (true) {
                const current = tree_sitter.ts_tree_cursor_current_node(&cursor);
                const node_type = tree_sitter.ts_node_type(current) orelse continue;

                const child = try ast_types.Node.init(self.allocator);
                errdefer child.deinit();

                const start_byte = tree_sitter.ts_node_start_byte(current);
                const end_byte = tree_sitter.ts_node_end_byte(current);
                const node_text = source[start_byte..end_byte];

                // Extract node name for declarations
                var name_value = node_text;
                if (std.mem.indexOf(u8, node_text, "interface ")) |interface_pos| {
                    name_value = node_text[interface_pos + "interface ".len ..];
                    if (std.mem.indexOf(u8, name_value, " ")) |space_pos| {
                        name_value = name_value[0..space_pos];
                    }
                } else if (std.mem.indexOf(u8, node_text, "class ")) |class_pos| {
                    name_value = node_text[class_pos + "class ".len ..];
                    if (std.mem.indexOf(u8, name_value, " ")) |space_pos| {
                        name_value = name_value[0..space_pos];
                    }
                }

                child.name = try self.allocator.dupe(u8, name_value);
                child.value = try self.allocator.dupe(u8, node_text);
                child.children = std.ArrayList(*ast_types.Node).init(self.allocator);
                child.dependencies = std.ArrayList(*ast_types.Node).init(self.allocator);
                child.dependents = std.ArrayList(*ast_types.Node).init(self.allocator);
                child.allocator = self.allocator;

                // Map tree-sitter node types to our AST node types
                child.kind = .{
                    .kind = if (std.mem.eql(u8, node_type, "interface_declaration")) .interface else if (std.mem.eql(u8, node_type, "class_declaration")) .class else if (std.mem.eql(u8, node_type, "function_declaration")) .function else if (std.mem.eql(u8, node_type, "export_statement")) .export_decl else if (std.mem.eql(u8, node_type, "import_statement")) .import_decl else .unknown,
                    .source = null,
                };

                try root.children.append(child);

                if (!tree_sitter.ts_tree_cursor_goto_next_sibling(&cursor)) break;
            }
        }

        return root;
    }
};

const testing = std.testing;

test "parse simple TypeScript file" {
    const allocator = testing.allocator;
    var ts_parser_impl = try TypeScriptParser.init(allocator);
    defer ts_parser_impl.deinit();

    var parser = mod.Parser.init(allocator, ts_parser_impl, &interface);
    defer parser.deinit();

    const source =
        \\ interface MyInterface {
        \\     field: string;
        \\ }
        \\ class MyClass {
        \\     method() {}
        \\ }
    ;

    const root_node = try parser.parse(source);
    defer root_node.deinit();
    defer allocator.destroy(root_node);

    // Iterate through children of the root node (Program) to find specific nodes
    var found_interface = false;
    var found_class = false;

    for (root_node.children.items) |node| {
        switch (node.kind.kind) {
            .Interface => {
                try testing.expectEqualStrings("MyInterface", node.name);
                found_interface = true;
            },
            .Class => {
                try testing.expectEqualStrings("MyClass", node.name);
                found_class = true;
            },
            else => {},
        }
    }

    try testing.expect(found_interface);
    try testing.expect(found_class);
}

test "parser memory management" {
    const allocator = testing.allocator;
    var ts_parser_impl = try TypeScriptParser.init(allocator);
    defer ts_parser_impl.deinit();

    var parser = mod.Parser.init(allocator, ts_parser_impl, &interface);
    defer parser.deinit();

    // Test memory management with large files
    var large_source = std.ArrayList(u8).init(allocator);
    defer large_source.deinit();

    // Create a large TypeScript file content
    try large_source.appendSlice("interface Test {");
    for (0..1000) |i| {
        const field = try std.fmt.allocPrint(allocator, "    field{d}: string;\n", .{i});
        defer allocator.free(field);
        try large_source.appendSlice(field);
    }
    try large_source.appendSlice("}");

    // Parse the large file and ensure proper cleanup
    const root_node = try parser.parse(large_source.items);
    defer root_node.deinit();
    defer allocator.destroy(root_node);

    try testing.expect(root_node.children.items.len > 0);
}
