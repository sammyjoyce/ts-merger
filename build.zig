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
        enable_watcher: bool,
    },
) !*std.Build.Step {
    // This step is the global container for all tests.
    const test_step = b.step("test", "Run all tests");

    // Create modules needed for tests
    const bindings_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/bindings/mod.zig" },
        .imports = &.{
            .{ .name = "tree_sitter", .module = options.tree_sitter },
            .{ .name = "tree_sitter_typescript", .module = options.tree_sitter_typescript },
        },
    });

    const ast_types_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/core/ast/ast_types.zig" },
        .imports = &.{.{ .name = "tree_sitter", .module = options.tree_sitter }},
    });

    const parser_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/parser/mod.zig" },
        .imports = &.{
            .{ .name = "bindings", .module = bindings_module },
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

    // Define the test configuration type
    const TestConfig = struct {
        name: []const u8,
        path: []const u8,
        modules: []const struct { name: []const u8, module: *std.Build.Module },
        needs_cpp: bool,
    };

    // Create build options module for tests
    const test_options = b.addOptions();
    test_options.addOption(bool, "enable_watcher", options.enable_watcher);
    const build_options_module = test_options.createModule();

    // Add tests from source files
    const source_tests = [_]TestConfig{
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
    } ++ if (options.enable_watcher) [_]TestConfig{
        .{
            .name = "watcher",
            .path = "src/watcher/mod.zig",
            .modules = &.{
                .{ .name = "build_options", .module = build_options_module },
            },
            .needs_cpp = true,
        },
    } else [_]TestConfig{};

    // Configure and add each test
    for (source_tests) |test_info| {
        const test_exe = b.addTest(.{
            .name = b.fmt("{s}_test", .{test_info.name}),
            .root_source_file = .{ .cwd_relative = test_info.path },
            .target = target,
            .optimize = optimize,
        });

        // Add module imports
        for (test_info.modules) |mod| {
            test_exe.root_module.addImport(mod.name, mod.module);
        }

        // Link required libraries
        test_exe.linkLibrary(options.tree_sitter_lib);
        if (test_info.needs_cpp) {
            test_exe.linkLibrary(options.tree_sitter_typescript_lib);
        }
        test_exe.linkLibC();
        test_exe.linkLibCpp();

        // Conditionally link libxev for watcher tests
        if (options.enable_watcher and std.mem.eql(u8, test_info.name, "watcher")) {
            const libxev_dep = b.dependency("libxev", .{});
            test_exe.linkLibrary(libxev_dep.artifact("xev"));
            test_exe.root_module.addImport("libxev", libxev_dep.module("xev"));
        }

        // Add include paths for tree-sitter
        test_exe.addIncludePath(.{ .cwd_relative = "pkg/tree-sitter/lib/include" });
        test_exe.addIncludePath(.{ .cwd_relative = "pkg/tree-sitter-typescript/typescript/src" });
        test_exe.addIncludePath(.{ .cwd_relative = "pkg/tree-sitter-typescript/tsx/src" });

        // Add object files
        test_exe.addObjectFile(.{ .cwd_relative = "pkg/tree-sitter/lib/src/lib.c" });
        test_exe.addObjectFile(.{ .cwd_relative = "pkg/tree-sitter-typescript/typescript/src/parser.c" });
        test_exe.addObjectFile(.{ .cwd_relative = "pkg/tree-sitter-typescript/typescript/src/scanner.c" });

        test_step.dependOn(&b.addRunArtifact(test_exe).step);
    }

    return test_step;
}

