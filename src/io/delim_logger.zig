const std = @import("std");

pub const Delim = union(enum) {
    scalar: u8,
    sequence: []const u8,
    any: []const u8,
};

pub const LogFn = fn (comptime fmt: []const u8, args: anytype) void;

pub fn DelimLogger(
    comptime buffer_size: usize,
    comptime delim: Delim,
    comptime log_fn: LogFn,
) type {
    return struct {
        pub const Error = error{Overflow};
        pub const Writer = std.io.GenericWriter(*@This(), Error, write);
        bounded: std.BoundedArray(u8, buffer_size) = .{},

        pub fn write(self: *@This(), bytes: []const u8) Error!usize {
            errdefer self.bounded.len = 0;
            try self.bounded.appendSlice(bytes);
            var end: usize = 0;
            var iter = switch (delim) {
                .scalar => |d| std.mem.tokenizeScalar(u8, self.bounded.constSlice(), d),
                .sequence => |d| std.mem.tokenize(u8, self.bounded.constSlice(), d),
                .any => |d| std.mem.tokenizeAny(u8, self.bounded.constSlice(), d),
            };
            while (iter.next()) |buf| {
                // check if the msg ends in \n, if not continue
                if (iter.index == self.bounded.len) continue;
                log_fn("{s}", .{buf});
                end = iter.index;
            }
            if (end > 0) {
                const left = self.bounded.len - end;
                std.mem.copyBackwards(u8, self.bounded.slice()[0..left], self.bounded.slice()[end..]);
                self.bounded.len = @intCast(left);
            }
            return bytes.len;
        }

        pub fn writer(self: *@This()) Writer {
            return .{ .context = self };
        }
    };
}

pub fn delimLogger(comptime buffer_size: usize, comptime delim: Delim, comptime log_fn: LogFn) DelimLogger(buffer_size, delim, log_fn) {
    return .{};
}

pub fn NewlineLogger(comptime buffer_size: usize, comptime log_fn: LogFn) type {
    return DelimLogger(buffer_size, .{ .scalar = '\n' }, log_fn);
}

pub fn newlineLogger(comptime buffer_size: usize, comptime log_fn: LogFn) NewlineLogger(buffer_size, log_fn) {
    return .{};
}
