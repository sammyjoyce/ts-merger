/// Provides AST types and structures for representing code elements.
const std = @import("std");

/// Represents a position in a source file with line and character information.
pub const Position = struct {
    row: u32,
    column: u32,
};

/// Represents a range in a source file defined by a start and end position.
pub const Range = struct {
    start: Position,
    end: Position,
};

/// Contains the file path and range information of a node in the source code.
pub const Location = struct {
    file_path: []const u8,
    range: Range,

    /// Initializes a new `Location` with the given file and range.
    pub fn init(allocator: std.mem.Allocator, file_path: []const u8, start: Position, end: Position) !Location {
        return Location{
            .file_path = try allocator.dupeZ(u8, file_path),
            .range = Range{
                .start = start,
                .end = end,
            },
        };
    }

    pub fn deinit(self: Location, allocator: std.mem.Allocator) void {
        allocator.free(self.file_path);
    }
};

pub const NodeKind = struct {
    base: BaseKind,
    custom_kind: ?[]const u8,
    source: ?[]const u8,

    pub const BaseKind = enum {
        unknown,
        program,
        export_statement,
        interface_declaration,
        class_declaration,
        method_definition,
        Program,
        ExportDecl,
        ImportDecl,
        Interface,
        Class,
        Function,
        Variable,
        Property,
        Method,
        Parameter,
        Type,
        Comment,
        Block,
        BlockEnd,
        Identifier,
        TypeIdentifier,
        TypeAnnotation,
        jsx_element,
        jsx_opening_element,
        jsx_closing_element,
        jsx_self_closing_element,
        jsx_attribute,
        ObjectType,
        ArrayType,
        UnionType,
        Constructor,
        Statement,
        Expression,
        Call,
        Member,
        String,
        Number,
        Operator,
        Semicolon,
        Comma,
        Public,
        Private,
        Protected,
        Return,
        This,
        Arrow,
        Equals,
        LeftBracket,
        RightBracket,
        LeftParen,
        RightParen,
        LeftBrace,
        RightBrace,
        Pipe,
        TripleEquals,
        class,
    };
};

