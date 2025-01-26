const std = @import("std");
const ast_types = @import("core/ast/ast_types.zig");
const parser_mod = @import("parser/mod.zig");
const LanguageRegistry = @import("bindings/language.zig").LanguageRegistry;
const Logger = @import("utils/log.zig").Logger;

pub const Project = struct {
    allocator: std.mem.Allocator,
    lang_registry: *LanguageRegistry,
    ast_root: *ast_types.Node,
    owned_nodes: std.ArrayList(*ast_types.Node),

    pub fn init(allocator: std.mem.Allocator, lang_registry: *LanguageRegistry) !Project {
        return .{
            .allocator = allocator,
            .lang_registry = lang_registry,
            .ast_root = try ast_types.Node.init(allocator),
            .owned_nodes = std.ArrayList(*ast_types.Node).init(allocator),
        };
    }

    pub fn deinit(self: *Project) void {
        self.ast_root.deinit();
        for (self.owned_nodes.items) |node| {
            node.deinit();
            self.allocator.destroy(node);
        }
        self.owned_nodes.deinit();
    }

    pub fn getNodes(self: *Project) []const *ast_types.Node {
        return self.owned_nodes.items;
    }

    pub fn parseFile(self: *Project, file_path: []const u8) !void {
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        const max_size = 1024 * 1024 * 10; // 10MB limit
        if (file_size > max_size) {
            Logger.scoped(.Error, "project").err("File too large: {s} (max {})", .{ file_path, max_size });
            return error.FileSizeExceeded;
        }

        const source = try self.allocator.alloc(u8, @as(usize, @intCast(file_size)));
        // Source buffer ownership transferred to nodes

        const bytes_read = try file.readAll(source);
        if (bytes_read != source.len) {
            Logger.scoped(.Error, "project").err("Partial read of {s}: read {}/{} bytes", .{ file_path, bytes_read, source.len });
            std.debug.print("File read error: {s}\n", .{file_path});
            return error.FileReadError;
        }

        // Parse source using the generic parser interface
        var parser = parser_mod.Parser.init(self.allocator, self.lang_registry);
        defer parser.deinit();

        try parser.detectLanguage(source, file_path);
        const root_node = try parser.parse(source);
        try self.mergeAst(root_node);
    }

    fn mergeAst(self: *Project, new_node: *ast_types.Node) !void {
        // Existing merge logic adapted for language-aware nodes
        try self.ast_root.merge(new_node);
        try self.owned_nodes.append(new_node);
    }

    pub fn writeToFile(self: *Project, file_path: []const u8) !void {
        const output = try self.ast_root.serialize(self.allocator);
        defer self.allocator.free(output);
        
        try std.fs.cwd().writeFile(file_path, output);
    }
};
