const std = @import("std");
const ast_types = @import("core/ast/ast_types.zig");
const parser_mod = @import("parser/mod.zig");
const typescript = @import("parser/typescript.zig");
const flow = @import("core/flow.zig");
const Logger = @import("utils/log.zig").Logger;

pub const Project = struct {
    allocator: std.mem.Allocator,
    flow: *flow.Flow,
    parser: *parser_mod.Parser, // Use generic parser interface
    owned_nodes: std.ArrayList(*ast_types.Node),

    pub fn init(allocator: std.mem.Allocator) !Project {
        var ts_parser_impl = try typescript.TypeScriptParser.init(allocator);
        var parser = parser_mod.Parser.init(allocator, ts_parser_impl, &typescript.interface);

        return .{
            .allocator = allocator,
            .flow = try flow.Flow.init(allocator),
            .parser = parser,
            .owned_nodes = std.ArrayList(*ast_types.Node).init(allocator),
        };
    }

    pub fn deinit(self: *Project) void {
        self.flow.deinit();
        for (self.owned_nodes.items) |node| {
            node.deinit();
            self.allocator.destroy(node);
        }
        self.owned_nodes.deinit();
        self.parser.deinit();
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
        const root_node = self.parser.parse(source) catch |err| {
            Logger.scoped(.Error, "project").err("Parsing failed for file '{s}': {s}", .{ file_path, @errorName(err) });
            return error.ParsingFailed; // Or a more specific error if needed
        };
        if (root_node == null) {
            Logger.scoped(.Error, "project").err("Parsing returned null root node for file '{s}'", .{file_path});
            return error.NoRootNode; // Or a more specific error
        }

        // Add root node and its children to flow graph
        try self.flow.addNode(root_node);
        try self.owned_nodes.append(root_node);
    }

    pub fn writeToFile(self: *Project, file_path: []const u8) !void {
        try self.flow.writeToFile(file_path);
    }
};
