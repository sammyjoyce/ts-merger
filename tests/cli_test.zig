const std = @import("std");
const testing = std.testing;
const cli = @import("cli");

test "parse help command" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Mock args
    const args = [_][]const u8{ "fuze", "--help" };
    var config = try cli.parseArgs(allocator, &args);
    defer config.deinit(allocator);

    try testing.expect(config.show_help);
}

test "parse watch command" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Mock args
    const args = [_][]const u8{ "fuze", "watch", "-r", "-v", "src" };
    var config = try cli.parseArgs(allocator, &args);
    defer config.deinit(allocator);

    try testing.expectEqual(cli.Command.watch, config.command);
    try testing.expect(config.recursive);
    try testing.expect(config.verbose);
    try testing.expectEqual(@as(usize, 1), config.source_paths.len);
    try testing.expectEqualStrings("src", config.source_paths[0]);
}

test "parse merge command" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Mock args
    const args = [_][]const u8{ "fuze", "merge", "-t", "dist/output.ts", "src/a.ts", "src/b.ts" };
    var config = try cli.parseArgs(allocator, &args);
    defer config.deinit(allocator);

    try testing.expectEqual(cli.Command.merge, config.command);
    try testing.expectEqual(@as(usize, 2), config.source_paths.len);
    try testing.expectEqualStrings("src/a.ts", config.source_paths[0]);
    try testing.expectEqualStrings("src/b.ts", config.source_paths[1]);
    try testing.expectEqualStrings("dist/output.ts", config.target_path.?);
}

test "parse invalid command" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Mock args
    const args = [_][]const u8{ "fuze", "invalid" };
    try testing.expectError(error.UnknownCommand, cli.parseArgs(allocator, &args));
}

test "parse missing target" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Mock args
    const args = [_][]const u8{ "fuze", "merge", "src/a.ts" };
    try testing.expectError(error.NoTargetPath, cli.parseArgs(allocator, &args));
}

test "parse invalid watch delay" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Mock args
    const args = [_][]const u8{ "fuze", "watch", "-d", "invalid", "src" };
    try testing.expectError(error.InvalidNumber, cli.parseArgs(allocator, &args));
}
