const std = @import("std");
const Build = std.Build;

pub fn addTreeSitter(b: *Build, target: Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "tree-sitter",
        .target = target,
        .optimize = optimize,
    });

    lib.addCSourceFile(.{
        .file = .{ .cwd_relative = "deps/tree-sitter/lib/src/lib.c" },
        .flags = &.{ "-std=c99", "-fPIC", "-Wno-trigraphs" },
    });

    lib.linkLibC();
    lib.addIncludePath(.{ .cwd_relative = "deps/tree-sitter/lib/include" });

    return lib;
}

pub fn addTreeSitterTypescript(b: *Build, target: Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "tree-sitter-typescript",
        .target = target,
        .optimize = optimize,
    });

    lib.addCSourceFile(.{
        .file = .{ .cwd_relative = "deps/tree-sitter-typescript/typescript/src/parser.c" },
        .flags = &.{ "-std=c99", "-fPIC", "-Wno-trigraphs" },
    });
    lib.addCSourceFile(.{
        .file = .{ .cwd_relative = "deps/tree-sitter-typescript/typescript/src/scanner.c" },
        .flags = &.{ "-std=c99", "-fPIC", "-Wno-trigraphs" },
    });

    lib.linkLibC();
    lib.addIncludePath(.{ .cwd_relative = "deps/tree-sitter-typescript/typescript/src" });
    lib.addIncludePath(.{ .cwd_relative = "deps/tree-sitter-typescript/common" });

    return lib;
}