pub const Node = struct {
    kind: NodeKind,
    value: ?[]const u8,
    children: std.ArrayList(*Node),
    dependencies: std.ArrayList(*Node),
    dependents: std.ArrayList(*Node),
    name: []const u8,
    allocator: std.mem.Allocator,
    // Code style information
    style: ?CodeStyle = null,

    pub fn init(allocator: std.mem.Allocator, name: []const u8, kind: NodeKind) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .kind = kind,
            .value = null,
            .children = std.ArrayList(*Node).init(allocator),
            .dependencies = std.ArrayList(*Node).init(allocator),
            .dependents = std.ArrayList(*Node).init(allocator),
            .name = name,
            .allocator = allocator,
        };
        return node;
    }

    /// Merges another node into this node, combining their children and updating dependencies.
    /// The other node is not modified or destroyed by this operation.
    pub fn merge(self: *Node, other: *Node) !void {
        // For program nodes, merge all children
        if (self.kind.base == .program or self.kind.base == .Program) {
            // Add all children from the other node
            for (other.children.items) |child| {
                // Check if we already have this child (by name)
                var found = false;
                for (self.children.items) |existing| {
                    if (std.mem.eql(u8, existing.name, child.name)) {
                        // If found, recursively merge the child nodes
                        try existing.merge(child);
                        found = true;
                        break;
                    }
                }

                // If not found, add as a new child
                if (!found) {
                    try self.children.append(child);
                }
            }

            // Merge dependencies
            for (other.dependencies.items) |dep| {
                var dep_found = false;
                for (self.dependencies.items) |existing_dep| {
                    if (std.mem.eql(u8, existing_dep.name, dep.name)) {
                        dep_found = true;
                        break;
                    }
                }

                if (!dep_found) {
                    try self.dependencies.append(dep);
                }
            }

            // Update dependents
            for (other.dependents.items) |dependent| {
                var dependent_found = false;
                for (self.dependents.items) |existing_dependent| {
                    if (std.mem.eql(u8, existing_dependent.name, dependent.name)) {
                        dependent_found = true;
                        break;
                    }
                }

                if (!dependent_found) {
                    try self.dependents.append(dependent);
                }
            }
        } else {
            // For non-program nodes, just append children if they don't exist
            for (other.children.items) |child| {
                var found = false;
                for (self.children.items) |existing| {
                    if (std.mem.eql(u8, existing.name, child.name)) {
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    try self.children.append(child);
                }
            }
        }
    }

    pub fn deinit(self: *Node) void {
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit();

        for (self.dependencies.items) |dep| {
            dep.deinit();
            self.allocator.destroy(dep);
        }
        self.dependencies.deinit();

        for (self.dependents.items) |dependent| {
            dependent.deinit();
            self.allocator.destroy(dependent);
        }
        self.dependents.deinit();
    }

    /// Serializes the node and its children into a string representation.
    /// The caller is responsible for freeing the returned memory.
    pub fn serialize(self: *Node, allocator: std.mem.Allocator) ![]const u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();

        try self.serializeToBuffer(&buffer);

        return buffer.toOwnedSlice();
    }

    /// Returns the source path of an import declaration (e.g., "react" in `import React from "react"`).
    /// Returns null if the node is not an import declaration or if the source path cannot be determined.
    pub fn getSourcePath(self: *Node) ?[]const u8 {
        if (self.kind.base != .ImportDecl) return null;

        // For simplicity, we'll assume the source path is stored in the node's value
        // In a real implementation, this would parse the import statement to extract the source path
        return self.value;
    }

    /// Returns the identifier of an export or import declaration (e.g., "React" in `import React from "react"`).
    /// Returns null if the node is not an export or import declaration or if the identifier cannot be determined.
    pub fn getIdentifier(self: *Node) ?[]const u8 {
        if (self.kind.base != .ExportDecl and self.kind.base != .ImportDecl) return null;

        // For simplicity, we'll use the node's name as the identifier
        // In a real implementation, this would parse the declaration to extract the identifier
        return self.name;
    }

    /// Returns a list of imported symbols from an import declaration.
    /// For example, from `import { useState, useEffect } from "react"`, it would return ["useState", "useEffect"].
    /// Returns null if the node is not an import declaration or if no symbols can be determined.
    pub fn getImportedSymbols(self: *Node) ?std.ArrayList([]const u8) {
        if (self.kind.base != .ImportDecl) return null;

        var symbols = std.ArrayList([]const u8).init(self.allocator);

        // For now, we'll just add the main identifier as a symbol if it exists
        if (self.getIdentifier()) |identifier| {
            symbols.append(identifier) catch return null;
        }

        // In a real implementation, we would parse the import statement to extract all imported symbols
        // For example, from `import { useState, useEffect } from "react"`, we would extract ["useState", "useEffect"]
        // For now, we'll assume that each child node with kind.base == .Identifier is an imported symbol
        for (self.children.items) |child| {
            if (child.kind.base == .Identifier) {
                if (child.name.len > 0) {
                    symbols.append(child.name) catch continue;
                }
            }
        }

        return symbols;
    }

    /// Merges imported symbols from another import node with the same source path.
    /// Returns true if the merge was successful, false otherwise.
    pub fn mergeImportedSymbols(self: *Node, other: *Node) !bool {
        if (self.kind.base != .ImportDecl or other.kind.base != .ImportDecl) return false;

        const self_path = self.getSourcePath() orelse return false;
        const other_path = other.getSourcePath() orelse return false;

        // Only merge imports from the same source
        if (!std.mem.eql(u8, self_path, other_path)) return false;

        // Get symbols from the other import
        var other_symbols = other.getImportedSymbols() orelse return false;
        defer other_symbols.deinit();

        // Add each symbol from the other import to this import if it doesn't already exist
        for (other_symbols.items) |symbol| {
            var found = false;

            // Check if this symbol already exists in this import
            if (self.getImportedSymbols()) |self_symbols| {
                defer self_symbols.deinit();

                for (self_symbols.items) |self_symbol| {
                    if (std.mem.eql(u8, self_symbol, symbol)) {
                        found = true;
                        break;
                    }
                }
            }

            // If the symbol doesn't exist, add it as a child node
            if (!found) {
                var symbol_node = try Node.init(self.allocator, symbol, .{ .base = .Identifier, .custom_kind = null, .source = null });
                try self.children.append(symbol_node);
            }
        }

        return true;
    }

    /// Helper function to serialize the node to a buffer.
    fn serializeToBuffer(self: *Node, buffer: *std.ArrayList(u8)) !void {
        // Add node value if it exists
        if (self.value) |value| {
            try buffer.appendSlice(value);
        }

        // For program nodes, add newlines between children
        if (self.kind.base == .program or self.kind.base == .Program) {
            for (self.children.items) |child| {
                try buffer.appendSlice("\n");
                try child.serializeToBuffer(buffer);
                try buffer.appendSlice("\n");
            }
        } else {
            // For other nodes, just serialize children
            for (self.children.items) |child| {
                try child.serializeToBuffer(buffer);
            }

            // Add appropriate closing syntax based on node type
            switch (self.kind.base) {
                .class_declaration, .interface_declaration, .method_definition => {
                    try buffer.appendSlice("\n}");
                },
                else => {},
            }
        }
    }
};

