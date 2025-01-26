const std = @import("std");
const fs = std.fs;
const json = std.json;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};    
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const language = blk: {
        for (args) |arg, i| {
            if (std.mem.eql(u8, arg, "--language") and i+1 < args.len) {
                break :blk args[i+1];
            }
        }
        return error.MissingLanguageArg;
    };

    const output_path = blk: {
        for (args) |arg, i| {
            if (std.mem.eql(u8, arg, "--output") and i+1 < args.len) {
                break :blk args[i+1];
            }
        }
        return error.MissingOutputArg;
    };

    const parser_output_path = blk: {
        for (args) |arg, i| {
            if (std.mem.eql(u8, arg, "--parser-output") and i+1 < args.len) {
                break :blk args[i+1];
            }
        }
        return error.MissingParserOutputArg;
    };

    const grammar_json = try readGrammarFile(allocator, language);
    defer allocator.free(grammar_json);

    const node_types = try parseNodeTypes(allocator, language);
    defer node_types.deinit();

    try generateZigBindings(allocator, node_types, grammar_json, output_path);
    try generateParserImplementation(allocator, node_types, parser_output_path);
}

fn readGrammarFile(allocator: Allocator, lang: []const u8) ![]const u8 {
    const path = try std.fmt.allocPrint(allocator,
        "pkg/tree-sitter-{s}/{s}/src/grammar.json",
        .{lang, lang}
    );
    defer allocator.free(path);

    return try fs.cwd().readFileAlloc(allocator, path, 1 << 20);
}

fn parseNodeTypes(allocator: Allocator, lang: []const u8) !json.Parsed(NodeTypes) {
    const path = try std.fmt.allocPrint(allocator,
        "pkg/tree-sitter-{s}/{s}/src/node-types.json",
        .{lang, lang}
    );
    defer allocator.free(path);

    const data = try fs.cwd().readFileAlloc(allocator, path, 1 << 20);
    defer allocator.free(data);

    return json.parseFromSlice(NodeTypes, allocator, data, .{});
}

const NodeTypes = struct {
    types: []const NodeTypeDef,
};

const NodeTypeDef = struct {
    type: []const u8,
    named: bool,
    fields: ?[]const FieldDef,
};

const FieldDef = struct {
    name: []const u8,
    multiple: bool,
    required: bool,
    types: []const []const u8,
};

