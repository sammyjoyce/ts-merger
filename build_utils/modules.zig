const std = @import("std");

pub fn createModules(
    b: *std.Build,
    options: struct {
        tree_sitter: *std.Build.Module,
        tree_sitter_typescript: *std.Build.Module,
    },
) struct {
    watcher: *std.Build.Module,
    parser: *std.Build.Module,
    flow: *std.Build.Module,
    ast_types: *std.Build.Module,
} {
    const watcher_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/watcher/mod.zig" },
    });

    const ast_types_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/ast_types.zig" },
        .imports = &.{
            .{ .name = "tree_sitter", .module = options.tree_sitter },
        },
    });

    const parser_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/parser.zig" },
        .imports = &.{
            .{ .name = "tree_sitter", .module = options.tree_sitter },
            .{ .name = "tree_sitter_typescript", .module = options.tree_sitter_typescript },
            .{ .name = "ast_types", .module = ast_types_mod },
        },
    });

    const flow_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/flow.zig" },
        .imports = &.{
            .{ .name = "ast_types", .module = ast_types_mod },
        },
    });

    return .{
        .watcher = watcher_mod,
        .parser = parser_mod,
        .flow = flow_mod,
        .ast_types = ast_types_mod,
    };
}
