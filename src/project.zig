const std = @import("std");
const ast_types = @import("ast_types.zig");
const parser_mod = @import("parser/mod.zig");
const typescript = @import("parser/typescript.zig");

pub const Project = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(*ast_types.Node),

    pub fn init(allocator: std.mem.Allocator) !Project {
        return Project{
            .allocator = allocator,
            .nodes = std.ArrayList(*ast_types.Node).init(allocator),
        };
    }

    pub fn deinit(self: *Project) void {
        for (self.nodes.items) |node| {
            node.deinit();
            self.allocator.destroy(node);
        }
        self.nodes.deinit();
    }

    pub fn getNodes(self: *Project) []const *ast_types.Node {
        return self.nodes.items;
    }

    pub fn parseFile(self: *Project, file_path: []const u8) !void {
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const file_size = try file.getEndPos();
        if (file_size > std.math.maxInt(u32)) {
            return error.FileTooLarge;
        }

        // Corrected @intCast usage: specify target type and value
        const source = try self.allocator.alloc(u8, @as(usize, @intCast(file_size)));
        defer self.allocator.free(source);

        const bytes_read = try file.readAll(source);
        if (bytes_read != @as(usize, @intCast(file_size))) {
            return error.FileReadError;
        }

        var parser = try typescript.TypeScriptParser.init(self.allocator);
        defer parser.deinit();

        try parser.parse(source);
        for (parser.nodes.items) |node| {
            const node_copy = try node.clone(self.allocator);
            try self.nodes.append(node_copy);
        }
    }

    pub fn writeToFile(self: *Project, file_path: []const u8) !void {
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();

        var buffered = std.io.bufferedWriter(file.writer());
        var writer = buffered.writer();

        for (self.nodes.items) |node| {
            if (node.value) |value| {
                // Ensure that 'value' is a valid null-terminated string
                try writer.print("{s}\n", .{value});
            } else {
                // Handle the case where 'node.value' is null
                try writer.print("Invalid node value\n", .{});
            }
        }

        try buffered.flush();
    }
};
