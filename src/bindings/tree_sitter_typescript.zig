pub const language = @cImport({
    @cInclude("tree_sitter/parser.h");
});

pub extern "c" fn tree_sitter_typescript() *language.TSLanguage;
