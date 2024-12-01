const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Clone Tree-sitter repository if it doesn't exist
    const clone_tree_sitter = b.addSystemCommand(&[_][]const u8{
        "sh", "-c",
        "test -d deps/tree-sitter || git clone https://github.com/tree-sitter/tree-sitter.git deps/tree-sitter",
    });

    // Clone Tree-sitter TypeScript repository if it doesn't exist
    const clone_tree_sitter_typescript = b.addSystemCommand(&[_][]const u8{
        "sh", "-c",
        "test -d deps/tree-sitter-typescript || git clone https://github.com/tree-sitter/tree-sitter-typescript.git deps/tree-sitter-typescript",
    });

    // Ensure Tree-sitter is cloned before Tree-sitter TypeScript
    clone_tree_sitter_typescript.step.dependOn(&clone_tree_sitter.step);

    // Build Tree-sitter static library
    const tree_sitter = b.addStaticLibrary(.{
        .name = "tree-sitter",
        .target = target,
        .optimize = optimize,
    });
    tree_sitter.addCSourceFile(.{
        .file = .{ .cwd_relative = "deps/tree-sitter/lib/src/lib.c" },
        .flags = &[_][]const u8{},
    });
    tree_sitter.addIncludePath(.{ .cwd_relative = "deps/tree-sitter/lib/include" });
    tree_sitter.linkLibC();
    tree_sitter.step.dependOn(&clone_tree_sitter.step);

    // Build Tree-sitter TypeScript static library
    const tree_sitter_typescript = b.addStaticLibrary(.{
        .name = "tree-sitter-typescript",
        .target = target,
        .optimize = optimize,
    });
    tree_sitter_typescript.addCSourceFile(.{
        .file = .{ .cwd_relative = "deps/tree-sitter-typescript/typescript/src/parser.c" },
        .flags = &[_][]const u8{},
    });
    tree_sitter_typescript.addCSourceFile(.{
        .file = .{ .cwd_relative = "deps/tree-sitter-typescript/typescript/src/scanner.c" },
        .flags = &[_][]const u8{},
    });
    tree_sitter_typescript.addIncludePath(.{ .cwd_relative = "deps/tree-sitter/lib/include" });
    tree_sitter_typescript.addIncludePath(.{ .cwd_relative = "deps/tree-sitter-typescript/typescript/src" });
    tree_sitter_typescript.addIncludePath(.{ .cwd_relative = "deps/tree-sitter-typescript/common" });
    tree_sitter_typescript.linkLibC();
    tree_sitter_typescript.step.dependOn(&clone_tree_sitter_typescript.step);
    tree_sitter_typescript.step.dependOn(&tree_sitter.step);

    // Add executable
    const exe = b.addExecutable(.{
        .name = "fuze",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addIncludePath(.{ .cwd_relative = "deps/tree-sitter/lib/include" });
    exe.linkLibrary(tree_sitter);
    exe.linkLibrary(tree_sitter_typescript);
    exe.linkLibC();

    b.installArtifact(exe);

    // Add run step - allows `zig build run -- [args]` to run the application
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the TypeScript merger application");
    run_step.dependOn(&run_cmd.step);

    // Add test step
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.addIncludePath(.{ .cwd_relative = "deps/tree-sitter/lib/include" });
    unit_tests.linkLibrary(tree_sitter);
    unit_tests.linkLibrary(tree_sitter_typescript);
    unit_tests.linkLibC();

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
