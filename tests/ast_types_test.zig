const std = @import("std");
const testing = std.testing;
const ast = @import("ast_types");

test "create and manipulate FlowNode" {
    const allocator = testing.allocator;

    var node = try ast.FlowNode.init(allocator, "TestNode", .class);
    defer node.deinit(allocator);

    try testing.expectEqualStrings("TestNode", node.name);
    try testing.expectEqual(ast.NodeKind.class, node.kind);
    try testing.expectEqual(@as(usize, 0), node.dependencies.items.len);
    try testing.expectEqual(@as(usize, 0), node.references.items.len);
}

test "add dependencies to FlowNode" {
    const allocator = testing.allocator;

    var node1 = try ast.FlowNode.init(allocator, "Node1", .class);
    defer node1.deinit(allocator);

    var node2 = try ast.FlowNode.init(allocator, "Node2", .interface);
    defer node2.deinit(allocator);

    try node1.dependencies.append(node2);
    try testing.expectEqual(@as(usize, 1), node1.dependencies.items.len);
    try testing.expectEqual(node2, node1.dependencies.items[0]);
}

test "add references to FlowNode" {
    const allocator = testing.allocator;

    var node1 = try ast.FlowNode.init(allocator, "Node1", .class);
    defer node1.deinit(allocator);

    var node2 = try ast.FlowNode.init(allocator, "Node2", .interface);
    defer node2.deinit(allocator);

    try node1.references.append(node2);
    try testing.expectEqual(@as(usize, 1), node1.references.items.len);
    try testing.expectEqual(node2, node1.references.items[0]);
}

test "node location" {
    const allocator = testing.allocator;

    var node = try ast.FlowNode.init(allocator, "TestNode", .class);
    defer node.deinit(allocator);

    node.location = .{
        .file = "test.ts",
        .start = .{ .line = 1, .column = 0 },
        .end = .{ .line = 5, .column = 10 },
    };

    try testing.expectEqualStrings("test.ts", node.location.file);
    try testing.expectEqual(@as(u32, 1), node.location.start.line);
    try testing.expectEqual(@as(u32, 0), node.location.start.column);
    try testing.expectEqual(@as(u32, 5), node.location.end.line);
    try testing.expectEqual(@as(u32, 10), node.location.end.column);
}

test "node kind conversion" {
    try testing.expectEqual(ast.NodeKind.class, std.meta.stringToEnum(ast.NodeKind, "class").?);
    try testing.expectEqual(ast.NodeKind.interface, std.meta.stringToEnum(ast.NodeKind, "interface").?);
    try testing.expectEqual(ast.NodeKind.function, std.meta.stringToEnum(ast.NodeKind, "function").?);
    try testing.expectEqual(ast.NodeKind.variable, std.meta.stringToEnum(ast.NodeKind, "variable").?);
    try testing.expectEqual(ast.NodeKind.import_decl, std.meta.stringToEnum(ast.NodeKind, "import_decl").?);
    try testing.expectEqual(ast.NodeKind.export_decl, std.meta.stringToEnum(ast.NodeKind, "export_decl").?);
    try testing.expectEqual(ast.NodeKind.namespace, std.meta.stringToEnum(ast.NodeKind, "namespace").?);
}
