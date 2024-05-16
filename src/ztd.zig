pub const meta = @import("meta.zig");
pub const bind = @import("bind.zig");
pub const unsafe = @import("unsafe.zig");
pub const encoding = @import("encoding.zig");
pub const mem = @import("mem.zig");
pub const math = @import("math.zig");
pub const io = @import("io.zig");
pub const os = @import("os.zig");

const root = @import("root");
const std = @import("std");

/// ztd-wide options that can be overridden by the root file.
pub const options: Options = if (@hasDecl(root, "ztd_options")) root.ztd_options else .{};

pub const Options = struct {
    setenv_allocator: std.mem.Allocator = std.heap.page_allocator,
    bit_deque_debug: bool = false,
};


test {
    @import("std").testing.refAllDecls(@This());
}
