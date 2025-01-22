const std = @import("std");

// ===========================================
// Single build.zig for ts-merger (Zig 0.14.0)
// ===========================================

fn validatePathComponent(comptime part: []const u8) void {
    // Disallow certain path characters
    if (std.mem.indexOfAny(u8, part, "\\:*?\"<>|") != null) {
        @compileError("Invalid path character in: " ++ part);
    }
}

/// Add all unit/integration tests, returning the step to run them.
fn addTests(
    b: *std.build.Builder,
    target: std.build.AvailableTarget,
    optimize: std.builtin.OptimizeMode,
    options: struct {
        tree_sitter: *std.build.Module,
        tree_sitter_typescript: *std.build.Module,
        tree_sitter_lib: *std.Build.Step.Compile,
        tree_sitter_typescript_lib: *std.Build.Step.Compile,
    },
) !*std.Build.Step {
    // This step is the global container for all tests.
    const test_step = b.step("test", "Run all tests");

    //
    // Example: some modules for the tests
    //
    const ast_types_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/core/ast/ast_types.zig" },
        .imports = &.{.{ .name = "tree_sitter", .module = options.tree_sitter }},
    });

    const parser_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/parser/mod.zig" },
        .imports = &.{
            .{ .name = "tree_sitter", .module = options.tree_sitter },
            .{ .name = "tree_sitter_typescript", .module = options.tree_sitter_typescript },
            .{ .name = "ast_types", .module = ast_types_module },
        },
    });

    const flow_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/core/flow.zig" },
        .imports = &.{
            .{ .name = "ast_types", .module = ast_types_module },
            .{ .name = "tree_sitter_typescript", .module = options.tree_sitter_typescript },
        },
    });

    // Example modules for CLI, types, watchers, etc. (only if needed)
    const cli_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/commands/cli.zig" },
        .imports = &.{},
    });

    const watcher_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/watcher/mod.zig" },
        .imports = &.{},
    });

    //
    // Now define the test executables themselves:
    //

    // Example: tree_sitter_test
    const tree_sitter_tests = b.addTest(.{
        .name = "tree_sitter_test",
        .root_source_file = .{ .cwd_relative = "tests/tree_sitter_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    tree_sitter_tests.root_module.addImport("tree_sitter", options.tree_sitter);
    tree_sitter_tests.linkLibrary(options.tree_sitter_lib);
    test_step.dependOn(&tree_sitter_tests.step);

    // parser_test
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
    parser_tests.linkLibCpp();
    test_step.dependOn(&parser_tests.step);

    // flow_test
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

    // cli_test
    const cli_tests = b.addTest(.{
        .name = "cli_test",
        .root_source_file = .{ .cwd_relative = "tests/cli_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    cli_tests.root_module.addImport("cli", cli_module);
    test_step.dependOn(&cli_tests.step);

    // watcher_test
    const watcher_tests = b.addTest(.{
        .name = "watcher_test",
        .root_source_file = .{ .cwd_relative = "tests/watcher_test.zig" },
        .target = target,
        .optimize = optimize,
    });
    watcher_tests.root_module.addImport("watcher", watcher_module);
    test_step.dependOn(&watcher_tests.step);

    //
    // Additional test executables that compile from source modules
    // (These can add object files, link libs, etc. as needed)
    //

    // Example: parser_test artifact from src/parser/mod.zig
    const parser_test = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/parser/mod.zig" },
        .target = target,
        .optimize = optimize,
    });
    parser_test.root_module.addImport("tree_sitter", options.tree_sitter);
    parser_test.root_module.addImport("tree_sitter_typescript", options.tree_sitter_typescript);
    parser_test.linkLibrary(options.tree_sitter_lib);
    parser_test.linkLibrary(options.tree_sitter_typescript_lib);
    parser_test.linkLibCpp();
    parser_test.linkLibC();
    parser_test.addLibraryPath(.{ .path = "/usr/lib" });
    test_step.dependOn(&b.addRunArtifact(parser_test).step);

    // Example: flow_test artifact from src/core/flow.zig
    const flow_test = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/core/flow.zig" },
        .target = target,
        .optimize = optimize,
    });
    flow_test.root_module.addImport("tree_sitter", options.tree_sitter);
    flow_test.root_module.addImport("tree_sitter_typescript", options.tree_sitter_typescript);
    flow_test.root_module.addImport("ast_types", ast_types_module);
    flow_test.linkLibrary(options.tree_sitter_lib);
    flow_test.linkLibrary(options.tree_sitter_typescript_lib);
    flow_test.addObjectFile(.{ .path = "pkg/tree-sitter/src/lib.c" });
    flow_test.addObjectFile(.{ .path = "pkg/tree-sitter-typescript/typescript/src/scanner.cc" });
    flow_test.addObjectFile(.{ .path = "pkg/tree-sitter-typescript/typescript/src/parser.c" });
    flow_test.linkLibCpp();
    flow_test.linkLibC();
    flow_test.addIncludePath(.{ .path = "pkg/tree-sitter/lib/include" });
    flow_test.addIncludePath(.{ .path = "pkg/tree-sitter-typescript/typescript/src" });
    flow_test.addLibraryPath(.{ .path = "/usr/lib" });
    test_step.dependOn(&b.addRunArtifact(flow_test).step);

    // Example: watcher_test artifact from src/watcher/mod.zig
    const watcher_test = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/watcher/mod.zig" },
        .target = target,
        .optimize = optimize,
    });
    watcher_test.linkLibC();
    watcher_test.linkLibCpp();
    test_step.dependOn(&b.addRunArtifact(watcher_test).step);

    return test_step;
}

