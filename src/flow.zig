const std = @import("std");
const ast = @import("ast_types.zig");

pub const Flow = struct {
    nodes: std.ArrayList(*ast.Node),
    written_nodes: std.AutoHashMap(*ast.Node, void),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*Flow {
        var flow = try allocator.create(Flow);
        flow.* = .{
            .nodes = std.ArrayList(*ast.Node).init(allocator),
            .written_nodes = std.AutoHashMap(*ast.Node, void).init(allocator),
            .allocator = allocator,
        };
        return flow;
    }

    pub fn deinit(self: *Flow) void {
        for (self.nodes.items) |node| {
            node.deinit();
            self.allocator.destroy(node);
        }
        self.nodes.deinit();
        self.written_nodes.deinit();
    }

    pub fn addNode(self: *Flow, node: *ast.Node) !void {
        // Validate node before cloning
        if (node.kind.kind == .unknown) {
            std.debug.print("Warning: Skipping node with unknown kind\n", .{});
            return;
        }

        // Clone the node to ensure we own it
        var cloned = try node.clone(self.allocator);
        errdefer cloned.deinit();

        // Track the node in our written nodes map
        try self.written_nodes.put(cloned, {});
        try self.nodes.append(cloned);
    }

    pub fn processNodes(self: *Flow, input_nodes: []const *ast.Node) !void {
        for (input_nodes) |node| {
            // Create a deep copy of the node to avoid memory issues
            const node_copy = try node.clone(self.allocator);
            errdefer {
                node_copy.deinit();
                self.allocator.destroy(node_copy);
            }
            try self.nodes.append(node_copy);
        }
    }

    pub fn writeToFile(self: *Flow, file_path: []const u8) !void {
        std.debug.print("Starting writeToFile\n", .{});
        
        // Create or truncate the file
        const file = try std.fs.cwd().createFile(file_path, .{
            .truncate = true,
            .read = true,
        });
        defer file.close();

        // Set up buffered writer for better performance
        var buffered_writer = std.io.bufferedWriter(file.writer());
        var writer = buffered_writer.writer();

        // Clear written nodes tracking
        self.written_nodes.clearRetainingCapacity();

        // Process nodes for output
        var processed = std.ArrayList(*ast.Node).init(self.allocator);
        defer processed.deinit();

        // First pass: Process export statements
        for (self.nodes.items) |node| {
            if (node.kind.kind == .ExportDecl) {
                try processed.append(node);
            }
        }

        // Second pass: Process non-export statements
        for (self.nodes.items) |node| {
            if (node.kind.kind != .ExportDecl) {
                try processed.append(node);
            }
        }

        // Write nodes
        for (processed.items) |node| {
            std.debug.print("Writing node: {s}\n", .{@tagName(node.kind.kind)});
            try self.writeNode(writer, node);
            try writer.writeAll("\n");  // Add newline after each top-level node
        }

        // Ensure all content is written
        try buffered_writer.flush();

        // Verify file was written correctly
        try file.seekTo(0);
        const file_size = try file.getEndPos();
        if (file_size == 0) {
            std.debug.print("Warning: Output file is empty\n", .{});
        } else {
            std.debug.print("Successfully wrote {d} bytes to file\n", .{file_size});
        }
    }

    fn writeNode(self: *Flow, writer: anytype, node: *ast.Node) !void {
        // Check if we've already written this node
        if (self.written_nodes.contains(node)) {
            return;
        }

        // Add spacing based on node type
        switch (node.kind.kind) {
            .program,
            .export_statement,
            .interface_declaration,
            .class_declaration,
            .method_definition => try writer.writeAll("\n"),
            else => {},
        }

        // Write node value if it exists
        if (node.value) |value| {
            try writer.writeAll(value);
        }

        // Process children
        for (node.children.items) |child| {
            if (child.kind.kind != .unknown) {
                try self.writeNode(writer, child);
            }
        }

        // Add trailing newline for certain node types
        switch (node.kind.kind) {
            .program,
            .export_statement,
            .interface_declaration,
            .class_declaration => try writer.writeAll("\n"),
            else => {},
        }

        // Mark node as written
        try self.written_nodes.put(node, {});
    }
};
