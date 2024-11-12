const std = @import("std");
const Node = @import("../ast/node.zig").Node;

pub const MergeRules = struct {
    preserve_comments: bool,
    sort_imports: bool,

    pub fn apply(self: MergeRules, program: *Node, nodes: []*Node) !void {
        // First pass: collect all exports and detect conflicts
        var exports = std.StringHashMap(*Node).init(program.children.allocator);
        defer exports.deinit();

        for (nodes) |node| {
            try self.collectExports(node, &exports);
        }

        // Second pass: resolve imports and merge
        for (nodes) |node| {
            try self.resolveImports(node, exports);
            try self.mergeNode(program, node);
        }

        // Optional: sort imports
        if (self.sort_imports) {
            try self.sortProgramImports(program);
        }
    }

    fn collectExports(self: MergeRules, node: *Node, exports: *std.StringHashMap(*Node)) !void {
        if (node.kind == .Export) {
            const name = node.getIdentifier() orelse return error.InvalidNode;
            const existing = try exports.getOrPut(name);

            if (existing.found_existing) {
                return error.ConflictingExports;
            }
            existing.value_ptr.* = node;
        }

        // Recursively collect exports from children
        for (node.children.items) |child| {
            try self.collectExports(child, exports);
        }
    }

    fn resolveImports(self: MergeRules, node: *Node, exports: std.StringHashMap(*Node)) !void {
        if (node.kind == .Import) {
            const name = node.getIdentifier() orelse return error.InvalidNode;
            if (exports.get(name)) |export_node| {
                // Replace import with the exported declaration
                try node.replaceWith(export_node);
            }
        }

        // Recursively resolve imports in children
        for (node.children.items) |child| {
            try self.resolveImports(child, exports);
        }
    }

    fn mergeNode(self: MergeRules, program: *Node, node: *Node) !void {
        switch (node.kind) {
            .Program => {
                // Merge all top-level declarations
                for (node.children.items) |child| {
                    try self.mergeNode(program, child);
                }
            },
            .Import => {
                if (self.sort_imports) {
                    // Skip imports, they'll be sorted later
                    return;
                }
                try program.addChild(node);
            },
            else => {
                // Add all other nodes to the program
                try program.addChild(node);
            },
        }

        // Preserve comments if enabled
        if (self.preserve_comments and node.comments.items.len > 0) {
            try program.comments.appendSlice(node.comments.items);
        }
    }

    fn sortProgramImports(self: MergeRules, program: *Node) !void {
        _ = self;
        var imports = std.ArrayList(*Node).init(program.children.allocator);
        defer imports.deinit();

        // Collect all import declarations
        var i: usize = 0;
        while (i < program.children.items.len) {
            const child = program.children.items[i];
            if (child.kind == .Import) {
                try imports.append(child);
                _ = program.children.orderedRemove(i);
            } else {
                i += 1;
            }
        }

        // Sort imports by source path
        std.sort.sort(*Node, imports.items, {}, struct {
            fn lessThan(_: void, a: *Node, b: *Node) bool {
                const a_path = a.getSourcePath() orelse return false;
                const b_path = b.getSourcePath() orelse return false;
                return std.mem.lessThan(u8, a_path, b_path);
            }
        }.lessThan);

        // Add sorted imports back to the program
        try program.children.insertSlice(0, imports.items);
    }
};
