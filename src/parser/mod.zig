const std = @import("std");
const bindings = @import("../bindings/mod.zig");
const ast_types = @import("../core/ast/ast_types.zig");
const testing = std.testing;

// Re-export the LanguageMetadata and NodeTypeInfo from bindings
pub const LanguageMetadata = bindings.language.LanguageMetadata;
pub const NodeTypeInfo = bindings.language.NodeTypeInfo;

// Use the LanguageRegistry from bindings
pub const LanguageRegistry = bindings.language.LanguageRegistry;

// Test cases
test "language detection" {
    const allocator = testing.allocator;
    var registry = try LanguageRegistry.init(allocator);
    defer registry.deinit();

    // Register TypeScript language
    try registry.register(bindings.language.BuiltinLanguages[0]);

    // Test TypeScript detection
    const ts_source = \\
        interface User {
            name: string;
            age: number;
        }
    ;

    const detected = try registry.detect("test.ts", ts_source);
    try testing.expectEqualStrings("typescript", detected.name);
}

test "parser memory management - basic" {
    const allocator = testing.allocator;
    var ts_parser_impl = try bindings.TreeSitter.ts_parser_new();
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

test "parser error handling - basic" {
    const allocator = testing.allocator;
    var ts_parser_impl = try tree_sitter_ts.TypeScriptParser.init(allocator);
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

test "parser memory management - advanced" {
    const allocator = testing.allocator;
    var ts_parser_impl = try tree_sitter_ts.TypeScriptParser.init(allocator);
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

test "parser error handling - advanced" {
    const allocator = testing.allocator;
    var ts_parser_impl = try tree_sitter_ts.TypeScriptParser.init(allocator);
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
test "parser memory management - edge cases" {
    const allocator = testing.allocator;
    var ts_parser_impl = try tree_sitter_ts.TypeScriptParser.init(allocator);
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

test "parser error handling - edge cases" {
    const allocator = testing.allocator;
    var ts_parser_impl = try tree_sitter_ts.TypeScriptParser.init(allocator);
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
