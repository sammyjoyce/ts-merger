pub usingnamespace @import("tree_sitter.zig");
pub const typescript = @import("tree_sitter_typescript.zig");

pub fn NodeType(comptime lang: anytype) type {
    return struct {
        pub const PROGRAM = "program";
        pub const FUNCTION_DECL = "function_declaration";
        pub const IDENTIFIER = "identifier";
        pub const STRING = "string";
        pub const NUMBER = "number";
        pub const COMMENT = "comment";
    };
}

test {
    _ = NodeType(typescript);
}
