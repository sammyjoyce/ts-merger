const std = @import("std");
const ast = @import("../ast/ast_types.zig");

pub const ParseError = common.Error;

/// Generic parser interface that can be implemented for different languages
pub const Parser = struct {
    context: *anyopaque,
    vtable: *const VTable,
    allocator: std.mem.Allocator,

    pub const VTable = struct {
        parse: *const fn (*anyopaque, []const u8) ParseError!*ast.Node,
        format: *const fn (*anyopaque, *ast.Node) ParseError![]const u8,
        deinit: *const fn (*anyopaque) void,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        impl: anytype,
    ) Parser {
        const Ptr = @TypeOf(impl);
        return .{
            .allocator = allocator,
            .context = impl,
            .vtable = &.{
                .parse = @ptrCast(&parseWrapper),
                .format = @ptrCast(&formatWrapper),
                .deinit = @ptrCast(&deinitWrapper),
            },
        };
    }

    fn parseWrapper(ctx: *anyopaque, source: []const u8) ParseError!*ast.Node {
        const impl: *const Ptr = @ptrCast(@alignCast(ctx));
        return impl.parse(source);
    }

    fn formatWrapper(ctx: *anyopaque, node: *ast.Node) ParseError![]const u8 {
        const impl: *const Ptr = @ptrCast(@alignCast(ctx));
        return impl.format(node);
    }

    fn deinitWrapper(ctx: *anyopaque) void {
        const impl: *const Ptr = @ptrCast(@alignCast(ctx));
        impl.deinit();
    }
};
