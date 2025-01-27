const std = @import("std");
const bindings = @import("../bindings/mod.zig");
const ast_types = @import("../core/ast/ast_types.zig");
const testing = std.testing;

pub const LanguageMetadata = struct {
    name: []const u8,
    extensions: []const []const u8,
    parser_create: *const fn (allocator: std.mem.Allocator) anyerror!*bindings.tree_sitter.Parser,
    node_types: NodeTypeInfo,
    detect_content: *const fn ([]const u8) bool,

    pub fn init(name: []const u8, extensions: []const []const u8, parser_create: *const fn (allocator: std.mem.Allocator) anyerror!*bindings.tree_sitter.Parser, node_types: NodeTypeInfo, detect_content: *const fn ([]const u8) bool) LanguageMetadata {
        return .{
            .name = name,
            .extensions = extensions,
            .parser_create = parser_create,
            .node_types = node_types,
            .detect_content = detect_content,
        };
    }
};

pub const NodeTypeInfo = struct {
    program: []const u8,
    interface_decl: []const u8,
    class_decl: []const u8,
    function_decl: []const u8,
    variable_decl: []const u8,
    import_decl: []const u8,
    export_decl: []const u8,
};

pub const LanguageRegistry = struct {
    languages: []const *const LanguageMetadata,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, languages: []const *const LanguageMetadata) LanguageRegistry {
        return .{
            .allocator = allocator,
            .languages = languages,
        };
    }

    pub fn detect(self: *const LanguageRegistry, filename: ?[]const u8, source: []const u8) !*const LanguageMetadata {
        // Try detection by file extension first
        if (filename) |fname| {
            const detected = try self.detectByExtension(fname);
            if (detected) |lang| return lang;
        }

        // Fall back to content-based detection
        return self.detectByContent(source) orelse error.LanguageNotDetected;
    }

    fn detectByExtension(self: *const LanguageRegistry, filename: []const u8) !?*const LanguageMetadata {
        if (std.mem.lastIndexOfScalar(u8, filename, '.')) |dot| {
            const ext = filename[dot + 1 ..];
            for (self.languages) |lang| {
                for (lang.extensions) |lang_ext| {
                    if (std.mem.eql(u8, ext, lang_ext)) {
                        return lang;
                    }
                }
            }
        }
        return null;
    }

    fn detectByContent(self: *const LanguageRegistry, source: []const u8) ?*const LanguageMetadata {
        // Basic content analysis for TypeScript/JavaScript
        if (source.len == 0) return null;

        var has_jsx = false;
        var has_types = false;

        // Look for TypeScript-specific syntax
        if (std.mem.indexOf(u8, source, "interface ") != null or
            std.mem.indexOf(u8, source, ": type") != null or
            std.mem.indexOf(u8, source, "type ") != null)
        {
            has_types = true;
        }

        // Look for JSX syntax
        if (std.mem.indexOf(u8, source, "<>") != null ||
            (std.mem.indexOf(u8, source, "/>") != null) ||
            (std.mem.indexOf(u8, source, "</") != null))
        {
            has_jsx = true;
        }

        // Select appropriate language based on content analysis
        for (self.languages) |lang| {
            if (has_jsx and std.mem.eql(u8, lang.name, "tsx")) return lang;
            if (has_types and std.mem.eql(u8, lang.name, "typescript")) return lang;
            if (!has_types and !has_jsx and std.mem.eql(u8, lang.name, "javascript")) return lang;
        }

        return null;
    }
};

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

pub const ParserError = error{
    NoLanguageDetected,
    UnsupportedLanguage,
    DetectionFailed,
    ParserInitFailed,
    InvalidSource,
    ParseFailure,
};

pub const Parser = struct {
    allocator: std.mem.Allocator,
    lang_registry: *LanguageRegistry,
    current_lang: ?*const LanguageMetadata,

    pub fn init(allocator: std.mem.Allocator, lang_registry: *LanguageRegistry) Parser {
        return .{
            .allocator = allocator,
            .lang_registry = lang_registry,
            .current_lang = null,
        };
    }

    pub fn detectLanguage(self: *Parser, source: []const u8, filename: ?[]const u8) !void {
        if (filename) |fname| {
            if (try self.lang_registry.detectByExtension(fname)) |lang| {
                self.current_lang = lang;
                return;
            }
        }

        // Try content-based detection if extension detection failed
        for (self.lang_registry.languages) |lang| {
            if (lang.detect_content(source)) {
                self.current_lang = lang;
                return;
            }
        }

        return ParserError.DetectionFailed;
    }

    pub fn parse(self: *Parser, source: []const u8) !*ast_types.Node {
        const lang = self.current_lang orelse return ParserError.NoLanguageDetected;

        if (source.len == 0) return ParserError.InvalidSource;
        if (source.len > std.math.maxInt(u32)) return ParserError.InvalidSource;

        const parser_impl = try lang.parser_create(self.allocator);
        defer parser_impl.deinit();

        return try parser_impl.parse(source);
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
