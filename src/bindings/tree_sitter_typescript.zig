const std = @import("std");
const tree_sitter = @import("tree_sitter.zig");

pub extern "c" fn tree_sitter_typescript() *const tree_sitter.Language;

/// External scanner functions
pub extern "c" fn tree_sitter_typescript_external_scanner_create() ?*anyopaque;
pub extern "c" fn tree_sitter_typescript_external_scanner_destroy(payload: ?*anyopaque) void;
pub extern "c" fn tree_sitter_typescript_external_scanner_serialize(payload: ?*anyopaque, buffer: [*]u8) u32;
pub extern "c" fn tree_sitter_typescript_external_scanner_deserialize(payload: ?*anyopaque, buffer: [*]const u8, length: u32) void;
pub extern "c" fn tree_sitter_typescript_external_scanner_scan(payload: ?*anyopaque, lexer: *tree_sitter.Scanner, valid_symbols: [*]const bool) bool;

/// Token types for the external scanner
pub const TokenType = enum(i32) {
    AUTOMATIC_SEMICOLON,
    TEMPLATE_CHARS,
    TERNARY_QMARK,
    HTML_COMMENT,
    LOGICAL_OR,
    ESCAPE_SEQUENCE,
    NEWLINE,
    INDENT,
    DEDENT,
    STRING_CONTENT,
    COMMENT_CONTENT,
    RAW_STRING_LITERAL,
    REGEX_CONTENT,
    REGEX_FLAGS,
    JSX_TEXT,
    NESTED_IDENTIFIER,
    NESTED_TYPE_IDENTIFIER,
    NESTED_NAMESPACE_IMPORT,
    REGEX_PATTERN,
    FUNCTION_SIGNATURE_AUTOMATIC_SEMICOLON,
    ERROR_RECOVERY,
};

pub fn language() *const tree_sitter.Language {
    return tree_sitter_typescript();
}
