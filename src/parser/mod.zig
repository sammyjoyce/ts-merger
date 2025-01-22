const std = @import("std");
const ast = @import("../ast/ast_types.zig");

const common = @import("common.zig");
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
        const Ptr = @TypeOf(ctx);
        const impl: *Ptr = @alignCast(ctx);
        if (@sizeOf(Ptr) == 0) @compileError("Parser implementation cannot be zero-sized");
        if (!@hasDecl(Ptr, "parse")) @compileError("Parser implementation must have parse method");
        return @call(.auto, impl.parse, .{source});
    }

    fn formatWrapper(ctx: *anyopaque, node: *ast.Node) ParseError![]const u8 {
        const impl: *const @TypeOf(impl) = @ptrCast(@alignCast(ctx));
        return impl.format(node);
    }

    fn deinitWrapper(ctx: *anyopaque) void {
        const impl: *const @TypeOf(impl) = @ptrCast(@alignCast(ctx));
        impl.deinit();
    }
};
