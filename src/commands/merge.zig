const std = @import("std");
const cli = @import("../cli.zig");

const parser_mod = @import("../parser/mod.zig");
const typescript = @import("../parser/typescript.zig");

const Project = @import("../project.zig").Project;
const Logger = @import("../utils/log.zig").Logger;
const ProgressReporter = @import("../utils/progress.zig").ProgressReporter;
const MergeRules = @import("../core/merge/rules.zig").MergeRules;

const MergeError = error{
    NoSourceFiles,
    NoTargetFile,
    ParserError,
    MergeError,
    OutOfMemory,
    InvalidSyntax,
    ParseFailed,
    InvalidRootNode,
    ParsingFailed,
    LanguageVersionMismatch,
    ParserCreationFailed,
    InvalidRange,
    QueryCreationFailed,
    InvalidCaptureId,
    InvalidStringId,
    InvalidPatternIndex,
    UnsupportedFeature,
    CyclicDependency,
    Unseekable,
    LanguageLoadFailed,
    LanguageSetFailed,
    InvalidArguments,
} || std.fs.File.OpenError || std.fs.File.WriteError || std.fs.File.ReadError;

pub fn execute(allocator: std.mem.Allocator, config: *const cli.Config) MergeError!void {
    const logger = Logger.scoped(.Info, "merge");
    logger.info("Starting merge command...", .{});

    // Validate input
    if (config.source_paths.len == 0) {
        Logger.scoped(.Error, "merge").err("No source files specified", .{});
        return error.NoSourceFiles;
    }

    if (config.target_path == null) {
        Logger.scoped(.Error, "merge").err("No target file specified", .{});
        return error.NoTargetFile;
    }

    const target_file = config.target_path.?;
    const source_files = config.source_paths.items;

    // Validate file extensions
    for (source_files) |file| {
        if (!std.mem.endsWith(u8, file, ".ts")) {
            Logger.scoped(.Error, "merge").err("Source file '{s}' is not a TypeScript file", .{file});
            return error.InvalidArguments;
        }
    }
    if (!std.mem.endsWith(u8, target_file, ".ts")) {
        Logger.scoped(.Error, "merge").err("Target file '{s}' is not a TypeScript file", .{target_file});
        return error.InvalidArguments;
    }

    logger.info("Target: {s}", .{target_file});
    logger.info("Source files:", .{});
    for (source_files) |file| {
        logger.info("  - {s}", .{file});
    }

    // Calculate total steps for progress reporting
    // 1 step for initialization, 1 step per source file, 1 step for writing to target file
    const total_steps = 2 + source_files.len;
    var progress = try ProgressReporter.init(allocator, total_steps, "Merge", .Info, true);
    defer progress.deinit();

    // Step 1: Initialize parser and flow
    progress.update(1, "Initializing parser and project");
    var ts_parser = try typescript.TypeScriptParser.init(allocator);
    defer ts_parser.deinit();

    // Use generic parser with TypeScript implementation
    var parser = parser_mod.Parser.init(allocator, ts_parser);

    // Create merge rules with remove_redundancies and eliminate_dead_code flags from config
    const merge_rules = MergeRules{
        .preserve_comments = true,
        .sort_imports = true,
        .remove_redundancies = config.remove_redundancies,
        .eliminate_dead_code = config.eliminate_dead_code,
    };

    // Log if remove_redundancies is enabled
    if (config.remove_redundancies) {
        logger.info("Remove redundant imports: enabled", .{});
    }

    // Log if eliminate_dead_code is enabled
    if (config.eliminate_dead_code) {
        logger.info("Eliminate dead code: enabled", .{});
    }

    // Initialize project with merge rules
    var project = try Project.initWithRules(allocator, &parser, merge_rules);
    defer project.deinit();

    // Process source files
    for (0..source_files.len) |i| {
        const file = source_files[i];
        const step = 2 + i; // Step 2 is the first file
        const message = std.fmt.allocPrint(allocator, "Processing file: {s}", .{file}) catch "Processing file";
        defer if (std.mem.indexOf(u8, message, "Processing file:") != null) allocator.free(message);

        progress.update(step, message);
        try project.parseFile(file);
    }

    // Create target file
    progress.update(total_steps - 1, "Writing merged content to target file");
    const target = std.fs.cwd().createFile(target_file, .{}) catch |err| {
        Logger.scoped(.Error, "merge").err("Failed to create target file '{s}': {s}", .{ target_file, @errorName(err) });
        return err; // Proper error propagation
    };
    defer target.close();

    // Write merged content using project API
    try project.writeToFile(target_file, &progress);

    // Mark progress as complete
    progress.complete("Merge completed successfully!");
    Logger.scoped(.Info, "merge").info("Merge completed successfully!", .{});
}
