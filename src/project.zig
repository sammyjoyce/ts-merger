const std = @import("std");
const ast_types = @import("core/ast/ast.zig");
const parser_mod = @import("parser/mod.zig");
const typescript = @import("parser/typescript.zig");
const flow = @import("core/flow.zig");
const Logger = @import("utils/log.zig").Logger;

pub const Project = struct {
    allocator: std.mem.Allocator,
    flow: *flow.Flow,
    parser: *parser_mod.Parser,
    owned_nodes: std.ArrayList(*ast_types.Node),

    pub fn init(allocator: std.mem.Allocator, parser: *parser_mod.Parser) !Project {
        return .{
            .allocator = allocator,
            .flow = try flow.Flow.init(allocator),
            .parser = parser,
            .owned_nodes = std.ArrayList(*ast_types.Node).init(allocator),
        };
    }

    pub fn deinit(self: *Project) void {
        for (self.owned_nodes.items) |node| {
            node.deinit();
            self.allocator.destroy(node);
        }
        self.owned_nodes.deinit();
        self.flow.deinit();
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
            Logger.scoped(.Error, "project").err(
                "File too large: {s} (max {})",
                .{ file_path, max_size }
            );
            return error.FileSizeExceeded;
        }

        const source = try self.allocator.alloc(u8, @as(usize, @intCast(file_size)));
        // Source buffer ownership transferred to nodes

        const bytes_read = try file.readAll(source);
        if (bytes_read != source.len) {
            Logger.scoped(.Error, "project").err(
                "Partial read of {s}: read {}/{} bytes",
                .{ file_path, bytes_read, source.len }
            );
            std.debug.print("File read error: {s}\n", .{file_path});
            return error.FileReadError;
        }

        // Clear previous nodes before parsing new ones
        self.parser.nodes.clearRetainingCapacity();
        try self.parser.parse(source);

        // Transfer ownership directly from parser
        try self.owned_nodes.ensureTotalCapacity(self.parser.nodes.items.len);
        for (self.parser.nodes.items) |node| {
            node.allocator = self.allocator;  // Update allocator ownership
            try self.flow.addNode(node);
            self.owned_nodes.appendAssumeCapacity(node);
        }
        self.parser.nodes.clearRetainingCapacity();  // Clear parser's references
    }

    pub fn writeToFile(self: *Project, file_path: []const u8) !void {
        try self.flow.writeToFile(file_path);
    }
};
