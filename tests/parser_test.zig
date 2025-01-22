const std = @import("std");
const testing = std.testing;
const parser_mod = @import("parser/mod.zig");
const typescript = @import("parser/typescript.zig");
const common = @import("../src/parser/common.zig");

test "parse simple TypeScript file" {
    const allocator = testing.allocator;
    var ts_parser_impl = try typescript.TypeScriptParser.init(allocator);
    defer ts_parser_impl.deinit();
    var ts_parser = parser_mod.Parser.init(allocator, ts_parser_impl);
    defer ts_parser.deinit();

    const source = try std.testing.readFile("tests/fixtures/simple.ts");
    const root_node = try ts_parser.parse(source);

    // Iterate through children of the root node (Program) to find specific nodes
    var found_interface = false;
    var found_class = false;
    var found_function = false;
    var found_export = false;
    var found_import = false;

    for (root_node.children.items) |node| {
        switch (node.kind.kind) {
            .interface => {
                try testing.expectEqualStrings("MyInterface", node.value);
                found_interface = true;
            },
            .class => {
                try testing.expectEqualStrings("MyClass", node.value);
                found_class = true;
            },
            .function => {
                try testing.expectEqualStrings("helper", node.value);
                found_function = true;
            },
            .export_decl => {
                // Exported entity name might be in a child node
                if (node.children.len > 0 and std.mem.eql(u8, node.children.items[0].value, "instance")) {
                    found_export = true;
                }
            },
            .import_decl => {
                // Imported module name might be in a child node
                if (node.children.len > 0 and std.mem.eql(u8, node.children.items[0].value, "Something")) {
                    found_import = true;
                }
            },
            else => {},
        }
    }

    try testing.expect(found_interface);
    try testing.expect(found_class);
    try testing.expect(found_function);
    try testing.expect(found_export);
    try testing.expect(found_import);

    root_node.deinit();
    allocator.destroy(root_node);
}

test "parse complex TypeScript file" {
    const allocator = testing.allocator;
    var ts_parser_impl = try typescript.TypeScriptParser.init(allocator);
    defer ts_parser_impl.deinit();
    var ts_parser = parser_mod.Parser.init(allocator, ts_parser_impl);
    defer ts_parser.deinit();

    const source = try std.testing.readFile("tests/fixtures/complex.ts");
    const root_node = try ts_parser.parse(source);
    defer root_node.deinit();
    defer allocator.destroy(root_node);

    // Helper function to find a node by name within children
    fn findChildNodeByName(nodes: []const *parser_mod.Node, name: []const u8) ?*parser_mod.Node {
        for (nodes) |node| {
            if (std.mem.eql(u8, node.value, name)) {
                return node;
            }
        }
        return null;
    }

    // Test generic class
    const container = findChildNodeByName(root_node.children.items, "Container") orelse null;
    try testing.expect(container != null);
    try testing.expectEqual(parser_mod.NodeKind.class, container.kind.kind);

    // Test interfaces
    const base_storage = findChildNodeByName(root_node.children.items, "BaseStorage") orelse {
        try testing.expect(false);
        return;
    };
    try testing.expectEqual(parser_mod.NodeKind.interface, base_storage.kind.kind);

    const logger = findChildNodeByName(root_node.children.items, "Logger") orelse {
        try testing.expect(false);
        return;
    };
    try testing.expectEqual(parser_mod.NodeKind.interface, logger.kind.kind);

    const storage_with_logging = findChildNodeByName(root_node.children.items, "StorageWithLogging") orelse {
        try testing.expect(false);
        return;
    };
    try testing.expectEqual(parser_mod.NodeKind.interface, storage_with_logging.kind.kind);

    // Test abstract class
    const base_service = findChildNodeByName(root_node.children.items, "BaseService") orelse {
        try testing.expect(false);
        return;
    };
    try testing.expectEqual(parser_mod.NodeKind.class, base_service.kind.kind);

    // Test namespace
    const storage = findChildNodeByName(root_node.children.items, "Storage") orelse {
        try testing.expect(false);
        return;
    };
    try testing.expectEqual(parser_mod.NodeKind.namespace, storage.kind.kind);

    // Test exported function
    const process_items = findChildNodeByName(root_node.children.items, "processItems") orelse {
        try testing.expect(false);
        return;
    };
    try testing.expectEqual(parser_mod.NodeKind.function, process_items.kind.kind);
}

test "test error handling" {
    const allocator = testing.allocator;
    var ts_parser_impl = try typescript.TypeScriptParser.init(allocator);
    defer ts_parser_impl.deinit();
    var ts_parser = parser_mod.Parser.init(allocator, ts_parser_impl);
    defer ts_parser.deinit();

    // Test parsing non-existent file
    const non_existent_file_result = std.fs.cwd().openFile("non_existent.ts", .{});
    try testing.expectError(std.fs.File.Error.FileNotFound, non_existent_file_result);

    // Test parsing invalid TypeScript
    const invalid_code = "class { invalid";
    const parse_result = ts_parser.parse(invalid_code);
    try testing.expectError(common.Error.ParseFailed, parse_result);
}

test "test memory management" {
    const allocator = testing.allocator;
    var ts_parser_impl = try typescript.TypeScriptParser.init(allocator);
    defer ts_parser_impl.deinit();
    var ts_parser = parser_mod.Parser.init(allocator, ts_parser_impl);
    defer ts_parser.deinit();

    // Parse multiple files to test memory management
    const simple_source = try std.testing.readFile("tests/fixtures/simple.ts");
    const other_source = try std.testing.readFile("tests/fixtures/other.ts");
    const complex_source = try std.testing.readFile("tests/fixtures/complex.ts");

    var root_node1 = try ts_parser.parse(simple_source);
    defer root_node1.deinit();
    defer allocator.destroy(root_node1);
    var root_node2 = try ts_parser.parse(other_source);
    defer root_node2.deinit();
    defer allocator.destroy(root_node2);
    var root_node3 = try ts_parser.parse(complex_source);
    defer root_node3.deinit();
    defer allocator.destroy(root_node3);
}