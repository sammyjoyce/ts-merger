const std = @import("std");

pub fn printHelp() void {
    const help_text =
        \\Usage: ts-merger [options]
        \\
        \\Options:
        \\  --dir <path>          Target directory to process (default: current directory)
        \\  --out <name>          Output filename
        \\  --recursive           Recursively process subdirectories (default: true)
        \\  --exclude <patterns>  Comma-separated list of patterns to exclude
        \\  --preserve-comments   Preserve comments in merged output (default: true)
        \\  --sort-imports        Sort import statements (default: true)
        \\  -h, --help           Show this help message
        \\
    ;
    std.debug.print("{s}", .{help_text});
}