/// Main build function (Zig 0.14.0 style)
pub fn build(b: *std.Build) !void {
    // Validate path components at compile-time
    comptime {
        validatePathComponent("pkg");
        validatePathComponent("tree-sitter");
        validatePathComponent("tree-sitter-typescript");
    }

    // Standard build options
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});
    const exe_name = b.option([]const u8, "name", "Name of the executable") orelse "fuze";

    //
    // Set up tree-sitter library + tree-sitter-typescript
    //

    const tree_sitter_path = "pkg/tree-sitter";
    const tree_sitter_ts_path = "pkg/tree-sitter-typescript";

    const tree_sitter_main_include = try std.fs.path.join(b.allocator, &.{ tree_sitter_path, "lib", "include" });
    defer b.allocator.free(tree_sitter_main_include);

    // Build the base tree-sitter library
    const tree_sitter = b.addStaticLibrary(.{
        .name = "tree-sitter",
        .target = target,
        .optimize = mode,
    });

    // Possibly clone the tree-sitter repo if absent
    const git_clone_ts = b.addSystemCommand(&.{ "git", "clone", "--depth=1", "https://github.com/tree-sitter/tree-sitter.git", tree_sitter_path });
    tree_sitter.step.dependOn(&git_clone_ts.step);

    const ts_lib_c = try std.fs.path.join(b.allocator, &.{ tree_sitter_path, "src", "lib.c" });
    defer b.allocator.free(ts_lib_c);

    tree_sitter.addCSourceFile(.{
        .file = .{ .path = ts_lib_c },
        .flags = &.{ "-std=c99", "-fPIC" },
    });
    tree_sitter.addIncludePath(.{ .path = tree_sitter_main_include });

    // Build the tree-sitter-typescript library
    const tree_sitter_typescript = b.addStaticLibrary(.{
        .name = "tree-sitter-typescript",
        .target = target,
        .optimize = mode,
    });

    const git_clone_ts_typescript = b.addSystemCommand(&.{ "git", "clone", "--depth=1", "https://github.com/tree-sitter/tree-sitter-typescript.git", tree_sitter_ts_path });
    tree_sitter_typescript.step.dependOn(&git_clone_ts_typescript.step);

    const ts_parser_c = try std.fs.path.join(b.allocator, &.{ tree_sitter_ts_path, "typescript", "src", "parser.c" });
    defer b.allocator.free(ts_parser_c);

    const ts_scanner_cc = try std.fs.path.join(b.allocator, &.{ tree_sitter_ts_path, "typescript", "src", "scanner.cc" });
    defer b.allocator.free(ts_scanner_cc);

    const ts_include_path = try std.fs.path.join(b.allocator, &.{ tree_sitter_ts_path, "typescript", "src" });
    defer b.allocator.free(ts_include_path);

    tree_sitter_typescript.addCSourceFile(.{
        .file = .{ .path = ts_parser_c },
        .flags = &.{ "-std=c99", "-fPIC" },
    });
    tree_sitter_typescript.addCSourceFile(.{
        .file = .{ .path = ts_scanner_cc },
        .flags = &.{ "-std=c++17", "-fPIC" },
    });
    tree_sitter_typescript.addIncludePath(.{ .path = ts_include_path });
    tree_sitter_typescript.addIncludePath(.{ .path = tree_sitter_main_include });
    tree_sitter_typescript.linkLibrary(tree_sitter);
    tree_sitter_typescript.linkLibCpp();

    // Create modules for the final executable
    const tree_sitter_module = b.createModule(.{
        .root_source_file = .{ .path = "src/bindings/tree_sitter.zig" },
    });
    const tree_sitter_typescript_module = b.createModule(.{
        .root_source_file = .{ .path = "src/bindings/tree_sitter_typescript.zig" },
    });

    // Create the main executable
    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/main.zig" } },
        .target = target,
        .optimize = mode,
    });
    exe.addModule("tree-sitter", tree_sitter_module);
    exe.addModule("tree-sitter-typescript", tree_sitter_typescript_module);
    exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "src" } });
    exe.linkLibC();
    exe.linkLibrary(tree_sitter);
    exe.linkLibrary(tree_sitter_typescript);
    exe.addObjectFile(.{ .path = ts_lib_c });
    exe.addObjectFile(.{ .path = ts_parser_c });
    exe.addObjectFile(.{ .path = ts_scanner_cc });
    exe.linkLibCpp();
    exe.addLibraryPath(.{ .path = "/usr/lib" }); // For macOS libc++.a

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    // Add tests from our integrated function
    const test_step = try addTests(
        b,
        target,
        mode,
        .{
            .tree_sitter = tree_sitter_module,
            .tree_sitter_typescript = tree_sitter_typescript_module,
            .tree_sitter_lib = tree_sitter,
            .tree_sitter_typescript_lib = tree_sitter_typescript,
        },
    );
    b.getStep("test", "Run unit tests").dependOn(test_step);
}
