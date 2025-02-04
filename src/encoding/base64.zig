const std = @import("std");
const base_coder = @import("base_coder.zig");
const BaseCoder = base_coder.BaseCoder;

pub const Error = base_coder.Error;

pub const Rfc4648Impl = struct {
    pub const Symbol = u6;
    pub const set = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    pub fn lookup(c: u8) Error!Symbol {
        return @intCast(switch (c) {
            'A'...'Z' => |i| i - 'A',
            'a'...'z' => |i| i - 'a' + 26,
            '0'...'9' => |i| i - '0' + 52,
            '+' => 62,
            '/' => 63,
            else => return error.InvalidCharacter,
        });
    }
};

/// RFC4648 §4
pub const rfc4648 = BaseCoder(Rfc4648Impl);

test "rfc4648" {
    var enc: [1024]u8 = undefined;
    try std.testing.expectEqual(4, comptime rfc4648.encodedLength(u8, "foo".len));
    try std.testing.expectEqual("foo".len, comptime rfc4648.decodedLength(u8, 4));
    try std.testing.expectEqualSlices(u8, "Zg", try rfc4648.encode(u8, 'f', &enc));
    try std.testing.expectEqual('f', try rfc4648.decode(u8, "Zg"));
    try std.testing.expectEqualSlices(u8, "Zm8", try rfc4648.encode(u16, std.mem.bytesToValue(u16, "fo"), &enc));
    try std.testing.expectEqual(std.mem.bytesToValue(u16, "fo"), try rfc4648.decode(u16, "Zm8"));
    try std.testing.expectEqualSlices(u8, "Zm9v", try rfc4648.encodeSlice("foo", &enc));
    try std.testing.expectEqualSlices(u8, "foo", try rfc4648.decodeSlice("Zm9v", &enc));
    try std.testing.expectEqualSlices(u8, "Zm9vYg", try rfc4648.encodeSlice("foob", &enc));
    try std.testing.expectEqualSlices(u8, "foob", try rfc4648.decodeSlice("Zm9vYg", &enc));
    try std.testing.expectEqualSlices(u8, "Zm9vYmE", try rfc4648.encodeSlice("fooba", &enc));
    try std.testing.expectEqualSlices(u8, "fooba", try rfc4648.decodeSlice("Zm9vYmE", &enc));
    try std.testing.expectEqualSlices(u8, "Zm9vYmFy", try rfc4648.encodeSlice("foobar", &enc));
    try std.testing.expectEqualSlices(u8, "foobar", try rfc4648.decodeSlice("Zm9vYmFy", &enc));
}

pub const Rfc4648UrlImpl = struct {
    pub const Symbol = u6;
    pub const set = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
    pub fn lookup(c: u8) Error!Symbol {
        return @intCast(switch (c) {
            'A'...'Z' => |i| i - 'A',
            'a'...'z' => |i| i - 'a' + 26,
            '0'...'9' => |i| i - '0' + 52,
            '-' => 62,
            '_' => 63,
            else => return error.InvalidCharacter,
        });
    }
};

/// RFC4648 §5
pub const rfc4648url = BaseCoder(Rfc4648UrlImpl);

test "rfc4648url" {
    var enc: [1024]u8 = undefined;
    try std.testing.expectEqual(4, comptime rfc4648url.encodedLength(u8, "foo".len));
    try std.testing.expectEqual("foo".len, comptime rfc4648url.decodedLength(u8, 4));
    try std.testing.expectEqualSlices(u8, "Zg", try rfc4648url.encode(u8, 'f', &enc));
    try std.testing.expectEqual('f', try rfc4648url.decode(u8, "Zg"));
    try std.testing.expectEqualSlices(u8, "Zm8", try rfc4648url.encode(u16, std.mem.bytesToValue(u16, "fo"), &enc));
    try std.testing.expectEqual(std.mem.bytesToValue(u16, "fo"), try rfc4648url.decode(u16, "Zm8"));
    try std.testing.expectEqualSlices(u8, "Zm9v", try rfc4648url.encodeSlice("foo", &enc));
    try std.testing.expectEqualSlices(u8, "foo", try rfc4648url.decodeSlice("Zm9v", &enc));
    try std.testing.expectEqualSlices(u8, "Zm9vYg", try rfc4648url.encodeSlice("foob", &enc));
    try std.testing.expectEqualSlices(u8, "foob", try rfc4648url.decodeSlice("Zm9vYg", &enc));
    try std.testing.expectEqualSlices(u8, "Zm9vYmE", try rfc4648url.encodeSlice("fooba", &enc));
    try std.testing.expectEqualSlices(u8, "fooba", try rfc4648url.decodeSlice("Zm9vYmE", &enc));
    try std.testing.expectEqualSlices(u8, "Zm9vYmFy", try rfc4648url.encodeSlice("foobar", &enc));
    try std.testing.expectEqualSlices(u8, "foobar", try rfc4648url.decodeSlice("Zm9vYmFy", &enc));
}
