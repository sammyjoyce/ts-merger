const std = @import("std");
const cli = @import("../cli.zig");
const ast_types = @import("../ast/ast_types.zig");
const parser_mod = @import("../parser/mod.zig");
const typescript = @import("../parser/typescript.zig");
const flow = @import("../flow.zig");

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
            Logger.scoped(.Error, "merge").err(
                "Source file '{s}' is not a TypeScript file",
                .{file}
            );
            return error.InvalidArguments;
        }
    }
    if (!std.mem.endsWith(u8, target_file, ".ts")) {
        Logger.scoped(.Error, "merge").err(
            "Target file '{s}' is not a TypeScript file",
            .{target_file}
        );
        return error.InvalidArguments;
    }

    logger.info("Target: {s}", .{target_file});
    logger.info("Source files:", .{});
    for (source_files) |file| {
        logger.info("  - {s}", .{file});
    }

    // Initialize parser and flow
    var ts_parser = try typescript.TypeScriptParser.init(allocator);
    defer ts_parser.deinit();

    var project = try Project.init(allocator, &parser_mod.Parser.init(allocator, ts_parser_impl)); // Use generic parser with TypeScript implementation
    defer project.deinit();

    // Process source files
    for (source_files) |file| {
        Logger.scoped(.Info, "merge").info("Processing file: {s}", .{file});
        try project.parseFile(file);
    }

    // Get topologically ordered nodes
    const ordered_nodes = try project.flow.getTopologicalOrder();

    // Create target file
    const target = std.fs.cwd().createFile(target_file, .{}) catch |err| {
        Logger.scoped(.Error, "merge").err(
            "Failed to create target file '{s}': {s}",
            .{target_file, @errorName(err)}
        );
        return err;  // Proper error propagation
    };
    defer target.close();

    // Write merged content using project API
    try project.writeToFile(target_file);

    Logger.scoped(.Info, "merge").info("Merge completed successfully!", .{});
}
