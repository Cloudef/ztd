pub const BaseCoder = @import("encoding/base_coder.zig").BaseCoder;
pub const base64 = @import("encoding/base64.zig");
pub const base32 = @import("encoding/base32.zig");
pub const base16 = @import("encoding/base16.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
