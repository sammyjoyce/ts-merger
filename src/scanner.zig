const std = @import("std");
const ts = @import("bindings/tree_sitter.zig");
const ts_typescript = @import("bindings/tree_sitter_typescript.zig");
const ast = @import("ast_types.zig");

/// Scanner for TypeScript that interfaces with Tree-sitter's external scanner API.
pub const TypeScriptScanner = struct {
    const Self = @This();

    scanner: ts.Scanner,
    lookahead_char: i32,
    result_symbol: i32,
    payload: ?*anyopaque,

    /// Initializes the `TypeScriptScanner` by creating the external scanner payload.
    pub fn init() !Self {
        const payload = ts_typescript.tree_sitter_typescript_external_scanner_create();
        return .{
            .scanner = .{
                .payload = payload,
                .advance = advanceImpl,
                .mark_end = markEndImpl,
                .reset = resetImpl,
                .lookahead = lookaheadImpl,
                .is_at_included_range_start = isAtIncludedRangeStartImpl,
                .is_at_included_range_end = isAtIncludedRangeEndImpl,
                .result_symbol = 0,
            },
            .lookahead_char = -1,
            .result_symbol = 0,
            .payload = payload,
        };
    }

    /// Deinitializes the `TypeScriptScanner` by destroying the external scanner payload.
    pub fn deinit(self: *Self) void {
        ts_typescript.tree_sitter_typescript_external_scanner_destroy(self.payload);
        self.payload = null;
    }

    /// Scans the input and updates the scanner state.
    pub fn scan(self: *Self, valid_symbols: []const bool) bool {
        return ts_typescript.tree_sitter_typescript_external_scanner_scan(
            self.payload,
            &self.scanner,
            valid_symbols.ptr,
        );
    }

    /// Advances the scanner by one token.
    fn advanceImpl(payload: ?*anyopaque, skip: bool) callconv(.C) void {
        _ = skip;
        if (payload) |p| {
            // Prepare the valid_symbols array for the scanner.
            const fields = std.meta.fields(ts_typescript.TokenType);
            var valid_symbols = [_]bool{true} ** fields.len;
            // SAFETY: The scanner state is managed by tree-sitter and doesn't require initialization here
            _ = ts_typescript.tree_sitter_typescript_external_scanner_scan(p, undefined, &valid_symbols);
        }
    }

    fn markEndImpl(payload: ?*anyopaque) callconv(.C) void {
        _ = payload;
    }

    fn resetImpl(payload: ?*anyopaque) callconv(.C) void {
        _ = payload;
    }

    /// Provides a lookahead character without advancing the scanner.
    fn lookaheadImpl(payload: ?*anyopaque) callconv(.C) i32 {
        if (payload) |p| {
            const fields = std.meta.fields(ts_typescript.TokenType);
            var valid_symbols = [_]bool{true} ** fields.len;
            // SAFETY: The scanner state is managed by tree-sitter and doesn't require initialization here
            if (ts_typescript.tree_sitter_typescript_external_scanner_scan(p, undefined, &valid_symbols)) {
                return @intFromEnum(ts_typescript.TokenType.AUTOMATIC_SEMICOLON);
            }
        }
        return -1;
    }

    fn isAtIncludedRangeStartImpl(payload: ?*anyopaque) callconv(.C) bool {
        _ = payload;
        return false;
    }

    fn isAtIncludedRangeEndImpl(payload: ?*anyopaque) callconv(.C) bool {
        _ = payload;
        return false;
    }
};
