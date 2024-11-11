//! Build script for ts-merger

const std = @import("std");

/// Current version of ts-merger
const version = std.SemanticVersion{ .major = 0, .minor = 0, .patch = 1 };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Runtime CLI options
    const target_dir = b.option(
        []const u8,
        "dir",
        "Target directory to process (defaults to current directory)",
    ) orelse ".";

    const output_name = b.option(
        []const u8,
        "out",
        "Output filename (defaults to directory name + '_merged')",
    ) orelse "";

    const recursive = b.option(
        bool,
        "recursive",
        "Recursively process subdirectories",
    ) orelse true;

    const exclude = b.option(
        []const u8,
        "exclude",
        "Comma-separated list of patterns to exclude",
    ) orelse "";

    const preserve_comments = b.option(
        bool,
        "preserve-comments",
        "Preserve comments in merged output",
    ) orelse true;

    const sort_imports = b.option(
        bool,
        "sort-imports",
        "Sort import statements",
    ) orelse true;

    const options_module = b.addOptions();
    options_module.addOption([]const u8, "target_dir", target_dir);
    options_module.addOption([]const u8, "output_name", output_name);
    options_module.addOption(bool, "recursive", recursive);
    options_module.addOption([]const u8, "exclude", exclude);
    options_module.addOption(bool, "preserve_comments", preserve_comments);
    options_module.addOption(bool, "sort_imports", sort_imports);
    // Version info for logs and debugging
    options_module.addOption(u32, "version_major", version.major);
    options_module.addOption(u32, "version_minor", version.minor);
    options_module.addOption(u32, "version_patch", version.patch);

    const exe = b.addExecutable(.{
        .name = "ts-merger",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const help_module = b.addModule("help", .{
        .root_source_file = b.path("src/help.zig"),
    });
    exe.root_module.addImport("help", help_module);

    const build_options = options_module.createModule();
    exe.root_module.addImport("build_options", build_options);

    const run_exe = b.addRunArtifact(exe);
    const run_step = b.step("run", "Run ts-merger");
    run_step.dependOn(&run_exe.step);

    // 5. Add Install Artifact
    b.installArtifact(exe);

    const clean_step = b.step("clean", "Clean build artifacts and cache");
    const remove_install = b.addRemoveDirTree(b.getInstallPath(.prefix, ""));
    clean_step.dependOn(&remove_install.step);

    if (@import("builtin").os.tag != .windows) {
        const remove_cache = b.addRemoveDirTree("zig-cache");
        clean_step.dependOn(&remove_cache.step);
    }

    const fmt_step = b.step("fmt", "Check source code formatting");
    const formatter = b.addFmt(.{
        .paths = &.{
            "src/**/*.zig",
            "tests/**/*.zig",
            "build.zig",
        },
        .check = true,
    });
    fmt_step.dependOn(&formatter.step);
}
