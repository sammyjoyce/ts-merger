const std = @import("std");
const cli = @import("../commands/cli.zig");
const ast_types = @import("../core/ast/ast_types.zig");

const flow = @import("../core/flow.zig");
const Project = @import("../project.zig").Project;
const Logger = @import("../utils/log.zig").Logger;
const ProgressReporter = @import("../utils/progress.zig").ProgressReporter;

const AnalyzeError = error{
    NoSourceFiles,
    ParserError,
    AnalyzeError,
    OutOfMemory,
    InvalidSyntax,
    ParseFailed,
    InvalidRootNode,
    ParsingFailed,
    LanguageVersionMismatch,
    ParserCreationFailed,
    InvalidRange,
    QueryCreationFailed,
    InvalidCaptureId,
    InvalidStringId,
    InvalidPatternIndex,
    UnsupportedFeature,
    CyclicDependency,
    Unseekable,
    LanguageLoadFailed,
    LanguageSetFailed,
    InvalidArguments,
} || std.fs.File.OpenError || std.fs.File.ReadError;

pub fn execute(allocator: std.mem.Allocator, config: *const cli.Config) AnalyzeError!void {
    const logger = Logger.scoped(.Info, "analyze");
    logger.info("Starting analyze command...", .{});

    // Validate input
    if (config.source_paths.len == 0) {
        Logger.scoped(.Error, "analyze").err("No source files specified", .{});
        return error.NoSourceFiles;
    }

    const source_files = config.source_paths;

    // Validate file extensions
    for (source_files) |file| {
        if (!std.mem.endsWith(u8, file, ".ts")) {
            Logger.scoped(.Error, "analyze").err("Source file '{s}' is not a TypeScript file", .{file});
            return error.InvalidArguments;
        }
    }

    logger.info("Source files:", .{});
    for (source_files) |file| {
        logger.info("  - {s}", .{file});
    }

    // Calculate total steps for progress reporting
    // 1 step for initialization, 1 step per source file, 1 step for analysis
    const total_steps = 2 + source_files.len;
    var progress = try ProgressReporter.init(allocator, total_steps, "Analyze", .Info, true);
    defer progress.deinit();

    // Step 1: Initialize parser and project
    progress.update(1, "Initializing parser and project");
    var lang_registry = try @import("../bindings/language.zig").LanguageRegistry.init(allocator);
    defer lang_registry.deinit();

    // Register languages here
    try lang_registry.register(.{
        .name = "typescript",
        .extensions = &[_][]const u8{"ts"},
        .parser_create = &@import("../bindings/tree_sitter_typescript.zig").TypeScriptParser.init,
        .node_types = .{
            .program = "program",
            .interface_decl = "interface_declaration",
            .class_decl = "class_declaration",
            .function_decl = "function_declaration",
            .variable_decl = "variable_declaration",
            .import_decl = "import_statement",
            .export_decl = "export_statement",
        },
        .detect_content = struct {
            fn detect(src: []const u8) bool {
                return std.mem.indexOf(u8, src, "interface ") != null or
                    std.mem.indexOf(u8, src, "class ") != null;
            }
        }.detect,
    });

    try lang_registry.register(.{
        .name = "tsx",
        .extensions = &[_][]const u8{"tsx"},
        .parser_create = &@import("../bindings/language.zig").LanguageParser.init,
        .node_types = .{
            .program = "program",
            .interface_decl = "interface_declaration",
            .class_decl = "class_declaration",
            .function_decl = "function_declaration",
            .variable_decl = "variable_declaration",
            .import_decl = "import_statement",
            .export_decl = "export_statement",
            .jsx_element = "jsx_element",
            .jsx_opening_element = "jsx_opening_element",
            .jsx_closing_element = "jsx_closing_element",
            .jsx_self_closing_element = "jsx_self_closing_element",
            .jsx_attribute = "jsx_attribute",
        },
        .detect_content = struct {
            fn detect(src: []const u8) bool {
                return std.mem.indexOf(u8, src, "interface ") != null or
                    std.mem.indexOf(u8, src, "class ") != null;
            }
        }.detect,
    });

    var project_instance = try Project.init(allocator, &lang_registry);
    defer project_instance.deinit();

    // Process source files
    var warnings: usize = 0;
    var errors: usize = 0;

    for (0..source_files.len) |i| {
        const file = source_files[i];
        const step = 2 + i; // Step 2 is the first file
        const message = std.fmt.allocPrint(allocator, "Analyzing file: {s}", .{file}) catch "Analyzing file";
        defer if (std.mem.indexOf(u8, message, "Analyzing file:") != null) allocator.free(message);

        progress.update(step, message);

        // Try to parse the file and report any errors
        project_instance.parseFile(file) catch |err| {
            Logger.scoped(.Error, "analyze").err("Error parsing file '{s}': {s}", .{ file, @errorName(err) });
            errors += 1;
            continue;
        };

        // Check for warnings in the file
        const file_warnings = analyzeFile(allocator, &project_instance, file);
        warnings += file_warnings;
    }

    // Final analysis step
    progress.update(total_steps - 1, "Performing final analysis");

    // Check for circular dependencies
    if (checkCircularDependencies(allocator, &project_instance)) |circular_deps| {
        defer allocator.free(circular_deps);
        if (circular_deps.len > 0) {
            Logger.scoped(.Warning, "analyze").warn("Detected circular dependencies: {s}", .{circular_deps});
            warnings += 1;
        }
    } else |_| {
        // Error checking circular dependencies
        Logger.scoped(.Error, "analyze").err("Error checking for circular dependencies", .{});
        errors += 1;
    }

    // Mark progress as complete
    if (errors > 0) {
        progress.complete(std.fmt.allocPrint(allocator, "Analysis completed with {d} errors and {d} warnings", .{ errors, warnings }) catch "Analysis completed with errors");
        Logger.scoped(.Error, "analyze").err("Analysis completed with {d} errors and {d} warnings", .{ errors, warnings });
    } else if (warnings > 0) {
        progress.complete(std.fmt.allocPrint(allocator, "Analysis completed with {d} warnings", .{warnings}) catch "Analysis completed with warnings");
        Logger.scoped(.Warning, "analyze").warn("Analysis completed with {d} warnings", .{warnings});
    } else {
        progress.complete("Analysis completed successfully with no issues!");
        Logger.scoped(.Info, "analyze").info("Analysis completed successfully with no issues!", .{});
    }
}

