const std = @import("std");
const Build = std.Build;

pub fn addTests(
    b: *Build,
    target: Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: struct {
        tree_sitter: *Build.Module,
        tree_sitter_typescript: *Build.Module,
        tree_sitter_lib: *std.Build.Step.Compile,
        tree_sitter_typescript_lib: *std.Build.Step.Compile,
    },
) !*Build.Step {
    // Create test step
    const test_step = b.step("test", "Run all tests");

    // Create modules for tests
    const ast_types_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/ast_types.zig" },
        .imports = &.{
            .{ .name = "tree_sitter", .module = options.tree_sitter },
        },
    });

    const parser_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/parser.zig" },
        .imports = &.{
            .{ .name = "tree_sitter", .module = options.tree_sitter },
            .{ .name = "tree_sitter_typescript", .module = options.tree_sitter_typescript },
            .{ .name = "ast_types", .module = ast_types_module },
        },
    });

    const flow_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/flow.zig" },
        .imports = &.{
            .{ .name = "ast_types", .module = ast_types_module },
        },
    });

    const cli_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/cli.zig" },
        .imports = &.{},
    });

    const types_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/types.zig" },
        .imports = &.{},
    });

    const watcher_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/watcher/mod.zig" },
        .imports = &.{},
    });

    // Tree-sitter tests
    const tree_sitter_tests = b.addTest(.{
        .name = "tree_sitter_test",
        .root_source_file = .{ .cwd_relative = "tests/tree_sitter_test.zig" },
        .target = target,
        .optimize = optimize,
    });

    tree_sitter_tests.root_module.addImport("tree_sitter", options.tree_sitter);
    tree_sitter_tests.linkLibrary(options.tree_sitter_lib);
    test_step.dependOn(&tree_sitter_tests.step);

    // Parser tests
    const parser_tests = b.addTest(.{
        .name = "parser_test",
        .root_source_file = .{ .cwd_relative = "tests/parser_test.zig" },
        .target = target,
        .optimize = optimize,
    });

    parser_tests.root_module.addImport("tree_sitter", options.tree_sitter);
    parser_tests.root_module.addImport("tree_sitter_typescript", options.tree_sitter_typescript);
    parser_tests.root_module.addImport("ast_types", ast_types_module);
    parser_tests.root_module.addImport("parser", parser_module);
    parser_tests.linkLibrary(options.tree_sitter_lib);
    parser_tests.linkLibrary(options.tree_sitter_typescript_lib);
    test_step.dependOn(&parser_tests.step);

    // Flow tests
    const flow_tests = b.addTest(.{
        .name = "flow_test",
        .root_source_file = .{ .cwd_relative = "tests/flow_test.zig" },
        .target = target,
        .optimize = optimize,
    });

    flow_tests.root_module.addImport("ast_types", ast_types_module);
    flow_tests.root_module.addImport("flow", flow_module);
    flow_tests.root_module.addImport("parser", parser_module);
    test_step.dependOn(&flow_tests.step);

    // CLI tests
    const cli_tests = b.addTest(.{
        .name = "cli_test",
        .root_source_file = .{ .cwd_relative = "tests/cli_test.zig" },
        .target = target,
        .optimize = optimize,
    });

    cli_tests.root_module.addImport("cli", cli_module);
    test_step.dependOn(&cli_tests.step);

    // Types tests
    const types_tests = b.addTest(.{
        .name = "types_test",
        .root_source_file = .{ .cwd_relative = "tests/types_test.zig" },
        .target = target,
        .optimize = optimize,
    });

    types_tests.root_module.addImport("types", types_module);
    test_step.dependOn(&types_tests.step);

    // AST types tests
    const ast_types_tests = b.addTest(.{
        .name = "ast_types_test",
        .root_source_file = .{ .cwd_relative = "tests/ast_types_test.zig" },
        .target = target,
        .optimize = optimize,
    });

    ast_types_tests.root_module.addImport("ast_types", ast_types_module);
    test_step.dependOn(&ast_types_tests.step);

    // Watcher tests
    const watcher_tests = b.addTest(.{
        .name = "watcher_test",
        .root_source_file = .{ .cwd_relative = "tests/watcher_test.zig" },
        .target = target,
        .optimize = optimize,
    });

    watcher_tests.root_module.addImport("watcher", watcher_module);
    test_step.dependOn(&watcher_tests.step);

    // Add parser tests
    const parser_test = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/parser.zig" },
        .target = target,
        .optimize = optimize,
    });
    parser_test.root_module.addImport("tree_sitter", options.tree_sitter);
    parser_test.root_module.addImport("tree_sitter_typescript", options.tree_sitter_typescript);
    parser_test.linkLibrary(options.tree_sitter_lib);
    parser_test.linkLibrary(options.tree_sitter_typescript_lib);
    parser_test.linkLibC();

    // Add flow tests
    const flow_test = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/flow.zig" },
        .target = target,
        .optimize = optimize,
    });
    flow_test.root_module.addImport("tree_sitter", options.tree_sitter);
    flow_test.root_module.addImport("tree_sitter_typescript", options.tree_sitter_typescript);
    flow_test.linkLibrary(options.tree_sitter_lib);
    flow_test.linkLibrary(options.tree_sitter_typescript_lib);
    flow_test.linkLibC();

    // Add watcher tests
    const watcher_test = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/watcher/mod.zig" },
        .target = target,
        .optimize = optimize,
    });
    watcher_test.linkLibC();

    // Add test artifacts to test step
    test_step.dependOn(&b.addRunArtifact(parser_test).step);
    test_step.dependOn(&b.addRunArtifact(flow_test).step);
    test_step.dependOn(&b.addRunArtifact(watcher_test).step);

    return test_step;
}
