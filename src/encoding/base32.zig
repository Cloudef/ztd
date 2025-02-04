const std = @import("std");
const base_coder = @import("base_coder.zig");
const BaseCoder = base_coder.BaseCoder;

pub const Error = base_coder.Error;

pub const CrockfordImpl = struct {
    pub const Symbol = u5;
    pub const set = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
    pub fn lookup(c: u8) Error!Symbol {
        return switch (c) {
            inline '0', 'O', 'o' => 0,
            inline '1', 'I', 'i', 'L', 'l' => 1,
            inline '2'...'9' => |i| i - '0',
            inline 'A'...'H' => |i| i - 'A' + 10,
            inline 'a'...'h' => |i| i - 'a' + 10,
            inline 'J'...'K' => |i| i - 'J' + 18,
            inline 'j'...'k' => |i| i - 'j' + 18,
            inline 'M'...'N' => |i| i - 'M' + 20,
            inline 'm'...'n' => |i| i - 'm' + 20,
            inline 'P'...'T' => |i| i - 'P' + 22,
            inline 'p'...'t' => |i| i - 'p' + 22,
            inline 'V'...'Z' => |i| i - 'V' + 27,
            inline 'v'...'z' => |i| i - 'v' + 27,
            // Accidental obscenity
            inline 'U', 'u' => error.InvalidCharacter,
            inline else => error.InvalidCharacter,
        };
    }
};

/// NOTE: This only supports subset of crockford
///       - Hyphens are not allowed
///       - No check symbols
/// https://www.crockford.com/base32.html
pub const crockford = BaseCoder(CrockfordImpl);

/// The superset of crockford is exactly as clockwork
/// However there is no support for encoding to lowercase
/// https://gist.github.com/szktty/228f85794e4187882a77734c89c384a8
pub const clockwork = crockford;

test "crockford" {
    var enc: [1024]u8 = undefined;
    try std.testing.expectEqual(5, comptime crockford.encodedLength(u8, "moi".len));
    try std.testing.expectEqual("moi".len, comptime crockford.decodedLength(u8, 5));
    try std.testing.expectEqualSlices(u8, "CR", try crockford.encode(u8, 'f', &enc));
    try std.testing.expectEqual('f', try crockford.decode(u8, "CR"));
    try std.testing.expectEqualSlices(u8, "CSTG", try crockford.encode(u16, std.mem.bytesToValue(u16, "fu"), &enc));
    try std.testing.expectEqualSlices(u8, "CSTG", try crockford.encodeSlice("fu", &enc));
    try std.testing.expectEqual(std.mem.bytesToValue(u16, "fu"), try crockford.decode(u16, "CSTG"));
    try std.testing.expectEqualSlices(u8, "fu", try crockford.decodeSlice("CSTG", &enc));
    try std.testing.expectEqualSlices(u8, "CSQPYRK1E8", try crockford.encodeSlice("foobar", &enc));
    try std.testing.expectEqualSlices(u8, "91JPRV3F5GG7EVVJDHJ22", try crockford.encodeSlice("Hello, world!", &enc));
    try std.testing.expectEqualSlices(u8, "AHM6A83HENMP6TS0C9S6YXVE41K6YY10D9TPTW3K41QQCSBJ41T6GS90DHGQMY90CHQPEBG", try crockford.encodeSlice("The quick brown fox jumps over the lazy dog.", &enc));
    try std.testing.expectEqualSlices(u8, "foobar", try crockford.decodeSlice("CSQPYRK1E8", &enc));
    try std.testing.expectEqualSlices(u8, "Hello, world!", try crockford.decodeSlice("91JPRV3F5GG7EVVJDHJ22", &enc));
    try std.testing.expectEqualSlices(u8, "The quick brown fox jumps over the lazy dog.", try crockford.decodeSlice("AHM6A83HENMP6TS0C9S6YXVE41K6YY10D9TPTW3K41QQCSBJ41T6GS90DHGQMY90CHQPEBG", &enc));
}