fn analyzeFile(allocator: std.mem.Allocator, project: *Project, file_path: []const u8) usize {
    const logger = Logger.scoped(.Info, "analyze_file");
    var warnings: usize = 0;

    // Get the AST node for this file
    var file_node: ?*ast_types.Node = null;
    for (project.owned_nodes.items) |node| {
        if (node.kind.source) |source| {
            if (std.mem.eql(u8, source, file_path)) {
                file_node = node;
                break;
            }
        }
    }

    if (file_node == null) {
        logger.warn("Could not find AST node for file: {s}", .{file_path});
        return 0;
    }

    // Check for syntax errors
    // If the node has a kind of "unknown", it might indicate a syntax error
    if (file_node.?.kind.base == .unknown) {
        logger.warn("Possible syntax error in file: {s}", .{file_path});
        warnings += 1;
    }

    // Check for empty interfaces or classes
    for (file_node.?.children.items) |child| {
        if (child.kind.base == .interface_declaration or child.kind.base == .class_declaration) {
            if (child.children.items.len == 0) {
                logger.warn("Empty {s} found in {s}: {s}", .{
                    @tagName(child.kind.base),
                    file_path,
                    child.name,
                });
                warnings += 1;
            }
        }
    }

    // Check for unused imports
    var imports = std.ArrayList(*ast_types.Node).init(allocator);
    defer imports.deinit();

    // Find all import statements
    for (file_node.?.children.items) |child| {
        if (child.kind.base == .ImportDecl) {
            imports.append(child) catch continue;
        }
    }

    // Check if imports are used
    for (imports.items) |import_node| {
        var is_used = false;

        // Simple check: see if the import name appears in any other node's value
        const import_name = import_node.name;
        for (file_node.?.children.items) |child| {
            if (child == import_node) continue;

            if (child.value) |value| {
                if (std.mem.indexOf(u8, value, import_name) != null) {
                    is_used = true;
                    break;
                }
            }

            // Also check children's values
            for (child.children.items) |grandchild| {
                if (grandchild.value) |value| {
                    if (std.mem.indexOf(u8, value, import_name) != null) {
                        is_used = true;
                        break;
                    }
                }
            }

            if (is_used) break;
        }

        if (!is_used) {
            logger.warn("Unused import in {s}: {s}", .{ file_path, import_name });
            warnings += 1;
        }
    }

    // Check for circular dependencies within the file
    var local_flow = flow.Flow.init(allocator) catch |err| {
        logger.err("Failed to initialize flow analysis: {s}", .{@errorName(err)});
        return warnings;
    };
    defer local_flow.deinit();

    // Add all nodes from this file to the flow
    for (file_node.?.children.items) |child| {
        local_flow.nodes.append(child) catch continue;
    }

    // Check for circular dependencies
    if (local_flow.getTopologicalOrder()) |_| {
        // No circular dependencies
    } else |err| {
        if (err == error.CircularDependency) {
            logger.warn("Circular dependency detected in file: {s}", .{file_path});
            warnings += 1;
        }
    }

    return warnings;
}

