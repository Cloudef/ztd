const std = @import("std");
const ztd = @import("ztd.zig");

pub const bit = @import("math/bit.zig");

/// Returns Tⁿ of unsigned integer type
/// NOTE: If T is u1 returns u<n> instead
pub inline fn PowInt(comptime T: type, comptime n: comptime_int) type {
    ztd.meta.comptimeAssertTypeSignedness(T, "ztd", "n", .unsigned);
    ztd.meta.comptimeError(n <= 0, "ztd: `n` must be larger than 0", .{});
    if (T == u1) {
        return comptime std.math.IntFittingRange(0, 1 << (n - 1));
    } else {
        return comptime std.math.IntFittingRange(0, std.math.powi(u256, std.math.maxInt(T), n) catch unreachable);
    }
}

test "PowInt" {
    try std.testing.expectEqual(u2, PowInt(u1, 2));
    try std.testing.expectEqual(u4, PowInt(u2, 2));
    try std.testing.expectEqual(u10, PowInt(u5, 2));
    try std.testing.expectEqual(u16, PowInt(u8, 2));
    try std.testing.expectEqual(u64, PowInt(u32, 2));
    try std.testing.expectEqual(u32, PowInt(u8, 4));
}

test {
    @import("std").testing.refAllDecls(@This());
}
