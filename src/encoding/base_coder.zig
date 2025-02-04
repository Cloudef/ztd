const std = @import("std");
const ztd = @import("../ztd.zig");

pub const Error = error{
    InvalidCharacter,
    NoSpaceLeft,
};

/// Generic base encoder / decoder
/// Not tested with other than Base32, but in theory should work :thinking:
pub fn BaseCoder(Impl: type) type {
    ztd.meta.comptimeError(std.math.IntFittingRange(0, Impl.set.len - 1) != Impl.Symbol, "ztd: `Symbol` cannot represent the `set`", .{});
    ztd.meta.comptimeError(@bitSizeOf(Impl.Symbol) > @bitSizeOf(u8), "ztd: `Symbol` larger than u8 is not supported", .{});
    return struct {
        const Symbol = Impl.Symbol;

        /// Returns length of the decoded result
        pub fn decodedLength(comptime T: type, encoded_len: usize) usize {
            return std.math.divFloor(usize, encoded_len * @bitSizeOf(Symbol), @bitSizeOf(T)) catch unreachable;
        }

        /// Decodes single block, expects bytes to have at least ::encodedLength size of T bytes
        /// If you are decoding fixed size types, this is the fastest method
        pub fn decode(comptime T: type, bytes: []const u8) Error!T {
            ztd.meta.comptimeAssertType(T, "ztd", "T", &.{.int});
            @setRuntimeSafety(false);
            const len = comptime encodedLength(u8, @sizeOf(T));
            if (bytes.len < len) return error.NoSpaceLeft;
            var deque = ztd.math.bit.Deque(T, .right){};
            inline for (0..len) |i| deque.push(Symbol, try Impl.lookup(bytes[i])) catch unreachable;
            return deque.as(T, .big);
        }

        /// Decodes single block to a writer
        pub fn decodeToWriter(comptime T: type, bytes: []const u8, writer: anytype) Error!usize {
            try writer.writeAll(std.mem.asBytes(try decode(T, bytes)));
            return @sizeOf(T);
        }

        /// Decodes slice to a writer
        pub fn decodeSliceToWriter(bytes: []const u8, writer: anytype) (Error || @TypeOf(writer).Error)!void {
            var buf = ztd.io.bufferedByteWriter(32, writer);
            var deque = ztd.math.bit.Deque(u16, .right){};
            for (bytes) |b| {
                deque.push(Symbol, try Impl.lookup(b)) catch unreachable;
                while (deque.len >= @bitSizeOf(u8)) {
                    _ = try buf.write(deque.popFirst(u8) catch unreachable);
                }
            }
            // Padding?
            // if (deque.len > 0) {
            //     _ = try buf.write(deque.popFirst(u8) catch unreachable);
            // }
            try buf.flush();
        }

        /// Encodes slice to a out buffer, out must be at least the size of ::decodedLength
        pub fn decodeSlice(bytes: []const u8, out: []u8) Error![]const u8 {
            var stream = std.io.fixedBufferStream(out);
            _ = decodeSliceToWriter(bytes, stream.writer()) catch unreachable;
            return stream.buffer[0..stream.pos];
        }

        /// Encodes slice to a allocated buffer
        pub fn decodeSliceAlloc(allocator: std.mem.Allocator, bytes: []const u8) Error![]const u8 {
            const len = comptime decodedLength(u8, bytes.len);
            const out = allocator.alloc(u8, len);
            return try decodeSlice(bytes, out);
        }

        /// Returns length of the encoded result
        pub fn encodedLength(comptime T: type, bytes_len: usize) usize {
            return (std.math.divCeil(usize, bytes_len * @bitSizeOf(T), @bitSizeOf(Symbol)) catch unreachable);
        }

        /// Encodes single block, expects out to be at least ::encodedLength size
        /// If you are encoding fixed size types, this is the fastest method
        pub fn encode(comptime T: type, in: T, out: []u8) Error![]const u8 {
            ztd.meta.comptimeAssertType(T, "ztd", "T", &.{.int});
            @setRuntimeSafety(false);
            const len = comptime encodedLength(u8, @sizeOf(T));
            if (out.len < len) return error.NoSpaceLeft;
            var deque = ztd.math.bit.Deque(T, .right).init(in, @bitSizeOf(T), .big);
            inline for (0..len) |i| out[i] = Impl.set[deque.popFirst(Symbol) catch unreachable];
            return out[0..len];
        }

        /// Encodes single block to a writer
        pub fn encodeToWriter(comptime T: type, in: T, writer: anytype) (Error || @TypeOf(writer).Error)!usize {
            const len = comptime encodedLength(u8, @sizeOf(T));
            var out: [len]u8 = undefined;
            try writer.writeAll(try encode(T, in, &out));
            return len;
        }

        /// Encodes slice to a writer
        pub fn encodeSliceToWriter(bytes: []const u8, writer: anytype) (Error || @TypeOf(writer).Error)!void {
            var buf = ztd.io.bufferedByteWriter(32, writer);
            var deque = ztd.math.bit.Deque(u16, .right){};
            for (bytes) |b| {
                deque.push(u8, b) catch unreachable;
                while (deque.len >= @bitSizeOf(Symbol)) {
                    _ = try buf.write(Impl.set[deque.popFirst(Symbol) catch unreachable]);
                }
            }
            if (deque.len > 0) {
                _ = try buf.write(Impl.set[deque.popLast(Symbol) catch unreachable]);
            }
            try buf.flush();
        }

        /// Encodes slice to a out buffer, out must be at least the size of ::encodedLength
        pub fn encodeSlice(bytes: []const u8, out: []u8) Error![]const u8 {
            var stream = std.io.fixedBufferStream(out);
            _ = encodeSliceToWriter(bytes, stream.writer()) catch unreachable;
            return stream.buffer[0..stream.pos];
        }

        /// Encodes slice to a allocated buffer
        pub fn encodeSliceAlloc(allocator: std.mem.Allocator, bytes: []const u8) Error![]const u8 {
            const len = comptime encodedLength(u8, bytes.len);
            const out = allocator.alloc(u8, len);
            return try encodeSlice(bytes, out);
        }

        pub fn formatEncodeSlice(bytes: []const u8, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            return encodeSliceToWriter(bytes, writer);
        }

        pub fn fmtEncodeSlice(bytes: []const u8) std.fmt.Formatter(formatEncodeSlice) {
            return .{ .data = bytes };
        }
    };
}

test "base32 encode" {
    const crockford = @import("base32.zig").crockford;
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
