const std = @import("std");
const Node = @import("../ast/node.zig").Node;
const common = @import("../languages/common.zig");
const rules = @import("rules.zig");

pub const MergeError = error{
    OutOfMemory,
    InvalidNode,
    ConflictingExports,
    CircularDependency,
};

pub const Merger = struct {
    allocator: std.mem.Allocator,
    parser: *const common.Parser,
    rules: rules.MergeRules,

    pub fn init(allocator: std.mem.Allocator, parser: *const common.Parser, merge_rules: rules.MergeRules) Merger {
        return .{
            .allocator = allocator,
            .parser = parser,
            .rules = merge_rules,
        };
    }

    pub fn merge(self: *const Merger, sources: []const []const u8) MergeError!*Node {
        var program = try Node.init(self.allocator, .Program, 0, 0);
        errdefer program.deinit(self.allocator);

        // Parse all sources
        var nodes = std.ArrayList(*Node).init(self.allocator);
        defer nodes.deinit();

        for (sources) |source| {
            const node = try self.parser.parse(source);
            try nodes.append(node);
        }

        // Apply merge rules
        try self.rules.apply(program, nodes.items);

        return program;
    }
};
