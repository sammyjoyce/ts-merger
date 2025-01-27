pub usingnamespace @import("tree_sitter.zig");
pub const language = @import("language.zig");
pub const typescript = @import("tree_sitter_typescript.zig");
pub const tree_sitter_typescript = @import("tree_sitter_typescript.zig");
pub const tsx = @import("tree_sitter_tsx.zig");

pub const tree_sitter_tsx = struct {
    pub const language = @import("language.zig");
    pub const NodeType = NodeType(.TSX);
    pub const NodeTypes = @import("generated/tsx.zig").NodeTypes;
    pub const Grammar = @import("generated/tsx.zig").Grammar;
};

pub const Language = language.Language;
pub const LanguageParser = language.LanguageParser;
pub const LanguageError = language.LanguageError;

pub fn NodeType(comptime lang: Language) type {
    return switch (lang) {
        .TypeScript => @import("generated/typescript.zig").NodeType,
        .TSX => @import("generated/tsx.zig").NodeType,
        else => @compileError("Unsupported language"),
    };
}

pub fn NodeTypes(comptime lang: Language) type {
    return switch (lang) {
        .TypeScript => @import("generated/typescript.zig").NodeTypes,
        .TSX => @import("generated/tsx.zig").NodeTypes,
        else => @compileError("Unsupported language"),
    };
}

pub fn Grammar(comptime lang: Language) type {
    return switch (lang) {
        .TypeScript => @import("generated/typescript.zig").Grammar,
        .TSX => @import("generated/tsx.zig").Grammar,
        else => @compileError("Unsupported language"),
    };
}

test {
    _ = NodeType(.TypeScript);
}
