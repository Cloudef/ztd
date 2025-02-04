const std = @import("std");
const base_coder = @import("base_coder.zig");
const BaseCoder = base_coder.BaseCoder;

pub const Error = base_coder.Error;

pub const CrockfordImpl = struct {
    pub const Symbol = u5;
    pub const set = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
    pub fn lookup(c: u8) Error!Symbol {
        return @intCast(switch (c) {
            '0', 'O', 'o' => 0,
            '1', 'I', 'i', 'L', 'l' => 1,
            '2'...'9' => |i| i - '0',
            'A'...'H' => |i| i - 'A' + 10,
            'a'...'h' => |i| i - 'a' + 10,
            'J'...'K' => |i| i - 'J' + 18,
            'j'...'k' => |i| i - 'j' + 18,
            'M'...'N' => |i| i - 'M' + 20,
            'm'...'n' => |i| i - 'm' + 20,
            'P'...'T' => |i| i - 'P' + 22,
            'p'...'t' => |i| i - 'p' + 22,
            'V'...'Z' => |i| i - 'V' + 27,
            'v'...'z' => |i| i - 'v' + 27,
            // Accidental obscenity
            'U', 'u' => return error.InvalidCharacter,
            else => return error.InvalidCharacter,
        });
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
    try std.testing.expectEqual(std.mem.bytesToValue(u16, "fu"), try crockford.decode(u16, "CSTG"));
    try std.testing.expectEqualSlices(u8, "CSTG", try crockford.encodeSlice("fu", &enc));
    try std.testing.expectEqualSlices(u8, "fu", try crockford.decodeSlice("CSTG", &enc));
    try std.testing.expectEqualSlices(u8, "CSQPYRK1E8", try crockford.encodeSlice("foobar", &enc));
    try std.testing.expectEqualSlices(u8, "91JPRV3F5GG7EVVJDHJ22", try crockford.encodeSlice("Hello, world!", &enc));
    try std.testing.expectEqualSlices(u8, "AHM6A83HENMP6TS0C9S6YXVE41K6YY10D9TPTW3K41QQCSBJ41T6GS90DHGQMY90CHQPEBG", try crockford.encodeSlice("The quick brown fox jumps over the lazy dog.", &enc));
    try std.testing.expectEqualSlices(u8, "foobar", try crockford.decodeSlice("CSQPYRK1E8", &enc));
    try std.testing.expectEqualSlices(u8, "Hello, world!", try crockford.decodeSlice("91JPRV3F5GG7EVVJDHJ22", &enc));
    try std.testing.expectEqualSlices(u8, "The quick brown fox jumps over the lazy dog.", try crockford.decodeSlice("AHM6A83HENMP6TS0C9S6YXVE41K6YY10D9TPTW3K41QQCSBJ41T6GS90DHGQMY90CHQPEBG", &enc));
}

pub const Rfc4648Impl = struct {
    pub const Symbol = u5;
    pub const set = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    pub fn lookup(c: u8) Error!Symbol {
        return @intCast(switch (c) {
            'A'...'Z' => |i| i - 'A',
            'a'...'z' => |i| i - 'a',
            '2'...'7' => |i| i - '2' + 26,
            else => return error.InvalidCharacter,
        });
    }
};

/// RFC4648 §6
pub const rfc4648 = BaseCoder(Rfc4648Impl);

test "rfc4648" {
    var enc: [1024]u8 = undefined;
    try std.testing.expectEqual(5, comptime rfc4648.encodedLength(u8, "foo".len));
    try std.testing.expectEqual("foo".len, comptime rfc4648.decodedLength(u8, 5));
    try std.testing.expectEqualSlices(u8, "MY", try rfc4648.encode(u8, 'f', &enc));
    try std.testing.expectEqual('f', try rfc4648.decode(u8, "MY"));
    try std.testing.expectEqualSlices(u8, "MZXQ", try rfc4648.encode(u16, std.mem.bytesToValue(u16, "fo"), &enc));
    try std.testing.expectEqual(std.mem.bytesToValue(u16, "fo"), try rfc4648.decode(u16, "MZXQ"));
    try std.testing.expectEqualSlices(u8, "MZXW6", try rfc4648.encodeSlice("foo", &enc));
    try std.testing.expectEqualSlices(u8, "foo", try rfc4648.decodeSlice("MZXW6", &enc));
    try std.testing.expectEqualSlices(u8, "MZXW6YQ", try rfc4648.encodeSlice("foob", &enc));
    try std.testing.expectEqualSlices(u8, "foob", try rfc4648.decodeSlice("MZXW6YQ", &enc));
    try std.testing.expectEqualSlices(u8, "MZXW6YTB", try rfc4648.encodeSlice("fooba", &enc));
    try std.testing.expectEqualSlices(u8, "fooba", try rfc4648.decodeSlice("MZXW6YTB", &enc));
    try std.testing.expectEqualSlices(u8, "MZXW6YTBOI", try rfc4648.encodeSlice("foobar", &enc));
    try std.testing.expectEqualSlices(u8, "foobar", try rfc4648.decodeSlice("MZXW6YTBOI", &enc));
}

pub const Rfc4648HexImpl = struct {
    pub const Symbol = u5;
    pub const set = "0123456789ABCDEFGHIJKLMNOPQRSTUV";
    pub fn lookup(c: u8) Error!Symbol {
        return @intCast(switch (c) {
            '0'...'9' => |i| i - '0',
            'A'...'V' => |i| i - 'A' + 10,
            'a'...'v' => |i| i - 'a' + 10,
            else => return error.InvalidCharacter,
        });
    }
};

/// RFC4648 §7
pub const rfc4648hex = BaseCoder(Rfc4648HexImpl);

test "rfc4648hex" {
    var enc: [1024]u8 = undefined;
    try std.testing.expectEqual(5, comptime rfc4648hex.encodedLength(u8, "foo".len));
    try std.testing.expectEqual("foo".len, comptime rfc4648hex.decodedLength(u8, 5));
    try std.testing.expectEqualSlices(u8, "CO", try rfc4648hex.encode(u8, 'f', &enc));
    try std.testing.expectEqual('f', try rfc4648hex.decode(u8, "CO"));
    try std.testing.expectEqualSlices(u8, "CPNG", try rfc4648hex.encode(u16, std.mem.bytesToValue(u16, "fo"), &enc));
    try std.testing.expectEqual(std.mem.bytesToValue(u16, "fo"), try rfc4648hex.decode(u16, "CPNG"));
    try std.testing.expectEqualSlices(u8, "CPNMU", try rfc4648hex.encodeSlice("foo", &enc));
    try std.testing.expectEqualSlices(u8, "foo", try rfc4648hex.decodeSlice("CPNMU", &enc));
    try std.testing.expectEqualSlices(u8, "CPNMUOG", try rfc4648hex.encodeSlice("foob", &enc));
    try std.testing.expectEqualSlices(u8, "foob", try rfc4648hex.decodeSlice("CPNMUOG", &enc));
    try std.testing.expectEqualSlices(u8, "CPNMUOJ1", try rfc4648hex.encodeSlice("fooba", &enc));
    try std.testing.expectEqualSlices(u8, "fooba", try rfc4648hex.decodeSlice("CPNMUOJ1", &enc));
    try std.testing.expectEqualSlices(u8, "CPNMUOJ1E8", try rfc4648hex.encodeSlice("foobar", &enc));
    try std.testing.expectEqualSlices(u8, "foobar", try rfc4648hex.decodeSlice("CPNMUOJ1E8", &enc));
}
