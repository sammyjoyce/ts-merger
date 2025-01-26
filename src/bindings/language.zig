const std = @import("std");
const tree_sitter = @import("tree_sitter.zig");

pub const LanguageError = error{
    UnsupportedLanguage,
    DetectionFailed,
    ParserInitFailed,
    LanguageConfigError,
    InvalidSource,
    InvalidExtension,
    UnknownLanguage,
};

pub const LanguageMetadata = struct {
    name: []const u8,
    extensions: []const []const u8,
    parser_create: *const fn (std.mem.Allocator) anyerror!*tree_sitter.Parser,
    node_types: NodeTypeInfo,
    detect_content: *const fn ([]const u8) bool,
};

pub const NodeTypeInfo = struct {
    program: []const u8,
    interface_decl: []const u8,
    class_decl: []const u8,
    function_decl: []const u8,
    variable_decl: []const u8,
    import_decl: []const u8,
    export_decl: []const u8,
};

pub const LanguageRegistry = struct {
    allocator: std.mem.Allocator,
    languages: std.ArrayList(LanguageMetadata),

    pub fn init(allocator: std.mem.Allocator) LanguageRegistry {
        return .{
            .allocator = allocator,
            .languages = std.ArrayList(LanguageMetadata).init(allocator),
        };
    }

    pub fn deinit(self: *LanguageRegistry) void {
        self.languages.deinit();
    }

    pub fn register(self: *LanguageRegistry, meta: LanguageMetadata) !void {
        try self.languages.append(meta);
    }

    pub fn detect(self: *const LanguageRegistry, filename: ?[]const u8, source: []const u8) LanguageError!*const LanguageMetadata {
        // Try detection by file extension first
        if (filename) |fname| {
            if (self.detectByExtension(fname)) |lang| return lang;
        }

        // Fall back to content analysis
        return self.detectByContent(source) orelse error.DetectionFailed;
    }

    fn detectByExtension(self: *const LanguageRegistry, filename: []const u8) ?*const LanguageMetadata {
        if (std.mem.lastIndexOfScalar(u8, filename, '.')) |dot| {
            const ext = filename[dot + 1 ..];
            for (self.languages.items) |*lang| {
                for (lang.extensions) |lang_ext| {
                    if (std.mem.eql(u8, ext, lang_ext)) return lang;
                }
            }
        }
        return null;
    }

    fn detectByContent(self: *const LanguageRegistry, source: []const u8) ?*const LanguageMetadata {
        for (self.languages.items) |*lang| {
            if (lang.detect_content(source)) {
                return lang;
            }
        }
        return null;
    }
};

pub const LanguageParser = struct {
    allocator: std.mem.Allocator,
    language: Language,
    parser: tree_sitter.Parser,
    language_ptr: *const tree_sitter.Language,

    pub fn init(allocator: std.mem.Allocator, language: Language) !LanguageParser {
        var parser = try tree_sitter.Parser.init(allocator);
        errdefer parser.deinit();

        const language_ptr = switch (language) {
            .TypeScript => tree_sitter_typescript(),
            .JavaScript => tree_sitter_typescript(), // Currently using TypeScript parser for JS
        };

        try parser.setLanguage(language_ptr);

        return .{
            .allocator = allocator,
            .language = language,
            .parser = parser,
            .language_ptr = language_ptr,
        };
    }

    pub fn deinit(self: *LanguageParser) void {
        self.parser.deinit();
    }

    pub fn parse(self: *LanguageParser, source: []const u8) !tree_sitter.Tree {
        if (source.len == 0) return LanguageError.InvalidSource;
        if (source.len > std.math.maxInt(u32)) return LanguageError.InvalidSource;

        return self.parser.parseString(null, source);
    }
};

// External C functions for different language parsers
extern "c" fn tree_sitter_typescript() *const tree_sitter.Language;
// Add more language parser declarations as needed
