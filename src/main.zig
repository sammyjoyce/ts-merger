const std = @import("std");
const help = @import("help.zig");
const build_options = @import("build_options");

const VERSION = "1.0.0";

const Config = struct {
    target_dir: []const u8,
    output_name: []const u8,
    recursive: bool,
    exclude_patterns: []const []const u8,
    preserve_comments: bool,
    sort_imports: bool,
};

fn parseExcludePatterns(allocator: std.mem.Allocator, patterns: []const u8) ![]const []const u8 {
    var list = std.ArrayList([]const u8).init(allocator);
    errdefer {
        for (list.items) |item| {
            allocator.free(item);
        }
        list.deinit();
    }

    var it = std.mem.split(u8, patterns, ",");
    while (it.next()) |pattern| {
        const trimmed = std.mem.trim(u8, pattern, " ");
        if (trimmed.len > 0) {
            const pattern_copy = try allocator.dupe(u8, trimmed);
            try list.append(pattern_copy);
        }
    }

    return list.toOwnedSlice();
}

fn getDefaultOutputName(allocator: std.mem.Allocator, dir: []const u8) ![]const u8 {
    if (dir.len == 0 or std.mem.eql(u8, dir, ".")) {
        const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
        defer allocator.free(cwd);
        const dirname = std.fs.path.basename(cwd);
        return std.fmt.allocPrint(allocator, "{s}_merged.ts", .{dirname});
    }
    const dirname = std.fs.path.basename(dir);
    return std.fmt.allocPrint(allocator, "{s}_merged.ts", .{dirname});
}
const MAX_FILE_SIZE = 1024 * 1024; // 1MB max file size

