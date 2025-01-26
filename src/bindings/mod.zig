pub usingnamespace @import("tree_sitter.zig");
pub const language = @import("language.zig");
pub const typescript = @import("tree_sitter_typescript.zig");
pub const tree_sitter_typescript = @import("tree_sitter_typescript.zig");
pub const tsx = @import("tree_sitter_tsx.zig");

pub const Language = language.Language;
pub const LanguageParser = language.LanguageParser;
pub const LanguageError = language.LanguageError;

pub fn NodeType(comptime lang: Language) type {
    return struct {
        pub const PROGRAM = "program";
        pub const FUNCTION_DECL = "function_declaration";
        pub const IDENTIFIER = "identifier";
        pub const STRING = "string";
        pub const NUMBER = "number";
        pub const COMMENT = "comment";
        pub const VARIABLE_DECL = "variable_declaration";
        pub const CLASS_DECL = "class_declaration";
        pub const INTERFACE_DECL = "interface_declaration";
        pub const TYPE_ALIAS = "type_alias_declaration";
        pub const ENUM_DECL = "enum_declaration";
        pub const IMPORT_DECL = "import_declaration";
        pub const EXPORT_DECL = "export_declaration";
        pub const METHOD_DEFINITION = "method_definition";
        pub const PROPERTY_DEFINITION = "property_definition";
        pub const OBJECT = "object";
        pub const ARRAY = "array";
    };
}

test {
    _ = NodeType(.TypeScript);
}
