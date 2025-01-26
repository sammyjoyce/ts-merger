const tree_sitter = @import("tree_sitter.zig");
const tree_sitter_typescript = @import("tree_sitter_typescript.zig");

pub const TreeSitter = tree_sitter;
pub const TreeSitterTypeScript = tree_sitter_typescript;

test {
    _ = TreeSitter;
    _ = TreeSitterTypeScript;
}
