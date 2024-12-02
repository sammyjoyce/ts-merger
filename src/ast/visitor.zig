const std = @import("std");
const Node = @import("../types.zig").Node;

pub const Visitor = struct {
    pub const VisitError = error{
        OutOfMemory,
        InvalidNode,
    };

    pub const VisitResult = enum {
        Continue,
        Skip,
        Stop,
    };

    pub const VisitFn = *const fn (*Node) VisitError!VisitResult;

    pub fn visit(node: *Node, visitor_fn: VisitFn) VisitError!void {
        const result = try visitor_fn(node);
        switch (result) {
            .Continue => {
                for (node.children.items) |child| {
                    try visit(child, visitor_fn);
                }
            },
            .Skip => {},
            .Stop => return,
        }
    }

    pub fn visitPost(node: *Node, visitor_fn: VisitFn) VisitError!void {
        for (node.children.items) |child| {
            try visitPost(child, visitor_fn);
        }
        _ = try visitor_fn(node);
    }
};