pub fn main() !void {
    // Check for help flag
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    defer std.process.argsFree(std.heap.page_allocator, args);

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            help.printHelp();
            return;
        }
    }

    // Print version info
    std.log.info("TypeScript Fragment Merger v{s}", .{VERSION});

    // Setup allocator
    const allocator = std.heap.page_allocator;

    // Parse configuration
    const exclude_patterns = try parseExcludePatterns(allocator, build_options.exclude);
    defer {
        for (exclude_patterns) |pattern| {
            allocator.free(pattern);
        }
        allocator.free(exclude_patterns);
    }

    const output_name = if (build_options.output_name.len > 0)
        build_options.output_name
    else
        try getDefaultOutputName(allocator, build_options.target_dir);

    if (!std.mem.eql(u8, build_options.output_name, "")) {
        defer allocator.free(output_name);
    }

    const config = Config{
        .target_dir = build_options.target_dir,
        .output_name = output_name,
        .recursive = build_options.recursive,
        .exclude_patterns = exclude_patterns,
        .preserve_comments = build_options.preserve_comments,
        .sort_imports = build_options.sort_imports,
    };

    // Log configuration
    std.log.info("Configuration:", .{});
    std.log.info("  Target directory: {s}", .{config.target_dir});
    std.log.info("  Output file: {s}", .{config.output_name});
    std.log.info("  Recursive: {}", .{config.recursive});
    std.log.info("  Preserve comments: {}", .{config.preserve_comments});
    std.log.info("  Sort imports: {}", .{config.sort_imports});
    if (config.exclude_patterns.len > 0) {
        std.log.info("  Exclude patterns:", .{});
        for (config.exclude_patterns) |pattern| {
            std.log.info("    - {s}", .{pattern});
        }
    }

    // Open working directory
    var cwd = std.fs.cwd().openDir(config.target_dir, .{ .iterate = true }) catch |err| {
        std.log.err("Failed to open current directory: {}", .{err});
        return err;
    };
    defer cwd.close();

    // Define output file name
    const output_filename = "merged.ts";

    // Get export order and other content from index.ts
    var export_info = try findExportOrder(&cwd, allocator);
    defer {
        if (export_info.other_content) |content| {
            allocator.free(content);
        }
        var it = export_info.order_map.keyIterator();
        while (it.next()) |key| {
            allocator.free(key.*);
        }
        export_info.order_map.deinit();
    }

    // Collect .ts files from current directory, excluding 'index.ts'
    std.log.info("Scanning for TypeScript files...", .{});
    var entries_list = try collectTSFiles(&cwd, allocator, &export_info.order_map);
    if (entries_list.items.len == 0) {
        std.log.info("No TypeScript files found in the current directory.", .{});
        return;
    }
    std.log.info("Found {d} TypeScript files to merge.", .{entries_list.items.len});
    defer {
        for (entries_list.items) |entry| {
            entry.deinit();
        }
        entries_list.deinit();
    }
    const entries = entries_list.items;

    // Sort the entries for consistent merge order
    std.mem.sort(FileEntry, entries, {}, FileEntry.compare);

    // Check if output file already exists
    if (cwd.statFile(output_filename)) |_| {
        std.log.info("Output file '{s}' already exists. Overwriting.", .{output_filename});
    } else |_| {}

    // Create or overwrite the output file
    const output_file = cwd.createFile(output_filename, .{ .truncate = true }) catch |err| {
        std.log.err("Failed to create output file '{s}': {}", .{ output_filename, err });
        return err;
    };
    defer output_file.close();

    const writer = output_file.writer();

    // Write non-barrel content from index.ts first, if any
    if (export_info.other_content) |content| {
        std.log.info("Including non-barrel content from index.ts", .{});
        try writer.print("\n// Source: index.ts (non-barrel content)\n", .{});

        // Process the content to remove imports from files that will be merged
        var lines = std.mem.split(u8, content, "\n");
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");

            // Skip empty lines
            if (trimmed.len == 0) {
                try writer.writeAll("\n");
                continue;
            }

            // Check if this is an import from one of our merged files
            var skip_line = false;
            if (std.mem.indexOf(u8, trimmed, "import")) |_| {
                if (std.mem.indexOf(u8, trimmed, "./")) |start| {
                    var end = start + 2;
                    while (end < trimmed.len and trimmed[end] != '\'' and trimmed[end] != '"') : (end += 1) {}
                    if (end > start + 2) {
                        const import_path = try std.fmt.allocPrint(allocator, "{s}.ts", .{trimmed[start + 2 .. end]});
                        defer allocator.free(import_path);

                        // Check if this import refers to one of our merged files
                        for (entries) |entry| {
                            if (std.mem.eql(u8, entry.name, import_path)) {
                                skip_line = true;
                                break;
                            }
                        }
                    }
                }
            }

            if (!skip_line) {
                try writer.print("{s}\n", .{line});
            }
        }
        try writer.writeAll("\n");
    }

    // First, read all file contents
    var file_contents = std.StringHashMap([]const u8).init(allocator);
    defer {
        var it = file_contents.valueIterator();
        while (it.next()) |value| {
            allocator.free(value.*);
        }
        file_contents.deinit();
    }

    // Read all files into memory
    for (entries) |entry| {
        const file = try cwd.openFile(entry.name, .{});
        defer file.close();
        const content = try file.readToEndAlloc(allocator, 1024 * 1024);
        try file_contents.put(entry.name, content);
    }

    // Process and write each file
    for (entries) |entry| {
        std.log.info("Merging file: {s}", .{entry.name});
        try writer.print("\n// Source: {s}\n", .{entry.name});

        const content = file_contents.get(entry.name).?;
        var lines = std.mem.split(u8, content, "\n");

        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");

            // Skip empty lines
            if (trimmed.len == 0) {
                try writer.writeAll("\n");
                continue;
            }

            // Check if this is an import from one of our merged files
            var skip_line = false;
            if (std.mem.indexOf(u8, trimmed, "import")) |_| {
                if (std.mem.indexOf(u8, trimmed, "./")) |start| {
                    var end = start + 2;
                    while (end < trimmed.len and trimmed[end] != '\'' and trimmed[end] != '"') : (end += 1) {}
                    if (end > start + 2) {
                        const import_path = try std.fmt.allocPrint(allocator, "{s}.ts", .{trimmed[start + 2 .. end]});
                        defer allocator.free(import_path);

                        // Check if this import refers to one of our merged files
                        for (entries) |other_entry| {
                            if (std.mem.eql(u8, other_entry.name, import_path)) {
                                skip_line = true;
                                break;
                            }
                        }
                    }
                }
            }

            if (!skip_line) {
                try writer.print("{s}\n", .{line});
            }
        }
    }

    std.log.info("Merging completed successfully.", .{});
}

