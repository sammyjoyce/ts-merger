const std = @import("std");
const testing = std.testing;
const parser = @import("parser");
const flow = @import("flow");

test "merge TypeScript files" {
    const allocator = testing.allocator;
    var ts_parser = try parser.Parser.init(allocator);
    defer ts_parser.deinit();

    var flow_graph = flow.FlowGraph.init(allocator);
    defer flow_graph.deinit();

    // Parse both files
    try ts_parser.parseFile("tests/fixtures/simple.ts");
    try ts_parser.parseFile("tests/fixtures/other.ts");

    // Add nodes to flow graph
    for (ts_parser.nodes.items) |node| {
        try flow_graph.addNode(node);
    }

    // Test that we can find nodes
    const something = flow_graph.findNodeByName("Something") orelse {
        try testing.expect(false);
        return;
    };
    try testing.expectEqual(parser.NodeKind.class, something.kind);

    const my_class = flow_graph.findNodeByName("MyClass") orelse {
        try testing.expect(false);
        return;
    };
    try testing.expectEqual(parser.NodeKind.class, my_class.kind);

    // Test flow traversal
    var instance_flow = try flow_graph.getFlowForNode(something);
    defer instance_flow.deinit();

    // Something should be used by OtherInterface and createSomething
    var found_interface = false;
    var found_function = false;
    for (instance_flow.items) |node| {
        if (std.mem.eql(u8, node.name, "OtherInterface")) {
            found_interface = true;
        } else if (std.mem.eql(u8, node.name, "createSomething")) {
            found_function = true;
        }
    }
    try testing.expect(found_interface);
    try testing.expect(found_function);
}

test "complex dependency flow" {
    const allocator = testing.allocator;
    var ts_parser = try parser.Parser.init(allocator);
    defer ts_parser.deinit();

    var flow_graph = flow.FlowGraph.init(allocator);
    defer flow_graph.deinit();

    // Parse complex TypeScript file
    try ts_parser.parseFile("tests/fixtures/complex.ts");

    // Add nodes to flow graph
    for (ts_parser.nodes.items) |node| {
        try flow_graph.addNode(node);
    }

    // Test interface inheritance flow
    const storage_with_logging = flow_graph.findNodeByName("StorageWithLogging") orelse {
        try testing.expect(false);
        return;
    };

    var interface_flow = try flow_graph.getFlowForNode(storage_with_logging);
    defer interface_flow.deinit();

    // StorageWithLogging should depend on BaseStorage and Logger
    var found_base_storage = false;
    var found_logger = false;
    for (interface_flow.items) |node| {
        if (std.mem.eql(u8, node.name, "BaseStorage")) {
            found_base_storage = true;
        } else if (std.mem.eql(u8, node.name, "Logger")) {
            found_logger = true;
        }
    }
    try testing.expect(found_base_storage);
    try testing.expect(found_logger);

    // Test class implementation flow
    const base_service = flow_graph.findNodeByName("BaseService") orelse {
        try testing.expect(false);
        return;
    };

    var class_flow = try flow_graph.getFlowForNode(base_service);
    defer class_flow.deinit();

    // BaseService should implement StorageWithLogging
    var implements_interface = false;
    for (class_flow.items) |node| {
        if (std.mem.eql(u8, node.name, "StorageWithLogging")) {
            implements_interface = true;
            break;
        }
    }
    try testing.expect(implements_interface);

    // Test namespace dependencies
    const storage = flow_graph.findNodeByName("Storage") orelse {
        try testing.expect(false);
        return;
    };

    var namespace_flow = try flow_graph.getFlowForNode(storage);
    defer namespace_flow.deinit();

    // Storage namespace should contain Config and FileStorage
    var found_config = false;
    var found_file_storage = false;
    for (namespace_flow.items) |node| {
        if (std.mem.eql(u8, node.name, "Config")) {
            found_config = true;
        } else if (std.mem.eql(u8, node.name, "FileStorage")) {
            found_file_storage = true;
        }
    }
    try testing.expect(found_config);
    try testing.expect(found_file_storage);
}

test "cyclic dependency detection" {
    const allocator = testing.allocator;
    var flow_graph = flow.FlowGraph.init(allocator);
    defer flow_graph.deinit();

    // Create nodes with cyclic dependencies
    var node1 = try createFlowNode(allocator, "Node1", .class);
    defer node1.deinit(allocator);
    var node2 = try createFlowNode(allocator, "Node2", .class);
    defer node2.deinit(allocator);
    var node3 = try createFlowNode(allocator, "Node3", .class);
    defer node3.deinit(allocator);

    try node1.dependencies.append(node2);
    try node2.dependencies.append(node3);
    try node3.dependencies.append(node1);

    try flow_graph.addNode(node1);
    try flow_graph.addNode(node2);
    try flow_graph.addNode(node3);

    // Test cycle detection
    const has_cycle = try flow_graph.hasCyclicDependencies();
    try testing.expect(has_cycle);
}

fn createFlowNode(allocator: std.mem.Allocator, name: []const u8, kind: parser.NodeKind) !*parser.FlowNode {
    const node = try allocator.create(parser.FlowNode);
    node.* = .{
        .name = try allocator.dupeZ(u8, name),
        .kind = kind,
        .source = null,
        .file_path = try allocator.dupeZ(u8, "test.ts"),
        .freed = false,
        .dependencies = std.ArrayList(*parser.FlowNode).init(allocator),
        .references = std.ArrayList(*parser.FlowNode).init(allocator),
        .location = .{
            .file = try allocator.dupeZ(u8, "test.ts"),
            .start = .{ .line = 0, .column = 0 },
            .end = .{ .line = 0, .column = 0 },
        },
    };
    return node;
}
