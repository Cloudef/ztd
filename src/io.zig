pub const BufferedByteWriter = @import("io/buffered_byte_writer.zig").BufferedByteWriter;
pub const bufferedByteWriter = @import("io/buffered_byte_writer.zig").bufferedByteWriter;

test {
    @import("std").testing.refAllDecls(@This());
}
