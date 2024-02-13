const std = @import("std");
const builtin = @import("builtin");

/// Returns the byte size of `T`
/// If `T` is smaller than a byte, this will return 1
pub inline fn byteSizeOf(comptime T: type) usize {
    return std.math.divCeil(usize, @max(@bitSizeOf(T), std.mem.byte_size_in_bits), std.mem.byte_size_in_bits) catch unreachable;
}

test "byteSizeOf" {
    try std.testing.expectEqual(1, byteSizeOf(u1));
    try std.testing.expectEqual(3, byteSizeOf(u24));
    try std.testing.expectEqual(3, byteSizeOf(u20));
}

/// Given any value, returns a copy of its bytes in an array tightly packed.
pub inline fn toPackedBytes(v: anytype) [byteSizeOf(@TypeOf(v))]u8 {
    const len = comptime byteSizeOf(@TypeOf(v));
    var bytes: [len]u8 = undefined;
    @memcpy(&bytes, std.mem.asBytes(&v)[0..len]);
    return bytes;
}
