const std = @import("std");
const cli = @import("../cli.zig");
const ast_types = @import("../ast_types.zig");
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
    std.debug.print("Command: merge\n", .{});
    std.debug.print("Starting merge command...\n", .{});

    // Validate input
    if (config.source_paths.len == 0) {
        std.debug.print("Error: No source files specified\n", .{});
        return error.NoSourceFiles;
    }

    if (config.target_path == null) {
        std.debug.print("Error: No target file specified\n", .{});
        return error.NoTargetFile;
    }

    const target_file = config.target_path.?;
    const source_files = config.source_paths.items;

    // Validate file extensions
    for (source_files) |file| {
        if (!std.mem.endsWith(u8, file, ".ts")) {
            std.debug.print("Error: Source file '{s}' is not a TypeScript file\n", .{file});
            return error.InvalidArguments;
        }
    }
    if (!std.mem.endsWith(u8, target_file, ".ts")) {
        std.debug.print("Error: Target file '{s}' is not a TypeScript file\n", .{target_file});
        return error.InvalidArguments;
    }

    std.debug.print("Target: {s}\n", .{target_file});
    std.debug.print("Source files:\n", .{});
    for (source_files) |file| {
        std.debug.print("  - {s}\n", .{file});
    }

    // Initialize parser and flow
    var ts_parser = try typescript.TypeScriptParser.init(allocator);
    defer ts_parser.deinit();

    var flow_instance = try flow.Flow.init(allocator);
    defer flow_instance.deinit();

    // Process source files
    for (source_files) |file| {
        std.debug.print("\nProcessing file: {s}\n", .{file});
        
        // Read source file
        const source_content = std.fs.cwd().readFileAlloc(allocator, file, 1024 * 1024 * 10) catch |err| {
            std.debug.print("Error reading file '{s}': {}\n", .{ file, err });
            return error.InvalidArguments;
        };
        defer allocator.free(source_content);

        // Parse file
        ts_parser.parse(source_content) catch |err| {
            std.debug.print("Error parsing file '{s}': {}\n", .{ file, err });
            return error.ParseFailed;
        };

        // Add nodes to flow
        for (ts_parser.nodes.items) |node| {
            flow_instance.addNode(node) catch |err| {
                std.debug.print("Error adding node from file '{s}': {}\n", .{ file, err });
                return error.MergeError;
            };
        }
    }

    // Create target file
    const target = std.fs.cwd().createFile(target_file, .{}) catch |err| {
        std.debug.print("Error creating target file '{s}': {}\n", .{ target_file, err });
        return error.InvalidArguments;
    };
    defer target.close();

    // Write merged content
    flow_instance.write(target.writer()) catch |err| {
        std.debug.print("Error writing to target file '{s}': {}\n", .{ target_file, err });
        return error.MergeError;
    };

    std.debug.print("\nMerge completed successfully!\n", .{});
}