fn generateZigBindings(
    allocator: Allocator,
    node_types: json.Parsed(NodeTypes),
    grammar_json: []const u8,
    output_path: []const u8
) !void {
    var out = try fs.cwd().createFile(output_path, .{});
    defer out.close();

    var bw = std.io.bufferedWriter(out.writer());
    const w = bw.writer();

    try w.writeAll(
        \\// Auto-generated from Tree-sitter grammar definitions
        \\// DO NOT EDIT DIRECTLY
        \\
        \\pub const NodeType = enum {
        \\
    );

    for (node_types.value.types) |nt| {
        if (nt.named) {
            const clean_name = try sanitizeTypeName(allocator, nt.type);
            try w.print("    {s},\n", .{clean_name});
        }
    }

    try w.writeAll("};

");
    try w.writeAll(
        \\pub const Grammar = struct {
        \\    pub const rules = @embedFile("grammar.json");
        \\};
        \\
    );

    try bw.flush();
}

fn mapBaseKind(node_type: []const u8) []const u8 {
    return if (std.mem.endsWith(u8, node_type, "_declaration"))
        "Declaration"
    else if (std.mem.startsWith(u8, node_type, "export_"))
        "Export"
    else if (std.mem.startsWith(u8, node_type, "import_"))
        "Import"
    else
        "Expression";
}

fn sanitizeTypeName(allocator: Allocator, name: []const u8) ![]const u8 {
    var cleaned = try std.mem.replaceOwned(u8, allocator, name, "typescript/", "");
    cleaned = try std.mem.replaceOwned(u8, allocator, cleaned, "_", "");
    return cleaned;
}

fn generateParserImplementation(
    allocator: Allocator,
    node_types: json.Parsed(NodeTypes),
    output_path: []const u8,
) !void {
    var out = try fs.cwd().createFile(output_path, .{});
    defer out.close();
    var bw = std.io.bufferedWriter(out.writer());
    const w = bw.writer();

    try w.writeAll(
        \\// Auto-generated TypeScript parser implementation
        \\const std = @import("std");
        \\const tree_sitter = @import("../bindings/tree_sitter.zig");
        \\const ast_types = @import("../../core/ast/ast_types.zig");
        \\const NodeType = @import("typescript.zig").NodeType;
        \\
        \\pub const TypeScriptParser = struct {
        \\    parser: *tree_sitter.Parser,
        \\    allocator: std.mem.Allocator,
        \\
        \\    pub fn init(allocator: std.mem.Allocator) !*@This() {
        \\        const self = try allocator.create(@This());
        \\        self.parser = try tree_sitter.Parser.init(allocator);
        \\        self.allocator = allocator;
        \\        
        \\        const lang = tree_sitter_typescript();
        \\        try self.parser.setLanguage(lang);
        \\        return self;
        \\    }
        \\
        \\    pub fn deinit(self: *@This()) void {
        \\        self.parser.deinit();
        \\        self.allocator.destroy(self);
        \\    }
        \\
        \\    pub fn parse(self: *@This(), source: []const u8) !*ast_types.Node {
        \\        if (source.len == 0) return error.EmptySource;
        \\        if (source.len > std.math.maxInt(u32)) return error.SourceTooLarge;
        \\
        \\        const tree = tree_sitter.ts_parser_parse_string(
        \\            self.parser.ptr, 
        \\            null, 
        \\            source.ptr, 
        \\            @intCast(source.len)
        \\        ) orelse return error.ParseFailure;
        \\        defer tree_sitter.ts_tree_delete(tree);
        \\
        \\        const root = try ast_types.Node.init(self.allocator);
        \\        errdefer root.deinit();
        \\
        \\        root.kind = .{ .base = .Program, .custom_kind = null, .source = null };
        \\        root.children = std.ArrayList(*ast_types.Node).init(self.allocator);
        \\
    );

    // Generate node type handling
    for (node_types.value.types) |nt| {
        if (nt.named) {
            const clean_name = try sanitizeTypeName(allocator, nt.type);
            try w.print(
                \\        const {s}_nodes = self.findNodesOfType(tree, .{s});
                \\        for ({s}_nodes) |node| {{
                \\            const child = try self.createAstNode(node, source);
                \\            try root.children.append(child);
                \\        }}
                \\
            , .{clean_name, clean_name, clean_name});
        }
    }

    try w.writeAll(
        \\        return root;
        \\    }
        \\
        \\    fn createAstNode(self: *@This(), ts_node: tree_sitter.Node, source: []const u8) !*ast_types.Node {
        \\        const node_type = blk: {{
        \\            const type_str = tree_sitter.ts_node_type(ts_node) orelse return error.InvalidNode;
        \\            inline for (@typeInfo(NodeType).Enum.fields) |field| {{
        \\                if (std.mem.eql(u8, type_str, field.name)) {{
        \\                    break :blk @field(NodeType, field.name);
        \\                }}
        \\            }}
        \\            return error.UnknownNodeType;
        \\        }};
        \\
        \\        const node = try ast_types.Node.init(self.allocator, "", .{{
        \\            .base = switch (node_type) {{
        \\
    );

    // Generate base kind mapping
    for (node_types.value.types) |nt| {
        if (nt.named) {
            const clean_name = try sanitizeTypeName(allocator, nt.type);
            try w.print(
                \\            .{s} => .{s},
            , .{clean_name, mapBaseKind(nt.type)});
        }
    }

    try w.writeAll(
        \\                else => .unknown,
        \\            }},
        \\            .custom_kind = null,
        \\            .source = try self.allocator.dupe(u8, source),
        \\        }});
        \\        return node;
        \\    }}
        \\}};
        \\
        \\extern fn tree_sitter_typescript() *const tree_sitter.Language;
        \\
    );

    try bw.flush();
}
