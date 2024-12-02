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

pub fn nodeKindFromString(kind_str: []const u8) !NodeKind.Kind {
    if (std.mem.eql(u8, kind_str, "program")) return .Program;
    if (std.mem.eql(u8, kind_str, "export_statement")) return .ExportDecl;
    if (std.mem.eql(u8, kind_str, "import_statement")) return .ImportDecl;
    if (std.mem.eql(u8, kind_str, "interface_declaration")) return .Interface;
    if (std.mem.eql(u8, kind_str, "class_declaration")) return .Class;
    if (std.mem.eql(u8, kind_str, "function_declaration")) return .Function;
    if (std.mem.eql(u8, kind_str, "variable_declaration")) return .Variable;
    if (std.mem.eql(u8, kind_str, "property_signature")) return .Property;
    if (std.mem.eql(u8, kind_str, "method_definition")) return .Method;
    if (std.mem.eql(u8, kind_str, "formal_parameters")) return .Parameter;
    if (std.mem.eql(u8, kind_str, "type_annotation")) return .TypeAnnotation;
    if (std.mem.eql(u8, kind_str, "comment")) return .Comment;
    if (std.mem.eql(u8, kind_str, "statement_block")) return .Block;
    if (std.mem.eql(u8, kind_str, "}")) return .BlockEnd;
    if (std.mem.eql(u8, kind_str, "identifier")) return .Identifier;
    if (std.mem.eql(u8, kind_str, "property_identifier")) return .Identifier;
    if (std.mem.eql(u8, kind_str, "type_identifier")) return .TypeIdentifier;
    if (std.mem.eql(u8, kind_str, "object_type")) return .ObjectType;
    if (std.mem.eql(u8, kind_str, "array_type")) return .ArrayType;
    if (std.mem.eql(u8, kind_str, "union_type")) return .UnionType;
    if (std.mem.eql(u8, kind_str, "constructor")) return .Constructor;
    if (std.mem.eql(u8, kind_str, "statement")) return .Statement;
    if (std.mem.eql(u8, kind_str, "expression")) return .Expression;
    if (std.mem.eql(u8, kind_str, "call_expression")) return .Call;
    if (std.mem.eql(u8, kind_str, "member_expression")) return .Member;
    if (std.mem.eql(u8, kind_str, "string")) return .String;
    if (std.mem.eql(u8, kind_str, "string_literal")) return .String;
    if (std.mem.eql(u8, kind_str, "number")) return .Number;
    if (std.mem.eql(u8, kind_str, "number_literal")) return .Number;
    if (std.mem.eql(u8, kind_str, ";")) return .Semicolon;
    if (std.mem.eql(u8, kind_str, ",")) return .Comma;
    if (std.mem.eql(u8, kind_str, "public")) return .Public;
    if (std.mem.eql(u8, kind_str, "private")) return .Private;
    if (std.mem.eql(u8, kind_str, "protected")) return .Protected;
    if (std.mem.eql(u8, kind_str, "return")) return .Return;
    if (std.mem.eql(u8, kind_str, "this")) return .This;
    if (std.mem.eql(u8, kind_str, "=>")) return .Arrow;
    if (std.mem.eql(u8, kind_str, "=")) return .Equals;
    if (std.mem.eql(u8, kind_str, "[")) return .LeftBracket;
    if (std.mem.eql(u8, kind_str, "]")) return .RightBracket;
    if (std.mem.eql(u8, kind_str, "(")) return .LeftParen;
    if (std.mem.eql(u8, kind_str, ")")) return .RightParen;
    if (std.mem.eql(u8, kind_str, "{")) return .LeftBrace;
    if (std.mem.eql(u8, kind_str, "}")) return .RightBrace;
    if (std.mem.eql(u8, kind_str, "|")) return .Pipe;
    if (std.mem.eql(u8, kind_str, "===")) return .TripleEquals;
    return .Unknown;
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
            // SAFETY: The 'location' will be initialized before being accessed.
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
            // SAFETY: The 'location' will be initialized before being accessed.
            .location = undefined,
        };

        try self.dependencies.append(method_node);
    }

    pub fn addDependency(self: *CodeFlowNode, dependency: *CodeFlowNode) !void {
        try self.dependencies.append(dependency);
        try dependency.references.append(self);
    }
};
