const std = @import("std");
const testing = std.testing;
const parser = @import("parser");

test "parse simple TypeScript file" {
    const allocator = testing.allocator;
    var ts_parser = try parser.Parser.init(allocator);
    defer ts_parser.deinit();

    try ts_parser.parseFile("tests/fixtures/simple.ts");

    // Test that we found all the nodes
    var found_interface = false;
    var found_class = false;
    var found_function = false;
    var found_export = false;
    var found_import = false;

    for (ts_parser.nodes.items) |node| {
        switch (node.kind) {
            .interface => {
                try testing.expectEqualStrings("MyInterface", node.name);
                found_interface = true;
            },
            .class => {
                try testing.expectEqualStrings("MyClass", node.name);
                found_class = true;
            },
            .function => {
                try testing.expectEqualStrings("helper", node.name);
                found_function = true;
            },
            .export_decl => {
                try testing.expectEqualStrings("instance", node.name);
                found_export = true;
            },
            .import_decl => {
                try testing.expectEqualStrings("Something", node.name);
                found_import = true;
            },
            else => {},
        }
    }

    try testing.expect(found_interface);
    try testing.expect(found_class);
    try testing.expect(found_function);
    try testing.expect(found_export);
    try testing.expect(found_import);
}

test "parse complex TypeScript file" {
    const allocator = testing.allocator;
    var ts_parser = try parser.Parser.init(allocator);
    defer ts_parser.deinit();

    try ts_parser.parseFile("tests/fixtures/complex.ts");

    // Test generic class
    const container = findNode(ts_parser.nodes.items, "Container") orelse {
        try testing.expect(false);
        return;
    };
    try testing.expectEqual(parser.NodeKind.class, container.kind);
    try testing.expect(container.dependencies.items.len > 0);

    // Test interfaces
    const base_storage = findNode(ts_parser.nodes.items, "BaseStorage") orelse {
        try testing.expect(false);
        return;
    };
    try testing.expectEqual(parser.NodeKind.interface, base_storage.kind);

    const logger = findNode(ts_parser.nodes.items, "Logger") orelse {
        try testing.expect(false);
        return;
    };
    try testing.expectEqual(parser.NodeKind.interface, logger.kind);

    const storage_with_logging = findNode(ts_parser.nodes.items, "StorageWithLogging") orelse {
        try testing.expect(false);
        return;
    };
    try testing.expectEqual(parser.NodeKind.interface, storage_with_logging.kind);
    try testing.expect(storage_with_logging.dependencies.items.len >= 2);

    // Test abstract class
    const base_service = findNode(ts_parser.nodes.items, "BaseService") orelse {
        try testing.expect(false);
        return;
    };
    try testing.expectEqual(parser.NodeKind.class, base_service.kind);
    try testing.expect(base_service.dependencies.items.len > 0);

    // Test namespace
    const storage = findNode(ts_parser.nodes.items, "Storage") orelse {
        try testing.expect(false);
        return;
    };
    try testing.expectEqual(parser.NodeKind.namespace, storage.kind);

    // Test exported function
    const process_items = findNode(ts_parser.nodes.items, "processItems") orelse {
        try testing.expect(false);
        return;
    };
    try testing.expectEqual(parser.NodeKind.function, process_items.kind);
}

test "test error handling" {
    const allocator = testing.allocator;
    var ts_parser = try parser.Parser.init(allocator);
    defer ts_parser.deinit();

    // Test parsing non-existent file
    try testing.expectError(error.FileNotFound, ts_parser.parseFile("non_existent.ts"));

    // Test parsing invalid TypeScript
    try testing.expectError(error.ParsingFailed, ts_parser.parseString("class { invalid", "test.ts"));
}

test "test memory management" {
    const allocator = testing.allocator;
    var ts_parser = try parser.Parser.init(allocator);
    defer ts_parser.deinit();

    // Parse multiple files to test memory management
    try ts_parser.parseFile("tests/fixtures/simple.ts");
    try ts_parser.parseFile("tests/fixtures/other.ts");
    try ts_parser.parseFile("tests/fixtures/complex.ts");

    // Clear nodes and verify memory is freed
    ts_parser.clearNodes();
    try testing.expectEqual(@as(usize, 0), ts_parser.nodes.items.len);
}

fn findNode(nodes: []const *parser.FlowNode, name: []const u8) ?*parser.FlowNode {
    for (nodes) |node| {
        if (std.mem.eql(u8, node.name, name)) {
            return node;
        }
    }
    return null;
}
