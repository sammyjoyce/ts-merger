const std = @import("std");
const tree_sitter = @import("tree_sitter.zig");

pub const LanguageError = error{
    UnsupportedLanguage,
    DetectionFailed,
    ParserInitFailed,
    LanguageConfigError,
    InvalidSource,
};

pub const Language = enum {
    TypeScript,
    JavaScript,
    // Add more languages as needed

    pub fn fromExtension(extension: []const u8) LanguageError!Language {
        const ext = std.mem.trimLeft(u8, extension, ".");
        return switch (std.ascii.lowerString(ext)) {
            "ts", "tsx" => .TypeScript,
            "js", "jsx" => .JavaScript,
            else => LanguageError.UnsupportedLanguage,
        };
    }

    pub fn fromContent(content: []const u8) LanguageError!Language {
        if (content.len == 0) return LanguageError.InvalidSource;

        // Look for TypeScript-specific syntax
        if (std.mem.indexOf(u8, content, "interface ") != null or
            std.mem.indexOf(u8, content, ": type") != null or
            std.mem.indexOf(u8, content, "namespace ") != null)
        {
            return .TypeScript;
        }

        // Default to JavaScript if no TypeScript-specific syntax is found
        return .JavaScript;
    }

    pub fn getExtensions(self: Language) []const []const u8 {
        return switch (self) {
            .TypeScript => &[_][]const u8{ ".ts", ".tsx" },
            .JavaScript => &[_][]const u8{ ".js", ".jsx" },
        };
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
