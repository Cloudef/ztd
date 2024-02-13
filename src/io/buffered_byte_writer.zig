const std = @import("std");

pub fn BufferedByteWriter(comptime buffer_size: usize, comptime WriterType: type) type {
    return struct {
        unbuffered_writer: WriterType,
        buf: [buffer_size]u8 = undefined,
        end: usize = 0,

        pub const Error = WriterType.Error;
        pub const Writer = std.io.Writer(*Self, Error, write);

        const Self = @This();

        pub fn flush(self: *Self) !void {
            try self.unbuffered_writer.writeAll(self.buf[0..self.end]);
            self.end = 0;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        pub fn write(self: *Self, byte: u8) Error!usize {
            if (self.end == self.buf.len) try self.flush();
            self.buf[self.end] = byte;
            self.end += 1;
            return 1;
        }
    };
}

pub fn bufferedByteWriter(comptime buffer_size: usize, underlying_stream: anytype) BufferedByteWriter(buffer_size, @TypeOf(underlying_stream)) {
    return .{ .unbuffered_writer = underlying_stream };
}