fn checkCircularDependencies(allocator: std.mem.Allocator, project: *Project) ![]const u8 {
    const logger = Logger.scoped(.Info, "check_circular_deps");

    // Use the project's flow object to check for circular dependencies
    var result = std.ArrayList(u8).init(allocator);
    defer result.deinit();

    // Try to get topological order - if this fails with CircularDependency, we have a cycle
    project.flow.getTopologicalOrder() catch |err| {
        if (err == error.CircularDependency) {
            // Find the cycle
            for (project.flow.nodes.items) |node| {
                // For each node, check if it forms a cycle with any of its dependencies
                var visited = std.AutoHashMap(*ast_types.Node, void).init(allocator);
                defer visited.deinit();

                var stack = std.ArrayList(*ast_types.Node).init(allocator);
                defer stack.deinit();

                try stack.append(node);

                while (stack.popOrNull()) |current| {
                    if (visited.contains(current)) {
                        if (current == node) {
                            // We found a cycle
                            var cycle_path = std.ArrayList(u8).init(allocator);
                            defer cycle_path.deinit();

                            // Build the cycle path
                            try cycle_path.writer().print("{s}", .{node.name});

                            for (current.dependencies.items) |dep| {
                                if (hasDependencyPath(dep, node)) {
                                    try cycle_path.writer().print(" -> {s}", .{dep.name});

                                    // Find the path from dep back to node
                                    var path_stack = std.ArrayList(*ast_types.Node).init(allocator);
                                    defer path_stack.deinit();

                                    var path_visited = std.AutoHashMap(*ast_types.Node, void).init(allocator);
                                    defer path_visited.deinit();

                                    try path_stack.append(dep);

                                    while (path_stack.popOrNull()) |path_current| {
                                        if (path_visited.contains(path_current)) continue;
                                        try path_visited.put(path_current, {});

                                        if (path_current == node) {
                                            // We've completed the cycle
                                            break;
                                        }

                                        for (path_current.dependencies.items) |path_dep| {
                                            try path_stack.append(path_dep);
                                            try cycle_path.writer().print(" -> {s}", .{path_dep.name});
                                            if (path_dep == node) break;
                                        }
                                    }

                                    // We found a cycle, add it to the result
                                    if (result.items.len > 0) {
                                        try result.writer().print(", ", .{});
                                    }
                                    try result.writer().print("{s}", .{cycle_path.items});
                                    break;
                                }
                            }

                            // If we found a cycle, no need to check other nodes
                            if (result.items.len > 0) break;
                        }
                        continue;
                    }

                    try visited.put(current, {});

                    for (current.dependencies.items) |dep| {
                        try stack.append(dep);
                    }
                }

                // If we found a cycle, no need to check other nodes
                if (result.items.len > 0) break;
            }

            if (result.items.len == 0) {
                // We know there's a cycle, but couldn't find it with our algorithm
                // This could happen if the cycle is complex or involves nodes we didn't check
                logger.warn("Circular dependency detected, but couldn't identify the specific cycle", .{});
                try result.writer().print("Unknown circular dependency", .{});
            }
        } else {
            // Some other error occurred
            logger.err("Error checking for circular dependencies: {s}", .{@errorName(err)});
            return err;
        }
    };

    return result.toOwnedSlice();
}

// Helper function to check if there's a path from start to target
fn hasDependencyPath(start: *ast_types.Node, target: *ast_types.Node) bool {
    if (start == target) return true;

    for (start.dependencies.items) |dep| {
        if (hasDependencyPath(dep, target)) {
            return true;
        }
    }

    return false;
}