/// Main build function (Zig 0.14.0 style)
fn addTreeSitterGrammar(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    mode: std.builtin.OptimizeMode,
    base_path: []const u8,
    language_name: []const u8,
) !*std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = b.fmt("tree-sitter-{s}", .{language_name}),
        .target = target,
        .optimize = mode,
    });

    const src_dir = try std.fs.path.join(b.allocator, &.{ base_path, "src" });
    defer b.allocator.free(src_dir);

    const parser_c = try std.fs.path.join(b.allocator, &.{ src_dir, "parser.c" });
    defer b.allocator.free(parser_c);

    const scanner_c = try std.fs.path.join(b.allocator, &.{ src_dir, "scanner.c" });
    defer b.allocator.free(scanner_c);

    lib.addCSourceFiles(.{
        .files = &.{ parser_c, scanner_c },
        .flags = &.{ "-std=c99", "-fPIC", "-D_GNU_SOURCE" },
    });

    lib.linkLibC();
    lib.addIncludePath(.{ .cwd_relative = "pkg/tree-sitter/lib/include" });
    lib.linkLibrary(b.dependency("tree-sitter", .{}).artifact("tree-sitter"));
    lib.installHeadersDirectory(.{ .cwd_relative = src_dir }, "include", .{});

    return lib;
}

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

    // Define enable_watcher as a build option with a default value of false
    const enable_watcher = b.option(bool, "enable-watcher", "Enable file watcher functionality") orelse false;

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

    const ts_lib_c = try std.fs.path.join(b.allocator, &.{ tree_sitter_path, "lib", "src", "lib.c" });
    defer b.allocator.free(ts_lib_c);

    const ts_parser_c = try std.fs.path.join(b.allocator, &.{ tree_sitter_ts_path, "typescript", "src", "parser.c" });
    defer b.allocator.free(ts_parser_c);

    const ts_scanner_c = try std.fs.path.join(b.allocator, &.{ tree_sitter_ts_path, "typescript", "src", "scanner.c" });
    defer b.allocator.free(ts_scanner_c);

    tree_sitter.addCSourceFiles(.{
        .files = &.{ts_lib_c},
        .flags = &.{ "-std=c99", "-fPIC", "-D_GNU_SOURCE" },
    });
    tree_sitter.installHeadersDirectory(.{ .cwd_relative = tree_sitter_path }, "include/tree_sitter", .{});
    tree_sitter.addIncludePath(.{ .cwd_relative = tree_sitter_main_include });

    // Build the tree-sitter-typescript and tree-sitter-tsx libraries using the helper function
    const ts_path = try std.fs.path.join(b.allocator, &.{ tree_sitter_ts_path, "typescript" });
    defer b.allocator.free(ts_path);
    const tree_sitter_typescript = try addTreeSitterGrammar(b, target, mode, ts_path, "typescript");
    tree_sitter_typescript.linkLibrary(tree_sitter);
    tree_sitter_typescript.linkLibCpp();

    const tsx_path = try std.fs.path.join(b.allocator, &.{ tree_sitter_ts_path, "tsx" });
    defer b.allocator.free(tsx_path);
    const tree_sitter_tsx = try addTreeSitterGrammar(b, target, mode, tsx_path, "tsx");
    tree_sitter_tsx.linkLibrary(tree_sitter);
    tree_sitter_tsx.linkLibrary(tree_sitter_typescript);

    // Add grammar generation step
    const gen = b.addExecutable(.{
        .name = "grammar_gen",
        .root_source_file = .{ .cwd_relative = "src/tools/grammar_gen.zig" },
        .target = target,
        .optimize = mode,
    });
    gen.addIncludePath(.{ .cwd_relative = tree_sitter_main_include });
    gen.linkLibrary(tree_sitter);
    gen.linkLibrary(tree_sitter_typescript);
    gen.linkLibrary(tree_sitter_tsx);
    gen.linkLibC();

    // Create generated directory
    const mkdir = b.addSystemCommand(&.{ "mkdir", "-p", "src/bindings/generated" });

    // Path components for node types files
    const ts_node_types_components = &.{ tree_sitter_ts_path, "typescript", "src", "node-types.json" };
    const ts_node_types = try std.fs.path.join(b.allocator, ts_node_types_components);

    const tsx_node_types_components = &.{ tree_sitter_ts_path, "tsx", "src", "node-types.json" };
    const tsx_node_types = try std.fs.path.join(b.allocator, tsx_node_types_components);

    comptime const grammar_defs = .{
        .{
            .name = "typescript",
            .node_types_path = ts_node_types,
            .output_path = "src/bindings/generated/typescript.zig",
        },
        .{
            .name = "tsx",
            .node_types_path = tsx_node_types,
            .output_path = "src/bindings/generated/tsx.zig",
        },
    };

    // Add generation step with proper dependencies
    const gen_step = b.step("generate", "Generate parser bindings");

    inline for (grammar_defs) |def| {
        const gen_cmd = b.addRunArtifact(gen);
        gen_cmd.step.dependOn(&mkdir.step);
        gen_cmd.addArgs(&.{
            "--language",   def.name,
            "--output",     def.output_path,
            "--node-types", def.node_types_path,
        });
        gen_step.dependOn(&gen_cmd.step);
    }

    // Create modules for the final executable
    const tree_sitter_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/bindings/tree_sitter.zig" },
    });

    const tree_sitter_typescript_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/bindings/generated/typescript.zig" },
        .imports = &.{.{ .name = "tree_sitter", .module = tree_sitter_module }},
    });

    // Create the main executable
    const clap_dep = b.dependency("clap", .{});
    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = mode,
    });

    // Add build options
    const exe_options = b.addOptions();
    exe_options.addOption(bool, "enable_watcher", enable_watcher);
    exe.root_module.addImport("build_options", exe_options.createModule());

    exe.root_module.addImport("clap", clap_dep.module("clap"));
    exe.addIncludePath(.{ .cwd_relative = "src" });
    exe.linkLibC();
    exe.linkLibrary(tree_sitter);
    exe.linkLibrary(tree_sitter_typescript);
    exe.addObjectFile(.{ .cwd_relative = ts_lib_c });
    exe.addObjectFile(.{ .cwd_relative = ts_parser_c });
    exe.addObjectFile(.{ .cwd_relative = ts_scanner_c });

    // Conditionally link libxev if watcher is enabled
    if (enable_watcher) {
        const libxev_dep = b.dependency("libxev", .{});
        exe.linkLibrary(libxev_dep.artifact("xev"));
        exe.root_module.addImport("libxev", libxev_dep.module("xev"));
    }
    // exe.addLibraryPath(.{ .cwd_relative = "/usr/lib" });

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
            .enable_watcher = enable_watcher,
        },
    );

    // Ensure main executable and tests depend on generation
    exe.step.dependOn(gen_step);
    test_step.dependOn(gen_step);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
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
