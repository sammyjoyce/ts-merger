/// Provides AST types and structures for representing code elements.
const std = @import("std");
const tree_sitter = @import("tree_sitter");

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
};

// Add test cases
test "node initialization" {
    const allocator = std.testing.allocator;
    var node = try Node.init(allocator, "TestNode", .{ .kind = .class_declaration });
    defer node.deinit();
    defer allocator.destroy(node);

    try std.testing.expect(node.children.items.len == 0);
    try std.testing.expect(node.dependencies.items.len == 0);
    try std.testing.expectEqualStrings("TestNode", node.name);
}

test "node dependencies" {
    const allocator = std.testing.allocator;
    var node1 = try Node.init(allocator, "Node1", .{ .kind = .class_declaration });
    defer node1.deinit();
    defer allocator.destroy(node1);

    var node2 = try Node.init(allocator, "Node2", .{ .kind = .class_declaration });
    defer node2.deinit();
    defer allocator.destroy(node2);

    try node1.dependencies.append(node2);
    try node2.dependents.append(node1);

    try std.testing.expect(node1.dependencies.items.len == 1);
    try std.testing.expect(node2.dependents.items.len == 1);
}

test "node children" {
    const allocator = std.testing.allocator;
    var node1 = try Node.init(allocator, "Node1", .{ .kind = .class_declaration });
    defer node1.deinit();
    defer allocator.destroy(node1);

    const child = try Node.init(allocator, "Child", .{ .kind = .method_definition });
    try node1.children.append(child);

    try std.testing.expect(node1.children.items.len == 1);
    try std.testing.expectEqualStrings("Child", node1.children.items[0].name);
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

    var node = try CodeFlowNode.init(allocator, "TestNode", .{ .kind = .class });
    defer node.deinit(allocator);

    try testing.expectEqualStrings("TestNode", node.name);
    try testing.expectEqual(NodeKind.Kind.class, node.kind.kind);
    try testing.expectEqual(@as(usize, 0), node.dependencies.items.len);
    try testing.expectEqual(@as(usize, 0), node.references.items.len);
}

test "add dependencies to CodeFlowNode" {
    const allocator = testing.allocator;

    var node1 = try CodeFlowNode.init(allocator, "Node1", .{ .kind = .class });
    defer node1.deinit(allocator);

    var node2 = try CodeFlowNode.init(allocator, "Node2", .{ .kind = .interface });
    defer node2.deinit(allocator);

    try node1.dependencies.append(node2);
    try testing.expectEqual(@as(usize, 1), node1.dependencies.items.len);
    try testing.expectEqual(node2, node1.dependencies.items[0]);
}

test "add references to CodeFlowNode" {
    const allocator = testing.allocator;

    var node1 = try CodeFlowNode.init(allocator, "Node1", .{ .kind = .class });
    defer node1.deinit(allocator);

    var node2 = try CodeFlowNode.init(allocator, "Node2", .{ .kind = .interface });
    defer node2.deinit(allocator);

    try node1.references.append(node2);
    try testing.expectEqual(@as(usize, 1), node1.references.items.len);
    try testing.expectEqual(node2, node1.references.items[0]);
}
