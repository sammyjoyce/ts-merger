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

    const grammar_json = try readGrammarFile(allocator, language);
    defer allocator.free(grammar_json);

    const node_types = try parseNodeTypes(allocator, language);
    defer node_types.deinit();

    try generateZigBindings(allocator, node_types, grammar_json, output_path);
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

fn sanitizeTypeName(allocator: Allocator, name: []const u8) ![]const u8 {
    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    for (name) |c| {
        const valid = switch (c) {
            'A'...'Z', 'a'...'z', '0'...'9', '_' => true,
            else => false,
        };
        if (valid) {
            try buf.append(c);
        } else {
            try buf.append('_');
        }
    }

    return buf.toOwnedSlice();
}