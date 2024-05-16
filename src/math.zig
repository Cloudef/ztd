const std = @import("std");
const ztd = @import("ztd.zig");

pub const bit = @import("math/bit.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
