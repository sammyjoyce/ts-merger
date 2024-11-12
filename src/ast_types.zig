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
    file_path: [:0]const u8,
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

/// Base AST node structure that represents any node in the syntax tree
pub const Node = struct {
    kind: NodeKind,
    value: ?[]const u8,
    children: std.ArrayList(*Node),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*Node {
        const node = try allocator.create(Node);
        errdefer allocator.destroy(node);
        
        node.* = .{
            .kind = .{ .kind = .Unknown, .source = null },
            .value = null,
            .children = std.ArrayList(*Node).init(allocator),
            .allocator = allocator,
        };
        return node;
    }

    pub fn deinit(self: *Node) void {
        // Clean up kind source if present
        if (self.kind.source) |source| {
            self.allocator.free(source);
        }
        
        // Clean up value if present
        if (self.value) |value| {
            self.allocator.free(value);
        }
        
        // Clean up children recursively
        for (self.children.items) |child| {
            child.deinit();
            self.allocator.destroy(child);
        }
        self.children.deinit();
    }

    pub fn clone(self: *const Node, allocator: std.mem.Allocator) !*Node {
        var new_node = try Node.init(allocator);
        errdefer new_node.deinit();

        // Clone kind
        new_node.kind.kind = self.kind.kind;
        if (self.kind.source) |source| {
            new_node.kind.source = try allocator.dupe(u8, source);
        }

        // Clone value if present
        if (self.value) |value| {
            new_node.value = try allocator.dupe(u8, value);
        }

        // Clone children recursively
        try new_node.children.ensureTotalCapacity(self.children.items.len);
        for (self.children.items) |child| {
            const cloned_child = try child.clone(allocator);
            errdefer cloned_child.deinit();
            try new_node.children.append(cloned_child);
        }

        return new_node;
    }

    pub fn setValue(self: *Node, value: []const u8) !void {
        if (self.value) |old_value| {
            self.allocator.free(old_value);
        }
        self.value = try self.allocator.dupe(u8, value);
    }

    pub fn addChild(self: *Node, child: *Node) !void {
        try self.children.append(child);
    }

    pub fn isLeafNode(self: *const Node) bool {
        return self.children.items.len == 0;
    }
};

pub const NodeKind = struct {
    kind: Kind,
    source: ?[]const u8,

    pub const Kind = enum {
        Unknown,
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
    };
};

pub fn nodeKindFromString(kind_str: [*:0]const u8) !NodeKind.Kind {
    const str = std.mem.span(kind_str);
    return if (std.mem.eql(u8, str, "program"))
        .Program
    else if (std.mem.eql(u8, str, "export_statement"))
        .ExportDecl
    else if (std.mem.eql(u8, str, "import_statement"))
        .ImportDecl
    else if (std.mem.eql(u8, str, "interface_declaration"))
        .Interface
    else if (std.mem.eql(u8, str, "class_declaration"))
        .Class
    else if (std.mem.eql(u8, str, "function_declaration"))
        .Function
    else if (std.mem.eql(u8, str, "variable_declaration"))
        .Variable
    else if (std.mem.eql(u8, str, "property_signature"))
        .Property
    else if (std.mem.eql(u8, str, "method_definition"))
        .Method
    else if (std.mem.eql(u8, str, "formal_parameters"))
        .Parameter
    else if (std.mem.eql(u8, str, "type_annotation"))
        .TypeAnnotation
    else if (std.mem.eql(u8, str, "comment"))
        .Comment
    else if (std.mem.eql(u8, str, "statement_block"))
        .Block
    else if (std.mem.eql(u8, str, "}"))
        .BlockEnd
    else if (std.mem.eql(u8, str, "identifier") or std.mem.eql(u8, str, "property_identifier"))
        .Identifier
    else if (std.mem.eql(u8, str, "type_identifier"))
        .TypeIdentifier
    else if (std.mem.eql(u8, str, "object_type"))
        .ObjectType
    else if (std.mem.eql(u8, str, "array_type"))
        .ArrayType
    else if (std.mem.eql(u8, str, "union_type"))
        .UnionType
    else if (std.mem.eql(u8, str, "constructor"))
        .Constructor
    else if (std.mem.eql(u8, str, "statement"))
        .Statement
    else if (std.mem.eql(u8, str, "expression"))
        .Expression
    else if (std.mem.eql(u8, str, "call_expression"))
        .Call
    else if (std.mem.eql(u8, str, "member_expression"))
        .Member
    else if (std.mem.eql(u8, str, "string") or std.mem.eql(u8, str, "string_literal"))
        .String
    else if (std.mem.eql(u8, str, "number") or std.mem.eql(u8, str, "number_literal"))
        .Number
    else if (std.mem.eql(u8, str, ";"))
        .Semicolon
    else if (std.mem.eql(u8, str, ","))
        .Comma
    else if (std.mem.eql(u8, str, "public"))
        .Public
    else if (std.mem.eql(u8, str, "private"))
        .Private
    else if (std.mem.eql(u8, str, "protected"))
        .Protected
    else if (std.mem.eql(u8, str, "return"))
        .Return
    else if (std.mem.eql(u8, str, "this"))
        .This
    else if (std.mem.eql(u8, str, "=>"))
        .Arrow
    else if (std.mem.eql(u8, str, "="))
        .Equals
    else if (std.mem.eql(u8, str, "["))
        .LeftBracket
    else if (std.mem.eql(u8, str, "]"))
        .RightBracket
    else if (std.mem.eql(u8, str, "("))
        .LeftParen
    else if (std.mem.eql(u8, str, ")"))
        .RightParen
    else if (std.mem.eql(u8, str, "{"))
        .LeftBrace
    else if (std.mem.eql(u8, str, "}"))
        .RightBrace
    else if (std.mem.eql(u8, str, "|"))
        .Pipe
    else if (std.mem.eql(u8, str, "==="))
        .TripleEquals
    else
        .Unknown;
}

/// Represents a code flow node with dependencies and references
pub const CodeFlowNode = struct {
    name: [:0]const u8,
    kind: NodeKind,
    source: ?[:0]const u8,
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
            .location = undefined,
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
            .location = undefined,
        };

        try self.dependencies.append(method_node);
    }

    pub fn addDependency(self: *CodeFlowNode, dependency: *CodeFlowNode) !void {
        try self.dependencies.append(dependency);
        try dependency.references.append(self);
    }
};
