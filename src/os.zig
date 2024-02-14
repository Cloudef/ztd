pub const OsRelease = @import("os/OsRelease.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
