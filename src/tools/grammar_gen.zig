// This file is responsible for generating Zig bindings from Tree-sitter grammar
const std = @import("std");
const fs = std.fs;
const json = std.json;
const mem = std.mem;
const Allocator = mem.Allocator;

pub const GrammarError = error{
    InvalidNodeType,
    MissingRequiredField,
    InvalidFieldType,
    InvalidGrammarJson,
    InvalidNodeTypeMapping,
};

pub fn generateGrammarBindings(allocator: Allocator, node_types_path: []const u8, output_path: []const u8) !void {
    // Read and parse the node-types.json file
    const node_types_content = try fs.cwd().readFileAlloc(allocator, node_types_path, std.math.maxInt(usize));
    defer allocator.free(node_types_content);

    var node_types = try json.parseFromSlice(NodeTypes, allocator, node_types_content, .{});
    defer node_types.deinit();

    // Create output file
    var out = try fs.cwd().createFile(output_path, .{});
    defer out.close();
    var bw = std.io.bufferedWriter(out.writer());
    const w = bw.writer();

    try w.writeAll("// Generated code - do not edit\n\n");
    try w.writeAll("const std = @import(\"std\");\n");
    try w.writeAll("const bindings = @import(\"../bindings/mod.zig\");\n");
    try w.writeAll("const ast_types = @import(\"../core/ast/ast_types.zig\");\n\n");

    // Generate node type mapping
    try w.writeAll("pub const NodeTypes = struct {\n");
    for (node_types.value.types) |node_type| {
        if (!node_type.named) continue;
        try w.print("    pub const {s} = \"{s}\";\n", .{ std.ascii.upperString(node_type.type), node_type.type });

        // Generate field accessors if available
        if (node_type.fields) |fields| {
            try w.print("    pub const {s}_FIELDS = struct {{\n", .{std.ascii.upperString(node_type.type)});
            for (fields.types) |field_type| {
                try w.print("        pub const {s}: bool = {s};\n", .{ std.ascii.upperString(field_type.type), if (fields.required) "true" else "false" });
            }
            try w.writeAll("    };\n");
        }
    }
    try w.writeAll("};");

    try w.writeAll("\n\npub const NodeType = enum {\n");

    for (node_types.value.types) |nt| {
        if (nt.named) {
            const clean_name = try sanitizeTypeName(allocator, nt.type);
            try w.print("    {s},\n", .{clean_name});
        }
    }

    try w.writeAll("};");

    try w.writeAll("\n\npub const Grammar = struct {\n");
    try w.writeAll("    pub const rules = @embedFile(\"grammar.json\");\n");
    try w.writeAll("};");

    try bw.flush();
}

fn mapBaseKind(node_type: []const u8) []const u8 {
    if (std.mem.endsWith(u8, node_type, "_declaration")) return "Declaration";
    if (std.mem.startsWith(u8, node_type, "export_")) return "Export";
    if (std.mem.startsWith(u8, node_type, "import_")) return "Import";
    if (std.mem.startsWith(u8, node_type, "class_")) return "Class";
    if (std.mem.startsWith(u8, node_type, "interface_")) return "Interface";
    if (std.mem.startsWith(u8, node_type, "method_")) return "Method";
    if (std.mem.startsWith(u8, node_type, "property_")) return "Property";
    if (std.mem.startsWith(u8, node_type, "type_")) return "Type";
    if (std.mem.startsWith(u8, node_type, "function_")) return "Function";
    return "Unknown";
}

fn sanitizeTypeName(allocator: Allocator, name: []const u8) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var capitalize = true;
    for (name) |c| {
        if (c == '_') {
            capitalize = true;
            continue;
        }
        if (capitalize) {
            try result.append(std.ascii.toUpper(c));
            capitalize = false;
        } else {
            try result.append(c);
        }
    }

    return result.toOwnedSlice();
}

const NodeTypes = struct {
    value: struct {
        types: []const struct {
            type: []const u8,
            named: bool,
            fields: ?struct {
                multiple: bool,
                required: bool,
                types: []const struct {
                    type: []const u8,
                    named: bool,
                },
            },
            children: ?struct {
                multiple: bool,
                required: bool,
                types: []const struct {
                    type: []const u8,
                    named: bool,
                },
            },
            subtypes: ?[]const struct {
                type: []const u8,
                named: bool,
            },
        },
    },

    pub fn deinit(self: @This()) void {
        for (self.value.types) |node_type| {
            if (node_type.fields) |fields| {
                for (fields.types) |_| {} // Free memory if needed
            }
            if (node_type.children) |children| {
                for (children.types) |_| {} // Free memory if needed
            }
            if (node_type.subtypes) |subtypes| {
                for (subtypes) |_| {} // Free memory if needed
            }
        }
        self.value.types.deinit();
    }
};
