const std = @import("std");

const lang = @import("lang.zig");

const Token = struct {
    pos: u64,
};

pub fn lex(alloc: std.mem.Allocator, text: []const u8) !std.ArrayList(Token) {
    var tokens = std.ArrayList(Token).init(alloc);

    try tokens.append(Token{ .pos = 3 });

    _ = text;

    return tokens;
}

test "lexing" {
    const text =
        \\one
    ;

    var tokens = try lex(std.heap.page_allocator, text);
    defer tokens.deinit();
}
