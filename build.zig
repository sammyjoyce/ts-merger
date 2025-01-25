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

/// Add all unit tests from source files, returning the test step.
fn addTests(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: struct {
        tree_sitter: *std.Build.Module,
        tree_sitter_typescript: *std.Build.Module,
        tree_sitter_lib: *std.Build.Step.Compile,
        tree_sitter_typescript_lib: *std.Build.Step.Compile,
    },
) !*std.Build.Step {
    // This step is the global container for all tests.
    const test_step = b.step("test", "Run all tests");

    // Add libxev dependency
    const libxev_dep = b.dependency("libxev", .{});

    // Create patch step using dependency path
    const patch_step = b.addSystemCommand(&[_][]const u8{
        "patch",
        "-p1",
        "--directory",
        libxev_dep.path("").getPath(b),
        "--input",
        "libxev.patch",
    });

    // Make libxev module depend on the patch step
    const libxev_module = libxev_dep.module("libxev");
    const libxev_compile = libxev_dep.artifact("xev");
    libxev_compile.step.dependOn(&patch_step.step);

    // Create modules needed for tests
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

    // Add tests from source files
    const source_tests = [_]struct {
        name: []const u8,
        path: []const u8,
        modules: []const struct { name: []const u8, module: *std.Build.Module },
        needs_cpp: bool,
    }{
        .{
            .name = "tree_sitter",
            .path = "src/bindings/tree_sitter.zig",
            .modules = &.{.{ .name = "tree_sitter", .module = options.tree_sitter }},
            .needs_cpp = false,
        },
        .{
            .name = "parser",
            .path = "src/parser/mod.zig",
            .modules = &.{
                .{ .name = "tree_sitter", .module = options.tree_sitter },
                .{ .name = "tree_sitter_typescript", .module = options.tree_sitter_typescript },
                .{ .name = "ast_types", .module = ast_types_module },
            },
            .needs_cpp = true,
        },
        .{
            .name = "flow",
            .path = "src/core/flow.zig",
            .modules = &.{
                .{ .name = "tree_sitter", .module = options.tree_sitter },
                .{ .name = "tree_sitter_typescript", .module = options.tree_sitter_typescript },
                .{ .name = "ast_types", .module = ast_types_module },
            },
            .needs_cpp = true,
        },
        .{
            .name = "cli",
            .path = "src/commands/cli.zig",
            .modules = &.{
                .{ .name = "parser", .module = parser_module },
                .{ .name = "flow", .module = flow_module },
            },
            .needs_cpp = false,
        },
        .{
            .name = "watcher",
            .path = "src/watcher/mod.zig",
            .modules = &.{
                .{ .name = "libxev", .module = libxev_module },
            },
            .needs_cpp = true,
        },
    };

    // Configure and add each test
    for (source_tests) |test_info| {
        const test_exe = b.addTest(.{ .name = b.fmt("{s}_test", .{test_info.name}), .root_source_file = .{ .cwd_relative = test_info.path }, .target = target, .optimize = optimize });

        // Add module imports
        for (test_info.modules) |mod| {
            test_exe.root_module.addImport(mod.name, mod.module);
        }

        // Link required libraries
        test_exe.linkLibrary(options.tree_sitter_lib);
        if (test_info.needs_cpp) {
            test_exe.linkLibrary(options.tree_sitter_typescript_lib);
            test_exe.linkLibCpp();
        }
        test_exe.linkLibC();

        test_step.dependOn(&b.addRunArtifact(test_exe).step);
    }

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
    // Only clone if directory doesn't exist
    if (!dirExists(b.allocator, tree_sitter_path)) {
        const git_clone_ts = b.addSystemCommand(&.{ "git", "clone", "--depth=1", "https://github.com/tree-sitter/tree-sitter.git", tree_sitter_path });
        tree_sitter.step.dependOn(&git_clone_ts.step);
    }

    const ts_lib_c = try std.fs.path.join(b.allocator, &.{ tree_sitter_path, "lib", "src", "lib.c" });
    defer b.allocator.free(ts_lib_c);

    tree_sitter.addCSourceFile(.{
        .file = .{ .cwd_relative = ts_lib_c },
        .flags = &.{ "-std=c99", "-fPIC" },
    });
    tree_sitter.addIncludePath(.{ .cwd_relative = tree_sitter_main_include });

    // Build the tree-sitter-typescript library
    const tree_sitter_typescript = b.addStaticLibrary(.{
        .name = "tree-sitter-typescript",
        .target = target,
        .optimize = mode,
    });

    // Only clone if directory doesn't exist
    if (!dirExists(b.allocator, tree_sitter_ts_path)) {
        const git_clone_ts_typescript = b.addSystemCommand(&.{ "git", "clone", "--depth=1", "https://github.com/tree-sitter/tree-sitter-typescript.git", tree_sitter_ts_path });
        tree_sitter_typescript.step.dependOn(&git_clone_ts_typescript.step);
    }

    const ts_parser_c = try std.fs.path.join(b.allocator, &.{ tree_sitter_ts_path, "typescript", "src", "parser.c" });
    defer b.allocator.free(ts_parser_c);

    const ts_scanner_cc = try std.fs.path.join(b.allocator, &.{ tree_sitter_ts_path, "typescript", "src", "scanner.c" });
    defer b.allocator.free(ts_scanner_cc);

    const ts_include_path = try std.fs.path.join(b.allocator, &.{ tree_sitter_ts_path, "typescript", "src" });
    defer b.allocator.free(ts_include_path);

    tree_sitter_typescript.addCSourceFile(.{
        .file = .{ .cwd_relative = ts_parser_c },
        .flags = &.{ "-std=c99", "-fPIC" },
    });
    tree_sitter_typescript.addCSourceFile(.{
        .file = .{ .cwd_relative = ts_scanner_cc },
        .flags = &.{ "-std=c99", "-fPIC" },
    });
    tree_sitter_typescript.addIncludePath(.{ .cwd_relative = ts_include_path });
    tree_sitter_typescript.addIncludePath(.{ .cwd_relative = tree_sitter_main_include });
    tree_sitter_typescript.linkLibrary(tree_sitter);
    tree_sitter_typescript.linkLibCpp();

    // Create modules for the final executable
    const tree_sitter_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/bindings/tree_sitter.zig" },
    });
    const tree_sitter_typescript_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/bindings/tree_sitter_typescript.zig" },
    });

    // Create the main executable
    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/main.zig" } },
        .target = target,
        .optimize = mode,
    });
    exe.root_module.addImport("tree-sitter", tree_sitter_module);
    exe.root_module.addImport("tree-sitter-typescript", tree_sitter_typescript_module);
    exe.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "src" } });
    exe.linkLibC();
    exe.linkLibrary(tree_sitter);
    exe.linkLibrary(tree_sitter_typescript);
    exe.addObjectFile(.{ .cwd_relative = ts_lib_c });
    exe.addObjectFile(.{ .cwd_relative = ts_parser_c });
    exe.addObjectFile(.{ .cwd_relative = ts_scanner_cc });
    exe.linkLibCpp();
    exe.addLibraryPath(.{ .cwd_relative = "/usr/lib" });

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
    test_step.dependOn(&b.addRunArtifact(exe).step);
}

fn dirExists(allocator: std.mem.Allocator, path: []const u8) bool {
    // Normalize the path to handle both absolute and relative paths
    const real_path = std.fs.path.resolve(allocator, &.{path}) catch return false;
    defer allocator.free(real_path);

    // Try to open the directory
    var dir = std.fs.cwd().openDir(".", .{}) catch return false;
    defer dir.close();

    return true;
}
