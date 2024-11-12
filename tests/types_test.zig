const std = @import("std");
const testing = std.testing;
const types = @import("types");

test "create and manipulate Position" {
    const pos = types.Position{
        .line = 10,
        .column = 5,
    };

    try testing.expectEqual(@as(u32, 10), pos.line);
    try testing.expectEqual(@as(u32, 5), pos.column);
}

test "create and manipulate Location" {
    const loc = types.Location{
        .file = "test.ts",
        .start = .{ .line = 1, .column = 0 },
        .end = .{ .line = 5, .column = 10 },
    };

    try testing.expectEqualStrings("test.ts", loc.file);
    try testing.expectEqual(@as(u32, 1), loc.start.line);
    try testing.expectEqual(@as(u32, 0), loc.start.column);
    try testing.expectEqual(@as(u32, 5), loc.end.line);
    try testing.expectEqual(@as(u32, 10), loc.end.column);
}

test "location comparison" {
    const loc1 = types.Location{
        .file = "test.ts",
        .start = .{ .line = 1, .column = 0 },
        .end = .{ .line = 5, .column = 10 },
    };

    const loc2 = types.Location{
        .file = "test.ts",
        .start = .{ .line = 1, .column = 0 },
        .end = .{ .line = 5, .column = 10 },
    };

    const loc3 = types.Location{
        .file = "other.ts",
        .start = .{ .line = 1, .column = 0 },
        .end = .{ .line = 5, .column = 10 },
    };

    try testing.expect(types.Location.eql(loc1, loc2));
    try testing.expect(!types.Location.eql(loc1, loc3));
}

test "position comparison" {
    const pos1 = types.Position{ .line = 10, .column = 5 };
    const pos2 = types.Position{ .line = 10, .column = 5 };
    const pos3 = types.Position{ .line = 10, .column = 6 };

    try testing.expect(types.Position.eql(pos1, pos2));
    try testing.expect(!types.Position.eql(pos1, pos3));
    try testing.expect(types.Position.lessThan(pos1, pos3));
    try testing.expect(!types.Position.lessThan(pos3, pos1));
}