// Add test cases
test "node initialization" {
    const allocator = std.testing.allocator;
    var node = try Node.init(allocator, "TestNode", .{ .base = .class_declaration, .custom_kind = null, .source = null });
    defer node.deinit();
    defer allocator.destroy(node);

    try std.testing.expect(node.children.items.len == 0);
    try std.testing.expect(node.dependencies.items.len == 0);
    try std.testing.expectEqualStrings("TestNode", node.name);
}

test "node dependencies" {
    const allocator = std.testing.allocator;
    var node1 = try Node.init(allocator, "Node1", .{ .base = .class_declaration, .custom_kind = null, .source = null });
    defer node1.deinit();
    defer allocator.destroy(node1);

    var node2 = try Node.init(allocator, "Node2", .{ .base = .class_declaration, .custom_kind = null, .source = null });
    defer node2.deinit();
    defer allocator.destroy(node2);

    try node1.dependencies.append(node2);
    try node2.dependents.append(node1);

    try std.testing.expect(node1.dependencies.items.len == 1);
    try std.testing.expect(node2.dependents.items.len == 1);
}

test "node children" {
    const allocator = std.testing.allocator;
    var node1 = try Node.init(allocator, "Node1", .{ .base = .class_declaration, .custom_kind = null, .source = null });
    defer node1.deinit();
    defer allocator.destroy(node1);

    const child = try Node.init(allocator, "Child", .{ .base = .method_definition, .custom_kind = null, .source = null });
    try node1.children.append(child);

    try std.testing.expect(node1.children.items.len == 1);
    try std.testing.expectEqualStrings("Child", node1.children.items[0].name);
}

test "node merge - program nodes" {
    const allocator = std.testing.allocator;

    // Create two program nodes
    var program1 = try Node.init(allocator, "Program1", .{ .base = .program, .custom_kind = null, .source = null });
    defer program1.deinit();
    defer allocator.destroy(program1);

    var program2 = try Node.init(allocator, "Program2", .{ .base = .program, .custom_kind = null, .source = null });
    defer program2.deinit();
    defer allocator.destroy(program2);

    // Add children to both programs
    var class1 = try Node.init(allocator, "Class1", .{ .base = .class_declaration, .custom_kind = null, .source = null });
    try program1.children.append(class1);

    var class2 = try Node.init(allocator, "Class2", .{ .base = .class_declaration, .custom_kind = null, .source = null });
    try program2.children.append(class2);

    // Merge program2 into program1
    try program1.merge(program2);

    // Verify the merge
    try std.testing.expect(program1.children.items.len == 2);
    try std.testing.expectEqualStrings("Class1", program1.children.items[0].name);
    try std.testing.expectEqualStrings("Class2", program1.children.items[1].name);
}

test "node merge - duplicate children" {
    const allocator = std.testing.allocator;

    // Create two program nodes
    var program1 = try Node.init(allocator, "Program1", .{ .base = .program, .custom_kind = null, .source = null });
    defer program1.deinit();
    defer allocator.destroy(program1);

    var program2 = try Node.init(allocator, "Program2", .{ .base = .program, .custom_kind = null, .source = null });
    defer program2.deinit();
    defer allocator.destroy(program2);

    // Add the same named class to both programs
    var class1 = try Node.init(allocator, "SameClass", .{ .base = .class_declaration, .custom_kind = null, .source = null });
    try program1.children.append(class1);

    var class2 = try Node.init(allocator, "SameClass", .{ .base = .class_declaration, .custom_kind = null, .source = null });
    var method1 = try Node.init(allocator, "Method1", .{ .base = .method_definition, .custom_kind = null, .source = null });
    try class2.children.append(method1);
    try program2.children.append(class2);

    // Merge program2 into program1
    try program1.merge(program2);

    // Verify the merge - should have one class with the method merged in
    try std.testing.expect(program1.children.items.len == 1);
    try std.testing.expectEqualStrings("SameClass", program1.children.items[0].name);
    try std.testing.expect(program1.children.items[0].children.items.len == 1);
    try std.testing.expectEqualStrings("Method1", program1.children.items[0].children.items[0].name);
}

