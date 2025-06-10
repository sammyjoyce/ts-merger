const std = @import("std");
const Node = @import("../ast/ast_types.zig").Node;

pub const MergeRules = struct {
    preserve_comments: bool,
    sort_imports: bool,
    remove_redundancies: bool = false, // Default to false for backward compatibility
    optimize_import_paths: bool = false, // Default to false for backward compatibility
    eliminate_dead_code: bool = false, // Default to false for backward compatibility

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

        // Optional: sort imports and remove redundancies
        if (self.sort_imports or self.remove_redundancies) {
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

    pub fn getImportScope(source_path: []const u8) ImportScope {
        // Built-in modules typically don't have a path with '/' or '.'
        if (std.mem.indexOf(u8, source_path, "/") == null and
            std.mem.indexOf(u8, source_path, ".") == null)
        {
            return .BuiltIn;
        }

        // External modules typically start with '@' or don't start with '.' or '/'
        if (source_path[0] == '@' or (source_path[0] != '.' and source_path[0] != '/')) {
            return .External;
        }

        // Internal modules typically start with './' or '../'
        return .Internal;
    }

    /// Optimizes an import path by normalizing and simplifying it.
    /// This includes:
    /// 1. Normalizing path separators (using forward slashes consistently)
    /// 2. Simplifying paths with unnecessary segments (e.g., `./foo/../bar` to `./bar`)
    /// 3. Handling index files appropriately (e.g., `./foo/index` to `./foo`)
    /// 4. Removing file extensions if they're not needed
    pub fn optimizeImportPath(self: MergeRules, allocator: std.mem.Allocator, source_path: []const u8) ![]const u8 {
        // Skip optimization for built-in and external modules
        const scope = getImportScope(source_path);
        if (scope != .Internal) {
            return allocator.dupe(u8, source_path);
        }

        // Create a mutable copy of the path
        var path_buf = try allocator.dupe(u8, source_path);

        // 1. Normalize path separators (replace backslashes with forward slashes)
        for (path_buf) |*c| {
            if (c.* == '\\') {
                c.* = '/';
            }
        }

        // 2. Simplify paths with unnecessary segments
        var path_parts = std.ArrayList([]const u8).init(allocator);
        defer path_parts.deinit();

        var it = std.mem.split(u8, path_buf, "/");
        while (it.next()) |part| {
            if (std.mem.eql(u8, part, ".")) {
                // Skip "." parts
                continue;
            } else if (std.mem.eql(u8, part, "..")) {
                // Handle ".." by removing the last part if possible
                if (path_parts.items.len > 0) {
                    _ = path_parts.pop();
                } else {
                    // If we can't go up further, keep the ".."
                    try path_parts.append(part);
                }
            } else if (part.len > 0) {
                // Add non-empty parts
                try path_parts.append(part);
            }
        }

        // 3. Handle index files and remove extensions
        if (path_parts.items.len > 0) {
            const last_part = path_parts.items[path_parts.items.len - 1];

            // Check if the last part is "index" or "index.js", "index.ts", etc.
            if (std.mem.startsWith(u8, last_part, "index")) {
                const ext_pos = std.mem.indexOf(u8, last_part, ".");
                if (ext_pos == null or ext_pos.? == 5) { // "index" or "index.ext"
                    _ = path_parts.pop(); // Remove the index part
                }
            } else {
                // Remove common extensions (.js, .ts, .jsx, .tsx)
                const extensions = [_][]const u8{ ".js", ".ts", ".jsx", ".tsx" };
                for (extensions) |ext| {
                    if (std.mem.endsWith(u8, last_part, ext)) {
                        const new_part = last_part[0 .. last_part.len - ext.len];
                        path_parts.items[path_parts.items.len - 1] = new_part;
                        break;
                    }
                }
            }
        }

        // Reconstruct the path
        allocator.free(path_buf); // Free the original copy

        // Handle special case of empty path (e.g., all parts were removed)
        if (path_parts.items.len == 0) {
            return allocator.dupe(u8, ".");
        }

        // Start with "./" for relative paths
        var is_relative = false;
        if (source_path.len > 0 and source_path[0] == '.') {
            is_relative = true;
        }

        // Calculate the total length needed
        var total_len: usize = 0;
        if (is_relative) {
            total_len += 2; // "./"
        }

        for (path_parts.items, 0..) |part, i| {
            total_len += part.len;
            if (i < path_parts.items.len - 1) {
                total_len += 1; // For the slash
            }
        }

        // Allocate and build the final path
        var result = try allocator.alloc(u8, total_len);
        var pos: usize = 0;

        if (is_relative) {
            result[pos] = '.';
            result[pos + 1] = '/';
            pos += 2;
        }

        for (path_parts.items, 0..) |part, i| {
            std.mem.copy(u8, result[pos..], part);
            pos += part.len;

            if (i < path_parts.items.len - 1) {
                result[pos] = '/';
                pos += 1;
            }
        }

        return result;
    }

    pub const ImportScope = enum {
        BuiltIn, // Node.js built-in modules (e.g., 'fs', 'path')
        External, // External dependencies (e.g., 'react', '@types/node')
        Internal, // Internal project modules (e.g., './utils', '../components')
    };

    /// Identifies and removes unused imports and code from the program.
    /// This method:
    /// 1. Collects all imported symbols from import declarations
    /// 2. Collects all exported symbols (functions, variables, classes, etc.)
    /// 3. Tracks references to these symbols throughout the code
    /// 4. Removes imports and code for symbols that are not referenced
    fn eliminateDeadCode(self: MergeRules, program: *Node, imports: *std.ArrayList(*Node)) !void {
        const allocator = program.allocator;

        // Create maps to track symbols and their usage
        var imported_symbols = std.StringHashMap(bool).init(allocator);
        defer imported_symbols.deinit();

        var declared_symbols = std.StringHashMap(struct {
            used: bool,
            node: *Node,
        }).init(allocator);
        defer declared_symbols.deinit();

        // Collect all imported symbols
        for (imports.items) |import_node| {
            if (import_node.getImportedSymbols()) |symbols| {
                defer symbols.deinit();

                for (symbols.items) |symbol| {
                    // Skip the default import name (which is the node's name)
                    if (std.mem.eql(u8, symbol, import_node.name)) continue;

                    // Add the symbol to the map, initially marked as unused
                    try imported_symbols.put(symbol, false);
                }
            }
        }

        // Collect all declared symbols (functions, variables, classes, etc.)
        for (program.children.items) |child| {
            // Skip import declarations as they're handled separately
            if (child.kind.base == .ImportDecl) continue;

            // Check for function declarations, variable declarations, class declarations, etc.
            switch (child.kind.base) {
                .Function, .Variable, .Class, .Interface, .Method, .Property => {
                    // Add the symbol to the map, initially marked as unused
                    try declared_symbols.put(child.name, .{ .used = false, .node = child });
                },
                else => {},
            }
        }

        // Recursively traverse the AST to track references to symbols
        try trackSymbolUsage(program, &imported_symbols, &declared_symbols);

        // Remove unused imports
        var i: usize = 0;
        while (i < imports.items.len) {
            const import_node = imports.items[i];
            var has_used_symbols = false;

            if (import_node.getImportedSymbols()) |symbols| {
                defer symbols.deinit();

                // Check if any of the imported symbols are used
                for (symbols.items) |symbol| {
                    if (imported_symbols.get(symbol)) |used| {
                        if (used) {
                            has_used_symbols = true;
                            break;
                        }
                    }
                }
            }

            if (!has_used_symbols) {
                // Remove the unused import
                _ = imports.orderedRemove(i);
            } else {
                // Keep the import and move to the next one
                i += 1;
            }
        }

        // Remove unused declared symbols (dead code)
        i = 0;
        while (i < program.children.items.len) {
            const child = program.children.items[i];

            // Skip import declarations as they're handled separately
            if (child.kind.base == .ImportDecl) {
                i += 1;
                continue;
            }

            // Check if this is a declaration that can be removed
            switch (child.kind.base) {
                .Function, .Variable, .Class, .Interface, .Method, .Property => {
                    if (declared_symbols.get(child.name)) |entry| {
                        if (!entry.used) {
                            // Remove the unused declaration
                            _ = program.children.orderedRemove(i);
                            continue;
                        }
                    }
                },
                else => {},
            }

            // Move to the next child
            i += 1;
        }
    }

    /// Recursively traverses the AST and tracks references to symbols.
    fn trackSymbolUsage(node: *Node, imported_symbols: *std.StringHashMap(bool), declared_symbols: *std.StringHashMap(struct { used: bool, node: *Node })) !void {
        // Check if this node is an identifier that matches a symbol
        if (node.kind.base == .Identifier or
            node.kind.base == .TypeIdentifier)
        {
            // Check if it matches an imported symbol
            if (imported_symbols.getPtr(node.name)) |used_ptr| {
                // Mark the symbol as used
                used_ptr.* = true;
            }

            // Check if it matches a declared symbol
            if (declared_symbols.getPtr(node.name)) |entry| {
                // Mark the symbol as used
                entry.used = true;
            }
        }

        // Recursively check all children
        for (node.children.items) |child| {
            try trackSymbolUsage(child, imported_symbols, declared_symbols);
        }
    }

    pub fn sortProgramImports(self: MergeRules, program: *Node) !void {
        var imports = std.ArrayList(*Node).init(program.children.allocator);
        defer imports.deinit();

        // Collect all import declarations
        var i: usize = 0;
        while (i < program.children.items.len) {
            const child = program.children.items[i];
            if (child.kind.base == .ImportDecl) {
                try imports.append(child);
                _ = program.children.orderedRemove(i);
            } else {
                i += 1;
            }
        }

        // If eliminate_dead_code is enabled, remove unused imports
        if (self.eliminate_dead_code) {
            try self.eliminateDeadCode(program, &imports);
        }

        // If optimize_import_paths is enabled, optimize all import paths
        if (self.optimize_import_paths) {
            for (imports.items) |import_node| {
                const source_path = import_node.getSourcePath() orelse continue;

                // Optimize the import path
                const optimized_path = try self.optimizeImportPath(program.children.allocator, source_path);
                defer program.children.allocator.free(optimized_path);

                // Update the import node's value with the optimized path
                if (!std.mem.eql(u8, source_path, optimized_path)) {
                    if (import_node.value) |old_value| {
                        program.children.allocator.free(old_value);
                    }
                    import_node.value = try program.children.allocator.dupe(u8, optimized_path);
                }
            }
        }

        // If remove_redundancies is enabled, group imports by source path
        if (self.remove_redundancies) {
            var unique_imports = std.StringHashMap(*Node).init(program.children.allocator);
            defer unique_imports.deinit();

            // Group imports by source path
            for (imports.items) |import_node| {
                const source_path = import_node.getSourcePath() orelse continue;

                // Check if we already have an import from this source
                const result = try unique_imports.getOrPut(source_path);

                if (result.found_existing) {
                    // Merge this import with the existing one by combining their imported symbols
                    const existing_import = result.value_ptr.*;
                    _ = try existing_import.mergeImportedSymbols(import_node);
                } else {
                    // This is the first import from this source
                    result.value_ptr.* = import_node;
                }
            }

            // Clear the imports list and add only the unique imports
            imports.clearRetainingCapacity();
            var it = unique_imports.valueIterator();
            while (it.next()) |import_node| {
                try imports.append(import_node.*);
            }
        }

        // Group imports by scope
        var built_in_imports = std.ArrayList(*Node).init(program.children.allocator);
        defer built_in_imports.deinit();

        var external_imports = std.ArrayList(*Node).init(program.children.allocator);
        defer external_imports.deinit();

        var internal_imports = std.ArrayList(*Node).init(program.children.allocator);
        defer internal_imports.deinit();

        for (imports.items) |import_node| {
            const source_path = import_node.getSourcePath() orelse continue;
            const scope = getImportScope(source_path);

            switch (scope) {
                .BuiltIn => try built_in_imports.append(import_node),
                .External => try external_imports.append(import_node),
                .Internal => try internal_imports.append(import_node),
            }
        }

        // Sort each group by source path
        const sortFn = struct {
            fn lessThan(_: void, a: *Node, b: *Node) bool {
                const a_path = a.getSourcePath() orelse return false;
                const b_path = b.getSourcePath() orelse return false;
                return std.mem.lessThan(u8, a_path, b_path);
            }
        }.lessThan;

        std.sort.sort(*Node, built_in_imports.items, {}, sortFn);
        std.sort.sort(*Node, external_imports.items, {}, sortFn);
        std.sort.sort(*Node, internal_imports.items, {}, sortFn);

        // Clear the imports list
        imports.clearRetainingCapacity();

        // Add imports back in order: built-in, external, internal
        try imports.appendSlice(built_in_imports.items);

        // Add a newline between groups if there are items in both groups
        if (built_in_imports.items.len > 0 and external_imports.items.len > 0) {
            // Create a blank line node
            var blank_line = try Node.init(program.children.allocator, "", .{ .base = .Comment, .custom_kind = null, .source = null });
            blank_line.value = "\n";
            try imports.append(blank_line);
        }

        try imports.appendSlice(external_imports.items);

        // Add a newline between groups if there are items in both groups
        if (external_imports.items.len > 0 and internal_imports.items.len > 0) {
            // Create a blank line node
            var blank_line = try Node.init(program.children.allocator, "", .{ .base = .Comment, .custom_kind = null, .source = null });
            blank_line.value = "\n";
            try imports.append(blank_line);
        }

        try imports.appendSlice(internal_imports.items);

        // Add sorted imports back to the program
        try program.children.insertSlice(0, imports.items);
    }
};
