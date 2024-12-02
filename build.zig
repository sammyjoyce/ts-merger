const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add name option
    const name = b.option([]const u8, "name", "Name of the executable") orelse "fuze";

    // Build tree-sitter library
    const tree_sitter = b.addStaticLibrary(.{
        .name = "tree-sitter",
        .target = target,
        .optimize = optimize,
    });
    tree_sitter.linkLibC();
    tree_sitter.addCSourceFile(.{
        .file = b.path("deps/tree-sitter/lib/src/lib.c"),
        .flags = &.{"-std=c99"},
    });
    tree_sitter.addIncludePath(b.path("deps/tree-sitter/lib/include"));
    tree_sitter.addIncludePath(b.path("deps/tree-sitter/lib/src"));

    // Build tree-sitter-typescript library
    const tree_sitter_typescript = b.addStaticLibrary(.{
        .name = "tree-sitter-typescript",
        .target = target,
        .optimize = optimize,
    });
    tree_sitter_typescript.linkLibC();
    tree_sitter_typescript.addCSourceFile(.{
        .file = b.path("deps/tree-sitter-typescript/typescript/src/parser.c"),
        .flags = &.{"-std=c99"},
    });
    tree_sitter_typescript.addCSourceFile(.{
        .file = b.path("deps/tree-sitter-typescript/typescript/src/scanner.c"),
        .flags = &.{"-std=c99"},
    });
    tree_sitter_typescript.addIncludePath(b.path("deps/tree-sitter/lib/include"));
    tree_sitter_typescript.addIncludePath(b.path("deps/tree-sitter-typescript/typescript/src"));

    // Get clap dependency
    const clap = b.dependency("clap", .{});
    const clap_module = clap.module("clap");

    // Add executable
    const exe = b.addExecutable(.{
        .name = name,
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add dependencies
    exe.root_module.addImport("clap", clap_module);
    exe.linkLibC();
    exe.addIncludePath(b.path("deps/tree-sitter/lib/include"));
    exe.addIncludePath(b.path("deps/tree-sitter-typescript/typescript/src"));
    exe.linkLibrary(tree_sitter);
    exe.linkLibrary(tree_sitter_typescript);

    // Install
    b.installArtifact(exe);

    // Add run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    // Add test step
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    unit_tests.linkLibC();
    unit_tests.addIncludePath(b.path("deps/tree-sitter/lib/include"));
    unit_tests.addIncludePath(b.path("deps/tree-sitter-typescript/typescript/src"));
    unit_tests.linkLibrary(tree_sitter);
    unit_tests.linkLibrary(tree_sitter_typescript);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