test "node serialize" {
    const allocator = std.testing.allocator;

    // Create a program node with a class and method
    var program = try Node.init(allocator, "Program", .{ .base = .program, .custom_kind = null, .source = null });
    defer program.deinit();
    defer allocator.destroy(program);

    var class_node = try Node.init(allocator, "TestClass", .{ .base = .class_declaration, .custom_kind = null, .source = null });
    class_node.value = "class TestClass {";
    try program.children.append(class_node);

    var method_node = try Node.init(allocator, "testMethod", .{ .base = .method_definition, .custom_kind = null, .source = null });
    method_node.value = "  testMethod() {";
    try class_node.children.append(method_node);

    var method_body = try Node.init(allocator, "methodBody", .{ .base = .Block, .custom_kind = null, .source = null });
    method_body.value = "    return 'test';";
    try method_node.children.append(method_body);

    // Serialize the program
    const serialized = try program.serialize(allocator);
    defer allocator.free(serialized);

    // Verify the serialized output
    try std.testing.expect(std.mem.indexOf(u8, serialized, "class TestClass {") != null);
    try std.testing.expect(std.mem.indexOf(u8, serialized, "  testMethod() {") != null);
    try std.testing.expect(std.mem.indexOf(u8, serialized, "    return 'test';") != null);
    try std.testing.expect(std.mem.indexOf(u8, serialized, "}") != null);
}

test "get imported symbols" {
    const allocator = std.testing.allocator;

    // Create an import node
    var import_node = try Node.init(allocator, "React", .{ .base = .ImportDecl, .custom_kind = null, .source = null });
    defer import_node.deinit();
    defer allocator.destroy(import_node);
    import_node.value = "react";

    // Add some imported symbols as child nodes
    var symbol1 = try Node.init(allocator, "useState", .{ .base = .Identifier, .custom_kind = null, .source = null });
    try import_node.children.append(symbol1);

    var symbol2 = try Node.init(allocator, "useEffect", .{ .base = .Identifier, .custom_kind = null, .source = null });
    try import_node.children.append(symbol2);

    // Get the imported symbols
    var symbols = import_node.getImportedSymbols() orelse {
        try std.testing.expect(false); // Should not fail
        return;
    };
    defer symbols.deinit();

    // Verify the symbols
    try std.testing.expectEqual(@as(usize, 3), symbols.items.len);
    try std.testing.expectEqualStrings("React", symbols.items[0]);
    try std.testing.expectEqualStrings("useState", symbols.items[1]);
    try std.testing.expectEqualStrings("useEffect", symbols.items[2]);
}

test "merge imported symbols" {
    const allocator = std.testing.allocator;

    // Create two import nodes with the same source path
    var import1 = try Node.init(allocator, "React", .{ .base = .ImportDecl, .custom_kind = null, .source = null });
    defer import1.deinit();
    defer allocator.destroy(import1);
    import1.value = "react";

    var import2 = try Node.init(allocator, "ReactDOM", .{ .base = .ImportDecl, .custom_kind = null, .source = null });
    defer import2.deinit();
    defer allocator.destroy(import2);
    import2.value = "react";

    // Add some imported symbols to each import
    var symbol1 = try Node.init(allocator, "useState", .{ .base = .Identifier, .custom_kind = null, .source = null });
    try import1.children.append(symbol1);

    var symbol2 = try Node.init(allocator, "useEffect", .{ .base = .Identifier, .custom_kind = null, .source = null });
    try import2.children.append(symbol2);

    // Merge the imports
    const result = try import1.mergeImportedSymbols(import2);
    try std.testing.expect(result);

    // Verify the merged symbols
    var symbols = import1.getImportedSymbols() orelse {
        try std.testing.expect(false); // Should not fail
        return;
    };
    defer symbols.deinit();

    // Verify the symbols
    try std.testing.expectEqual(@as(usize, 3), symbols.items.len);
    try std.testing.expectEqualStrings("React", symbols.items[0]);
    try std.testing.expectEqualStrings("useState", symbols.items[1]);
    try std.testing.expectEqualStrings("useEffect", symbols.items[2]);
}