const ExportInfo = struct {
    order_map: std.StringHashMap(usize),
    other_content: ?[]const u8,
};

const FileEntry = struct {
    name: []const u8,
    order: usize,
    allocator: std.mem.Allocator,

    pub fn compare(_: void, a: FileEntry, b: FileEntry) bool {
        if (a.order != b.order) {
            return a.order < b.order;
        }
        return std.mem.lessThan(u8, a.name, b.name);
    }

    pub fn deinit(self: FileEntry) void {
        self.allocator.free(self.name);
    }
};

fn findExportOrder(dir: *std.fs.Dir, allocator: std.mem.Allocator) !ExportInfo {
    var order_map = std.StringHashMap(usize).init(allocator);
    errdefer order_map.deinit();

    var other_content = std.ArrayList(u8).init(allocator);
    errdefer other_content.deinit();

    const index_file = dir.openFile("index.ts", .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.log.info("No index.ts found, using alphabetical order.", .{});
            return ExportInfo{
                .order_map = order_map,
                .other_content = null,
            };
        },
        else => return err,
    };
    defer index_file.close();

    const index_content = index_file.readToEndAlloc(allocator, MAX_FILE_SIZE) catch |err| {
        std.log.err("Failed to read index.ts: {}", .{err});
        return err;
    };
    defer allocator.free(index_content);

    var line_it = std.mem.split(u8, index_content, "\n");
    var order: usize = 0;

    while (line_it.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) {
            try other_content.appendSlice("\n");
            continue;
        }

        var is_barrel_export = false;
        if (std.mem.indexOf(u8, trimmed, "export")) |_| {
            if (std.mem.indexOf(u8, trimmed, "./")) |start| {
                is_barrel_export = true;
                var end = start + 2;
                while (end < trimmed.len and trimmed[end] != '\'' and trimmed[end] != '"') : (end += 1) {}
                if (end > start + 2) {
                    const file_path = trimmed[start + 2 .. end];
                    // Allocate a persistent string for the map key
                    const key = try std.fmt.allocPrint(allocator, "{s}.ts", .{file_path});
                    errdefer allocator.free(key);

                    // If put fails, free the key
                    order_map.put(key, order) catch |err| {
                        allocator.free(key);
                        return err;
                    };
                    order += 1;
                }
            }
        }

        if (!is_barrel_export) {
            try other_content.appendSlice(line);
            try other_content.appendSlice("\n");
        }
    }

    const final_content = if (other_content.items.len > 0 and !std.mem.eql(u8, std.mem.trim(u8, other_content.items, " \t\r\n"), ""))
        try other_content.toOwnedSlice()
    else
        null;

    if (final_content) |content| {
        std.log.info("Found non-barrel content in index.ts ({d} bytes)", .{content.len});
        std.log.info("First few characters: '{s}'", .{if (content.len > 50) content[0..50] else content});
    } else {
        std.log.info("No non-barrel content found in index.ts", .{});
    }

    return ExportInfo{
        .order_map = order_map,
        .other_content = final_content,
    };
}

fn collectTSFiles(dir: *std.fs.Dir, allocator: std.mem.Allocator, export_order: *std.StringHashMap(usize)) !std.ArrayList(FileEntry) {
    var list = std.ArrayList(FileEntry).init(allocator);

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".ts")) continue;
        if (std.mem.eql(u8, entry.name, "index.ts")) continue;
        if (std.mem.eql(u8, entry.name, "merged.ts")) continue;

        std.log.info("Found TypeScript file: {s}", .{entry.name});
        const name_copy = try allocator.dupe(u8, entry.name);
        const order = export_order.get(entry.name) orelse std.math.maxInt(usize);
        try list.append(FileEntry{
            .name = name_copy,
            .order = order,
            .allocator = allocator,
        });
    }

    return list;
}
