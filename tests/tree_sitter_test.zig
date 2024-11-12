const std = @import("std");
const testing = std.testing;
const ts = @import("tree-sitter");

test "Point creation" {
    const point = ts.Point.init(10, 20);
    try testing.expectEqual(@as(u32, 10), point.row);
    try testing.expectEqual(@as(u32, 20), point.column);
}

test "Range creation" {
    const start = ts.Point.init(1, 0);
    const end = ts.Point.init(2, 10);
    const range = ts.Range.init(start, end, 100, 200);

    try testing.expectEqual(@as(u32, 1), range.start_point.row);
    try testing.expectEqual(@as(u32, 0), range.start_point.column);
    try testing.expectEqual(@as(u32, 2), range.end_point.row);
    try testing.expectEqual(@as(u32, 10), range.end_point.column);
    try testing.expectEqual(@as(u32, 100), range.start_byte);
    try testing.expectEqual(@as(u32, 200), range.end_byte);
}

test "Parser creation and basic operations" {
    var parser = try ts.Parser.init();
    defer parser.deinit();

    // Test timeout operations
    parser.setTimeout(1000);
    try testing.expectEqual(@as(u64, 1000), parser.timeout());

    // Reset parser
    parser.reset();

    // Test language operations
    try testing.expectEqual(@as(?*const ts.Language, null), parser.language());
}

test "Node creation and basic operations" {
    const null_node = ts.Node.null_();
    try testing.expectEqual(@as(?*const ts.Tree, null), null_node.tree);
    try testing.expectEqual(@as(u32, 0), null_node.id);
    try testing.expectEqual(@as(u32, 0), null_node.context[0]);

    try testing.expect(null_node.isNull());
}

test "TreeCursor operations" {
    const null_node = ts.Node.null_();
    const cursor = ts.TreeCursor.init(null_node);
    try testing.expectEqual(@as(?*const ts.Tree, null), cursor.tree);
    try testing.expectEqual(@as(u32, 0), cursor.id);
    try testing.expectEqual(@as(u32, 0), cursor.context[0]);
}

test "Query error types" {
    try testing.expectEqual(ts.QueryError.None, ts.QueryError.None);
    try testing.expectEqual(ts.QueryError.Syntax, ts.QueryError.Syntax);
    try testing.expectEqual(ts.QueryError.NodeType, ts.QueryError.NodeType);
    try testing.expectEqual(ts.QueryError.Field, ts.QueryError.Field);
    try testing.expectEqual(ts.QueryError.Capture, ts.QueryError.Capture);
    try testing.expectEqual(ts.QueryError.Structure, ts.QueryError.Structure);
    try testing.expectEqual(ts.QueryError.Language, ts.QueryError.Language);
}

test "Input encoding types" {
    try testing.expectEqual(ts.InputEncoding.UTF8, ts.InputEncoding.UTF8);
    try testing.expectEqual(ts.InputEncoding.UTF16LE, ts.InputEncoding.UTF16LE);
    try testing.expectEqual(ts.InputEncoding.UTF16BE, ts.InputEncoding.UTF16BE);
    try testing.expectEqual(ts.InputEncoding.Custom, ts.InputEncoding.Custom);
}

test "Symbol types" {
    try testing.expectEqual(ts.SymbolType.Regular, ts.SymbolType.Regular);
    try testing.expectEqual(ts.SymbolType.Anonymous, ts.SymbolType.Anonymous);
    try testing.expectEqual(ts.SymbolType.Supertype, ts.SymbolType.Supertype);
    try testing.expectEqual(ts.SymbolType.Auxiliary, ts.SymbolType.Auxiliary);
}

test "Error types" {
    const makeErrorFn = struct {
        fn make(err: ts.Error) error{
            ParserCreationFailed,
            QueryCreationFailed,
            InvalidCaptureId,
            InvalidStringId,
            InvalidPatternIndex,
            OutOfMemory,
            LanguageVersionMismatch,
            InvalidRange,
        }!void {
            return err;
        }
    }.make;

    try testing.expectError(error.ParserCreationFailed, makeErrorFn(error.ParserCreationFailed));
    try testing.expectError(error.QueryCreationFailed, makeErrorFn(error.QueryCreationFailed));
    try testing.expectError(error.InvalidCaptureId, makeErrorFn(error.InvalidCaptureId));
    try testing.expectError(error.InvalidStringId, makeErrorFn(error.InvalidStringId));
    try testing.expectError(error.InvalidPatternIndex, makeErrorFn(error.InvalidPatternIndex));
    try testing.expectError(error.OutOfMemory, makeErrorFn(error.OutOfMemory));
    try testing.expectError(error.LanguageVersionMismatch, makeErrorFn(error.LanguageVersionMismatch));
    try testing.expectError(error.InvalidRange, makeErrorFn(error.InvalidRange));
}