/// Represents a code flow node with dependencies and references
pub const CodeFlowNode = struct {
    name: []const u8,
    kind: NodeKind,
    source: ?[]const u8,
    location: Location,
    freed: bool,
    dependencies: std.ArrayList(*CodeFlowNode),
    references: std.ArrayList(*CodeFlowNode),

    pub fn init(allocator: std.mem.Allocator, name: []const u8, kind: NodeKind) !*CodeFlowNode {
        const node = try allocator.create(CodeFlowNode);
        const owned_name = try allocator.dupeZ(u8, name);

        node.* = .{
            .name = owned_name,
            .kind = kind,
            .source = null,
            .freed = false,
            .dependencies = std.ArrayList(*CodeFlowNode).init(allocator),
            .references = std.ArrayList(*CodeFlowNode).init(allocator),
            // Initialize valid temporary location
            .location = Location{
                .file_path = try allocator.dupeZ(u8, "uninitialized"), // Will be set later
                .range = Range{
                    .start = Position{ .row = 0, .column = 0 },
                    .end = Position{ .row = 0, .column = 0 },
                },
            },
        };
        return node;
    }

    pub fn deinit(self: *CodeFlowNode, allocator: std.mem.Allocator) void {
        if (self.freed) return;
        allocator.free(self.name);
        if (self.source) |source| {
            allocator.free(source);
        }
        self.dependencies.deinit();
        self.references.deinit();

        // Properly deinitialize location
        self.location.deinit(allocator);

        self.freed = true;
        allocator.destroy(self);
    }

    pub fn addMethod(self: *CodeFlowNode, method_name: []const u8) !void {
        const method_node = try self.dependencies.allocator.create(CodeFlowNode);
        const owned_name = try self.dependencies.allocator.dupeZ(u8, method_name);

        method_node.* = .{
            .name = owned_name,
            .kind = .{ .kind = .Function },
            .source = null,
            .freed = false,
            .dependencies = std.ArrayList(*CodeFlowNode).init(self.dependencies.allocator),
            .references = std.ArrayList(*CodeFlowNode).init(self.dependencies.allocator),
            .location = Location{
                .file_path = try self.dependencies.allocator.dupeZ(u8, "uninitialized"),
                .range = Range{
                    .start = Position{ .row = 0, .column = 0 },
                    .end = Position{ .row = 0, .column = 0 },
                },
            },
        };

        try self.dependencies.append(method_node);
    }

    pub fn addDependency(self: *CodeFlowNode, dependency: *CodeFlowNode) !void {
        try self.dependencies.append(dependency);
        try dependency.references.append(self);
    }
};

const testing = std.testing;

test "create and manipulate CodeFlowNode" {
    const allocator = testing.allocator;

    var node = try CodeFlowNode.init(allocator, "TestNode", .{ .base = .class, .custom_kind = null, .source = null });
    defer node.deinit(allocator);

    try testing.expectEqualStrings("TestNode", node.name);
    try testing.expectEqual(NodeKind.BaseKind.class, node.kind.base);
    try testing.expectEqual(@as(usize, 0), node.dependencies.items.len);
    try testing.expectEqual(@as(usize, 0), node.references.items.len);
}

test "add dependencies to CodeFlowNode" {
    const allocator = testing.allocator;

    var node1 = try CodeFlowNode.init(allocator, "Node1", .{ .base = .class, .custom_kind = null, .source = null });
    defer node1.deinit(allocator);

    var node2 = try CodeFlowNode.init(allocator, "Node2", .{ .base = .Interface, .custom_kind = null, .source = null });
    defer node2.deinit(allocator);

    try node1.dependencies.append(node2);
    try testing.expectEqual(@as(usize, 1), node1.dependencies.items.len);
    try testing.expectEqual(node2, node1.dependencies.items[0]);
}

test "add references to CodeFlowNode" {
    const allocator = testing.allocator;

    var node1 = try CodeFlowNode.init(allocator, "Node1", .{ .base = .class, .custom_kind = null, .source = null });
    defer node1.deinit(allocator);

    var node2 = try CodeFlowNode.init(allocator, "Node2", .{ .base = .Interface, .custom_kind = null, .source = null });
    defer node2.deinit(allocator);

    try node1.references.append(node2);
    try testing.expectEqual(@as(usize, 1), node1.references.items.len);
    try testing.expectEqual(node2, node1.references.items[0]);
}
