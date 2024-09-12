const std = @import("std");
const builtin = @import("builtin");

/// Returns the packed byte size of `T`
pub inline fn packedSizeOf(comptime T: type) usize {
    return std.math.divCeil(usize, @bitSizeOf(T), std.mem.byte_size_in_bits) catch unreachable;
}

test "packedSizeOf" {
    try std.testing.expectEqual(0, packedSizeOf(u0));
    try std.testing.expectEqual(1, packedSizeOf(u1));
    try std.testing.expectEqual(3, packedSizeOf(u24));
    try std.testing.expectEqual(3, packedSizeOf(u20));
}

fn CopyPtrAttrs(
    comptime source: type,
    comptime size: std.builtin.Type.Pointer.Size,
    comptime child: type,
) type {
    const info = @typeInfo(source).pointer;
    return @Type(.{
        .pointer = .{
            .size = size,
            .is_const = info.is_const,
            .is_volatile = info.is_volatile,
            .is_allowzero = info.is_allowzero,
            .alignment = info.alignment,
            .address_space = info.address_space,
            .child = child,
            .sentinel = null,
        },
    });
}

fn AsPackedBytesReturnType(comptime P: type) type {
    const size = packedSizeOf(std.meta.Child(P));
    return CopyPtrAttrs(P, .One, [size]u8);
}

/// Given a pointer to a single item, returns a slice of the underlying bytes, preserving pointer attributes.
pub inline fn asPackedBytes(ptr: anytype) AsPackedBytesReturnType(@TypeOf(ptr)) {
    const len = comptime packedSizeOf(std.meta.Child(@TypeOf(ptr)));
    return std.mem.asBytes(ptr)[0..len];
}

/// Given any value, returns a copy of its bytes in an array tightly packed.
pub inline fn toPackedBytes(value: anytype) [packedSizeOf(@TypeOf(value))]u8 {
    return asPackedBytes(&value).*;
}
