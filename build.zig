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

    // Watcher functionality is removed
    const enable_watcher = false;

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
    } ++ if (enable_watcher) [_]TestConfig{
        .{
            .name = "watcher",
            .path = "src/watcher/mod.zig",
            .modules = &.{},
            .needs_cpp = true,
        },
    } else [_]TestConfig{};

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

    const ts_lib_c = try std.fs.path.join(b.allocator, &.{ tree_sitter_path, "lib", "src", "lib.c" });
    defer b.allocator.free(ts_lib_c);

    tree_sitter.addCSourceFiles(.{
        .files = &.{ts_lib_c},
        .flags = &.{ "-std=c99", "-fPIC", "-D_GNU_SOURCE" },
    });
    tree_sitter.installHeadersDirectory(.{ .cwd_relative = tree_sitter_path }, "include/tree_sitter", .{});
    tree_sitter.addIncludePath(.{ .cwd_relative = tree_sitter_main_include });

    // Build the tree-sitter-typescript library
    const tree_sitter_typescript = b.addStaticLibrary(.{
        .name = "tree-sitter-typescript",
        .target = target,
        .optimize = mode,
    });

    const ts_parser_c = try std.fs.path.join(b.allocator, &.{ tree_sitter_ts_path, "typescript", "src", "parser.c" });
    defer b.allocator.free(ts_parser_c);

    const ts_scanner_c = try std.fs.path.join(b.allocator, &.{ tree_sitter_ts_path, "typescript", "src", "scanner.c" });
    defer b.allocator.free(ts_scanner_c);

    const ts_include_path = try std.fs.path.join(b.allocator, &.{ tree_sitter_ts_path, "typescript", "src" });
    defer b.allocator.free(ts_include_path);

    tree_sitter_typescript.addCSourceFiles(.{
        .flags = &.{ "-std=c99", "-fPIC", "-D_GNU_SOURCE" },
        .files = &.{ ts_parser_c, ts_scanner_c },
    });

    // Add TSX library
    const tree_sitter_tsx = b.addStaticLibrary(.{
        .name = "tree-sitter-tsx",
        .target = target,
        .optimize = mode,
    });

    const tsx_parser_c = try std.fs.path.join(b.allocator, &.{ tree_sitter_ts_path, "tsx", "src", "parser.c" });
    defer b.allocator.free(tsx_parser_c);

    const tsx_scanner_c = try std.fs.path.join(b.allocator, &.{ tree_sitter_ts_path, "tsx", "src", "scanner.c" });
    defer b.allocator.free(tsx_scanner_c);

    const tsx_include_path = try std.fs.path.join(b.allocator, &.{ tree_sitter_ts_path, "tsx", "src" });
    defer b.allocator.free(tsx_include_path);

    tree_sitter_tsx.addCSourceFiles(.{
        .flags = &.{ "-std=c99", "-fPIC", "-D_GNU_SOURCE" },
        .files = &.{ tsx_parser_c, tsx_scanner_c },
    });
    tree_sitter_tsx.linkLibrary(tree_sitter);
    tree_sitter_tsx.linkLibC();
    tree_sitter_typescript.installHeadersDirectory(.{ .cwd_relative = ts_include_path }, "include/tree_sitter_typescript", .{});
    tree_sitter_typescript.addIncludePath(.{ .cwd_relative = ts_include_path });
    tree_sitter_typescript.addIncludePath(.{ .cwd_relative = tree_sitter_main_include });
    tree_sitter_typescript.linkLibrary(tree_sitter);
    tree_sitter_typescript.linkLibCpp();

    // Add grammar generation step
    const gen = b.addExecutable(.{
        .name = "grammar_gen",
        .root_source_file = .{ .cwd_relative = "src/tools/grammar_gen.zig" },
        .target = target,
        .optimize = mode,
    });

    const gen_ts_cmd = b.addRunArtifact(gen);
    gen_ts_cmd.addArg("--language=typescript");
    gen_ts_cmd.addArg("--output=src/bindings/generated/typescript.zig");
    gen_ts_cmd.addArg("--parser-output=src/bindings/generated/TypeScriptParser.zig");

    const gen_tsx_cmd = b.addRunArtifact(gen);
    gen_tsx_cmd.addArg("--language=tsx");
    gen_tsx_cmd.addArg("--output=src/bindings/generated/tsx.zig");
    gen_tsx_cmd.addArg("--parser-output=src/bindings/generated/TSXParser.zig");

    // Create modules for the final executable
    const tree_sitter_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/bindings/tree_sitter.zig" },
    });
    const tree_sitter_typescript_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "src/bindings/tree_sitter_typescript.zig" },
    });

    // Create the main executable
    const clap_dep = b.dependency("clap", .{});
    const exe = b.addExecutable(.{
        .name = exe_name,
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = mode,
    });
    exe.root_module.addImport("clap", clap_dep.module("clap"));
    exe.addIncludePath(.{ .cwd_relative = "src" });
    exe.linkLibC();
    exe.linkLibrary(tree_sitter);
    exe.linkLibrary(tree_sitter_typescript);
    exe.addObjectFile(.{ .cwd_relative = ts_lib_c });
    exe.addObjectFile(.{ .cwd_relative = ts_parser_c });
    exe.addObjectFile(.{ .cwd_relative = ts_scanner_c });
    // exe.addLibraryPath(.{ .cwd_relative = "/usr/lib" });

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
