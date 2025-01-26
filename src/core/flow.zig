const std = @import("std");
const Parser = @import("../parser/mod.zig").Parser;
const ast_types = @import("ast_types");
const typescript = @import("../bindings/tree_sitter_typescript.zig");

pub fn analyze(allocator: std.mem.Allocator, input: []const u8) !void {
    var ts_parser_impl = try typescript.TypeScriptParser.init(allocator);
    defer ts_parser_impl.deinit();
    
    var parser = Parser.init(allocator, ts_parser_impl, &typescript.interface);
    defer parser.deinit();
    
    const node = try parser.parse(input);
    defer node.deinit();
    
    if (node.kind.kind == .unknown) {
        Logger.scoped(.Warning, "flow").warn("Skipping unknown node type", .{});
        return;
    }

    // Check for cyclic dependencies before adding the node
    for (node.dependencies.items) |dep| {
        if (dep == node) {
            return error.CyclicDependency;
        }

        // Check if this dependency creates a cycle
        var visited = std.AutoHashMap(*ast_types.Node, void).init(self.allocator);
        defer visited.deinit();

        if (try self.hasCycle(dep, node, &visited)) {
            return error.CyclicDependency;
        }
    }

    try self.nodes.append(node);
}

fn hasCycle(self: *Flow, current: *ast_types.Node, target: *ast_types.Node, visited: *std.AutoHashMap(*ast_types.Node, void)) !bool {
    if (current == target) return true;
    if (visited.contains(current)) return false;

    try visited.put(current, {});

    for (current.dependencies.items) |dep| {
        if (try self.hasCycle(dep, target, visited)) {
            return true;
        }
    }

    return false;
}

pub fn getNodes(self: *Flow) []const *ast_types.Node {
    return self.nodes.items;
}

pub fn getTopologicalOrder(self: *Flow) !std.ArrayList(*ast_types.Node) {
    var in_degree = std.AutoHashMap(*ast_types.Node, u32).init(self.allocator);
    defer in_degree.deinit();

    // Initialize in-degrees based on dependencies
    for (self.nodes.items) |node| {
        try in_degree.put(node, 0);
    }
    for (self.nodes.items) |node| {
        for (node.dependencies.items) |dep| {
            const count = in_degree.get(dep) orelse 0;
            try in_degree.put(dep, count + 1);
        }
    }

    // Kahn's algorithm implementation
    var queue = std.ArrayList(*ast_types.Node).init(self.allocator);
    defer queue.deinit();

    for (self.nodes.items) |node| {
        if (in_degree.get(node).? == 0) {
            try queue.append(node);
        }
    }

    var sorted = std.ArrayList(*ast_types.Node).init(self.allocator);
    while (queue.popOrNull()) |node| {
        try sorted.append(node);
        for (node.dependents.items) |dependent| {
            const current = in_degree.get(dependent).?;
            if (current == 0) continue;
            try in_degree.put(dependent, current - 1);
            if (current - 1 == 0) {
                try queue.append(dependent);
            }
        }
    }

    if (sorted.items.len != self.nodes.items.len) {
        var cycle_node: ?*ast_types.Node = null;
        var it = in_degree.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.* > 0) {
                cycle_node = entry.key_ptr.*;
                break;
            }
        }

        if (cycle_node) |node| {
            const cycle_path = try detectCycleDfs(self.allocator, node);
            defer self.allocator.free(cycle_path);

            Logger.scoped(.Error, "flow").err("Circular dependency detected: {s}", .{cycle_path});
        }
        return error.CircularDependency;
    }

    return sorted;
}

pub fn writeToFile(self: *Flow, file_path: []const u8) !void {
    const ordered = try self.getTopologicalOrder();
    std.debug.print("Starting writeToFile\n", .{});

    const file = try std.fs.cwd().createFile(file_path, .{
        .truncate = true,
        .read = true,
    });
    defer file.close();

    var buffered_writer = std.io.bufferedWriter(file.writer());
    var writer = buffered_writer.writer();

    // Single pass through topological order
    for (ordered.items) |node| {
        std.debug.print("Writing node: {s}\n", .{@tagName(node.kind.kind)});
        try self.writeNode(writer, node);
        try writer.writeAll("\n");
    }

    try buffered_writer.flush();

    // Verification remains the same
    try file.seekTo(0);
    const file_size = try file.getEndPos();
    if (file_size == 0) {
        std.debug.print("Warning: Output file is empty\n", .{});
    }
}

fn writeNode(self: *Flow, writer: anytype, node: *ast_types.Node) !void {
    switch (node.kind.kind) {
        .program, .export_statement, .interface_declaration, .class_declaration, .method_definition => try writer.writeAll("\n"),
        else => {},
    }

    if (node.value) |value| {
        try writer.writeAll(value);
    }

    for (node.children.items) |child| {
        if (child.kind.kind != .unknown) {
            try self.writeNode(writer, child);
        }
    }

    switch (node.kind.kind) {
        .program, .export_statement, .interface_declaration, .class_declaration => try writer.writeAll("\n"),
        else => {
            std.debug.print("Unhandled node kind: {s}\n", .{@tagName(node.kind.kind)});
        },
    }
};

fn detectCycleDfs(allocator: std.mem.Allocator, start: *ast_types.Node) ![]const u8 {
    var visited = std.AutoHashMap(*ast_types.Node, void).init(allocator);
    var stack = std.ArrayList(*ast_types.Node).init(allocator);
    var path = std.ArrayList(u8).init(allocator);

    try stack.append(start);
    while (stack.popOrNull()) |current| {
        if (visited.contains(current)) {
            if (current == start) {
                // Build cycle path string
                for (stack.items) |node| {
                    try path.writer().print("{s}->", .{node.name});
                }
                try path.writer().print("{s}", .{start.name});
                return path.toOwnedSlice();
            }
            continue;
        }
        try visited.put(current, {});
        for (current.dependencies.items) |dep| {
            try stack.append(dep);
        }
    }
    return error.NoCycleFound;
}

const testing = std.testing;
const parser_mod = @import("../parser/mod.zig");

test "cyclic dependency detection" {
    const allocator = testing.allocator;
    var ts_parser_impl = try ts.TypeScriptParser.init(allocator);
    defer ts_parser_impl.deinit();

    var parser = parser_mod.Parser.init(allocator, ts_parser_impl, &typescript.interface);
    defer parser.deinit();

    var flow_graph = try Flow.init(allocator);
    defer flow_graph.deinit();

    // Create a source with cyclic dependencies
    const cyclic_source =
        \\ class A extends B {}
        \\ class B extends C {}
        \\ class C extends A {}
    ;

    const root = try parser.parse(cyclic_source);
    try testing.expectError(error.CyclicDependency, flow_graph.addNode(root));
}
