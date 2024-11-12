const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tree_sitter = b.addStaticLibrary(.{
        .name = "tree-sitter",
        .target = target,
        .optimize = optimize,
    });
    tree_sitter.addCSourceFile(.{ .file = .{ .cwd_relative = "deps/tree-sitter/lib/src/lib.c" }, .flags = &[_][]const u8{} });
    tree_sitter.addIncludePath(.{ .cwd_relative = "deps/tree-sitter/lib/include" });
    tree_sitter.linkLibC();

    const tree_sitter_typescript = b.addStaticLibrary(.{
        .name = "tree-sitter-typescript",
        .target = target,
        .optimize = optimize,
    });
    tree_sitter_typescript.addCSourceFile(.{ .file = .{ .cwd_relative = "deps/tree-sitter-typescript/typescript/src/parser.c" }, .flags = &[_][]const u8{} });
    tree_sitter_typescript.addCSourceFile(.{ .file = .{ .cwd_relative = "deps/tree-sitter-typescript/typescript/src/scanner.c" }, .flags = &[_][]const u8{} });
    tree_sitter_typescript.addIncludePath(.{ .cwd_relative = "deps/tree-sitter/lib/include" });
    tree_sitter_typescript.linkLibC();

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

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
