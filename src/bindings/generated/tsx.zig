// Generated code - do not edit

const std = @import("std");
const bindings = @import("../bindings/mod.zig");
const ast_types = @import("../core/ast/ast_types.zig");

pub const NodeTypes = struct {
    pub const JSX_ELEMENT = "jsx_element";
    pub const JSX_OPENING_ELEMENT = "jsx_opening_element";
    pub const JSX_CLOSING_ELEMENT = "jsx_closing_element";
    pub const JSX_SELF_CLOSING_ELEMENT = "jsx_self_closing_element";
    pub const JSX_ATTRIBUTE = "jsx_attribute";
    
    // Include TypeScript node types as well since TSX is a superset
    pub usingnamespace @import("typescript.zig").NodeTypes;
};

pub const NodeType = enum {
    JsxElement,
    JsxOpeningElement,
    JsxClosingElement,
    JsxSelfClosingElement,
    JsxAttribute,
    // Include all TypeScript node types
    usingnamespace @import("typescript.zig").NodeType,
    _,
};

pub const Grammar = struct {
    pub const rules = @embedFile("grammar.json");
};
