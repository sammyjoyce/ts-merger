const std = @import("std");
const ast_types = @import("ast_types");
const testing = std.testing;
const typescript = @import("../bindings/tree_sitter_typescript.zig");

pub const ParserInterface = struct {
    deinitFn: *const fn (ctx: *anyopaque) void,
    parseFn: *const fn (ctx: *anyopaque, source: []const u8) error{ EmptySource, ParseError, LanguageError, Unimplemented }!*ast_types.Node,

    pub fn deinit(self: *const ParserInterface, ctx: *anyopaque) void {
        self.deinitFn(ctx);
    }

    pub fn parse(self: *const ParserInterface, ctx: *anyopaque, source: []const u8) !*ast_types.Node {
        return self.parseFn(ctx, source);
    }
};

pub const Parser = struct {
    allocator: std.mem.Allocator,
    impl_ptr: *anyopaque,
    interface: *const ParserInterface,

    pub fn init(allocator: std.mem.Allocator, impl_ptr: *anyopaque, interface: *const ParserInterface) Parser {
        return .{
            .allocator = allocator,
            .impl_ptr = impl_ptr,
            .interface = interface,
        };
    }

    pub fn deinit(self: *Parser) void {
        self.interface.deinit(self.impl_ptr);
    }

    pub fn parse(self: *Parser, source: []const u8) !*ast_types.Node {
        return self.interface.parse(self.impl_ptr, source);
    }
};

pub const ParserImpl = struct {
    pub fn deinit(self: *ParserImpl) void {
        _ = self;
    }

    pub fn parse(self: *ParserImpl, source: []const u8) !*ast_types.Node {
        _ = self;
        _ = source;
        return error.Unimplemented;
    }
};

test "parser memory management" {
    const allocator = testing.allocator;
    var ts_parser_impl = try typescript.TypeScriptParser.init(allocator);
    defer ts_parser_impl.deinit();
    var ts_parser = Parser.init(allocator, ts_parser_impl);
    defer ts_parser.deinit();

    // Test memory management with large files
    var large_source = std.ArrayList(u8).init(allocator);
    defer large_source.deinit();

    // Create a large TypeScript file content
    try large_source.appendSlice("interface Test {");
    for (0..1000) |i| {
        const field = try std.fmt.allocPrint(allocator, "    field{d}: string;\n", .{i});
        defer allocator.free(field);
        try large_source.appendSlice(field);
    }
    try large_source.appendSlice("}");

    // Parse the large file and ensure proper cleanup
    const root_node = try ts_parser.parse(large_source.items);
    defer root_node.deinit();
    defer allocator.destroy(root_node);

    try testing.expect(root_node.children.items.len > 0);
}

test "parser error handling" {
    const allocator = testing.allocator;
    var ts_parser_impl = try typescript.TypeScriptParser.init(allocator);
    defer ts_parser_impl.deinit();
    var ts_parser = Parser.init(allocator, ts_parser_impl);
    defer ts_parser.deinit();

    // Test parsing invalid TypeScript code
    const invalid_source = "class Test { constructor( }";
    const root_node = try ts_parser.parse(invalid_source);
    defer root_node.deinit();
    defer allocator.destroy(root_node);

    // Even with syntax errors, we should get a root node
    try testing.expect(root_node != null);
    try testing.expect(root_node.children.items.len > 0);
}

test "parser memory management" {
    const allocator = testing.allocator;
    var ts_parser_impl = try typescript.TypeScriptParser.init(allocator);
    defer ts_parser_impl.deinit();
    var ts_parser = Parser.init(allocator, ts_parser_impl);
    defer ts_parser.deinit();

    // Test memory management with large files
    var large_source = std.ArrayList(u8).init(allocator);
    defer large_source.deinit();

    // Create a large TypeScript file content
    try large_source.appendSlice("interface Test {");
    for (0..1000) |i| {
        const field = try std.fmt.allocPrint(allocator, "    field{d}: string;\n", .{i});
        defer allocator.free(field);
        try large_source.appendSlice(field);
    }
    try large_source.appendSlice("}");

    // Parse the large file and ensure proper cleanup
    const root_node = try ts_parser.parse(large_source.items);
    defer root_node.deinit();
    defer allocator.destroy(root_node);

    try testing.expect(root_node.children.items.len > 0);
}

test "parser error handling" {
    const allocator = testing.allocator;
    var ts_parser_impl = try typescript.TypeScriptParser.init(allocator);
    defer ts_parser_impl.deinit();
    var ts_parser = Parser.init(allocator, ts_parser_impl);
    defer ts_parser.deinit();

    // Test parsing invalid TypeScript code
    const invalid_source = "class Test { constructor( }";
    const root_node = try ts_parser.parse(invalid_source);
    defer root_node.deinit();
    defer allocator.destroy(root_node);

    // Even with syntax errors, we should get a root node
    try testing.expect(root_node != null);
    try testing.expect(root_node.children.items.len > 0);
}
test "parser memory management" {
    const allocator = testing.allocator;
    var ts_parser_impl = try typescript.TypeScriptParser.init(allocator);
    defer ts_parser_impl.deinit();
    var ts_parser = Parser.init(allocator, ts_parser_impl);
    defer ts_parser.deinit();

    // Test memory management with large files
    var large_source = std.ArrayList(u8).init(allocator);
    defer large_source.deinit();

    // Create a large TypeScript file content
    try large_source.appendSlice("interface Test {");
    for (0..1000) |i| {
        const field = try std.fmt.allocPrint(allocator, "    field{d}: string;\n", .{i});
        defer allocator.free(field);
        try large_source.appendSlice(field);
    }
    try large_source.appendSlice("}");

    // Parse the large file and ensure proper cleanup
    const root_node = try ts_parser.parse(large_source.items);
    defer root_node.deinit();
    defer allocator.destroy(root_node);

    try testing.expect(root_node.children.items.len > 0);
}

test "parser error handling" {
    const allocator = testing.allocator;
    var ts_parser_impl = try typescript.TypeScriptParser.init(allocator);
    defer ts_parser_impl.deinit();
    var ts_parser = Parser.init(allocator, ts_parser_impl);
    defer ts_parser.deinit();

    // Test parsing invalid TypeScript code
    const invalid_source = "class Test { constructor( }";
    const root_node = try ts_parser.parse(invalid_source);
    defer root_node.deinit();
    defer allocator.destroy(root_node);

    // Even with syntax errors, we should get a root node
    try testing.expect(root_node != null);
    try testing.expect(root_node.children.items.len > 0);
}
