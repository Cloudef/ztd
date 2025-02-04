const std = @import("std");
const base_coder = @import("base_coder.zig");
const BaseCoder = base_coder.BaseCoder;

pub const Error = base_coder.Error;

pub const Rfc4648Impl = struct {
    pub const Symbol = u4;
    pub const set = "0123456789ABCDEF";
    pub fn lookup(c: u8) Error!Symbol {
        return @intCast(switch (c) {
            '0'...'9' => |i| i - '0',
            'A'...'F' => |i| i - 'A' + 10,
            'a'...'f' => |i| i - 'a' + 10,
            else => return error.InvalidCharacter,
        });
    }
};

/// RFC4648 §8
pub const rfc4648 = BaseCoder(Rfc4648Impl);

test "rfc4648" {
    var enc: [1024]u8 = undefined;
    try std.testing.expectEqual(6, comptime rfc4648.encodedLength(u8, "foo".len));
    try std.testing.expectEqual("foo".len, comptime rfc4648.decodedLength(u8, 6));
    try std.testing.expectEqualSlices(u8, "66", try rfc4648.encode(u8, 'f', &enc));
    try std.testing.expectEqual('f', try rfc4648.decode(u8, "66"));
    try std.testing.expectEqualSlices(u8, "666F", try rfc4648.encode(u16, std.mem.bytesToValue(u16, "fo"), &enc));
    try std.testing.expectEqual(std.mem.bytesToValue(u16, "fo"), try rfc4648.decode(u16, "666F"));
    try std.testing.expectEqualSlices(u8, "666F6F", try rfc4648.encodeSlice("foo", &enc));
    try std.testing.expectEqualSlices(u8, "foo", try rfc4648.decodeSlice("666F6F", &enc));
    try std.testing.expectEqualSlices(u8, "666F6F62", try rfc4648.encodeSlice("foob", &enc));
    try std.testing.expectEqualSlices(u8, "foob", try rfc4648.decodeSlice("666F6F62", &enc));
    try std.testing.expectEqualSlices(u8, "666F6F6261", try rfc4648.encodeSlice("fooba", &enc));
    try std.testing.expectEqualSlices(u8, "fooba", try rfc4648.decodeSlice("666F6F6261", &enc));
    try std.testing.expectEqualSlices(u8, "666F6F626172", try rfc4648.encodeSlice("foobar", &enc));
    try std.testing.expectEqualSlices(u8, "foobar", try rfc4648.decodeSlice("666F6F626172", &enc));
}
