const std = @import("std");
const builtin = @import("builtin");
const ztd = @import("../ztd.zig");
const private = @import("../private.zig");
const byteSizeOf = ztd.mem.byteSizeOf;

/// Returns a type that can index the `T`'s 'range of bits [0..nbits - 1]
pub const Index = std.math.Log2Int;

test "Index" {
    try std.testing.expectEqual(u1, Index(u2));
    try std.testing.expectEqual(u3, Index(u8));
    try std.testing.expectEqual(u5, Index(u32));
}

/// Returns a type that can represent the amount of bits [0..nbits]
pub const Count = std.math.Log2IntCeil;

test "Count" {
    try std.testing.expectEqual(u1, Count(u1));
    try std.testing.expectEqual(u2, Count(u2));
    try std.testing.expectEqual(u4, Count(u8));
    try std.testing.expectEqual(u6, Count(u32));
}

pub const RangeError = error{
    InvalidRange,
};

/// Extracts range of bits from `T`
pub inline fn extractRange(comptime T: type, v: T, start: Index(T), end: Index(T)) RangeError!T {
    ztd.meta.comptimeAssertType(T, "ztd", "T", &.{ .Int, .ComptimeInt });
    @setRuntimeSafety(false);
    if (start > end) return error.InvalidRange;
    const mask = ((@as(T, 1) << end) - 1) << start;
    return (v & mask) >> start;
}

pub const ExtractError = error{
    NoSpaceLeft,
} || RangeError;

/// Extracts `E` from `T` with offset specified by `off`, the result is truncated if `E` is smaller than `T`
pub inline fn extract(comptime T: type, v: T, E: type, off: Count(T)) ExtractError!E {
    ztd.meta.comptimeError(@bitSizeOf(E) > @bitSizeOf(T), "ztd: `E` is larger than `T`", .{});
    @setRuntimeSafety(false);
    if (off == 0 and @bitSizeOf(E) == @bitSizeOf(T)) return v;
    if (@bitSizeOf(T) - @as(Count(T), off) < @bitSizeOf(E)) return error.NoSpaceLeft;
    const end: Index(E) = @min(std.math.maxInt(Index(E)), off + @bitSizeOf(E));
    return @truncate(try extractRange(T, v, off, end));
}

/// Extracts `E` from `T` as bytes with offset specified by `off`
pub inline fn extractBytes(comptime T: type, v: T, E: type, off: Count(T)) ExtractError![byteSizeOf(E)]u8 {
    return ztd.mem.toPackedBytes(try extract(T, v, E, off));
}

pub const DequeError = RangeError || ExtractError;

pub const Direction = enum {
    left,
    right,
};

/// Deque backed by a `BackingInt`
/// `head` determines which end of the bit pattern is the first element
/// E.g. If one element was pushed to `Deque` the result would look like:
/// head: .left
/// [*] 10101010 00000000
/// head: .right
///     00000000 10101010 [*]
pub fn Deque(BackingInt: type, head: Direction) type {
    ztd.meta.comptimeAssertTypeSignedness(BackingInt, "ztd", "BackingInt", .unsigned);
    const BackingIndex = Index(BackingInt);
    const BackingCount = Count(BackingInt);
    return struct {
        const DebugOps = private.opt(bool, false, ".bit_deque_debug");
        const Len = BackingCount;
        comptime capacity: BackingCount = @bitSizeOf(BackingInt),
        comptime range: BackingIndex = @bitSizeOf(BackingInt) - 1,
        len: BackingCount = 0,
        value: BackingInt = 0,

        /// Init the deque, it is not neccessary to call this.
        /// You must set the `len` correctly, as it can't be understood from the `initial` value alone.
        /// If `endianess` is not the same as native endianess the value will be byte swapped
        /// That is `endianess` indicates the endianess of the `BackingInt` not the endianess `Queue` operates in
        pub inline fn init(initial: BackingInt, len: BackingCount, endianess: std.builtin.Endian) @This() {
            if (endianess != comptime builtin.target.cpu.arch.endian()) {
                return .{ .value = @byteSwap(initial), .len = len };
            } else {
                return .{ .value = initial, .len = len };
            }
        }

        /// Empties the deque
        pub inline fn clear(self: *@This()) void {
            self.* = .{};
        }

        /// Returns index counted backwards from the capacity of the `Deque`
        /// This is a convience method that avoids having to @truncate() everywhere
        pub inline fn tailIndex(self: @This(), off: BackingCount) BackingIndex {
            return @truncate(self.capacity - off);
        }

        /// Raw variant of the push without type safety
        /// Useful when need to align pushes based on runtime variables
        pub inline fn rawPush(self: *@This(), bitsz: BackingIndex, v: anytype) DequeError!void {
            ztd.meta.comptimeAssertValueType(v, "ztd", "T", &.{ .Int, .ComptimeInt });
            @setRuntimeSafety(false);
            if (self.len == self.capacity) return error.NoSpaceLeft;
            switch (head) {
                .right => {
                    const free = self.capacity - self.len;
                    if (free < bitsz) {
                        const shrinked: @TypeOf(v) = v >> @truncate(bitsz - free);
                        self.value <<= @truncate(free);
                        self.value |= shrinked;
                    } else {
                        self.value <<= bitsz;
                        self.value |= v;
                    }
                    ztd.meta.debug(DebugOps, "<< {}", .{self});
                },
                .left => {
                    const free = self.capacity - self.len;
                    if (free < bitsz) {
                        const shrinked: @TypeOf(v) = v >> @truncate(bitsz - free);
                        self.value >>= @truncate(free);
                        self.value |= @as(BackingInt, shrinked) << self.tailIndex(free);
                    } else {
                        self.value >>= bitsz;
                        self.value |= @as(BackingInt, v) << self.tailIndex(bitsz);
                    }
                    ztd.meta.debug(DebugOps, ">> {}", .{self});
                },
            }
            self.len += @min(bitsz, self.capacity - self.len);
        }

        /// Pushes `T` into the `Deque`
        /// If push would overflow then `T` will be truncated to fit the remaining space
        /// Trying to push into a full deque returns error
        /// E.g. If empty `Deque` is backed by `u16` and `T` is `u8`, the result would look like:
        /// head: .left
        /// push: 10101010 00000000
        /// push: 11111111 10101010
        /// head: .right
        /// push: 00000000 10101010
        /// push: 10101010 11111111
        pub inline fn push(self: *@This(), T: type, v: T) DequeError!void {
            ztd.meta.comptimeError(@bitSizeOf(T) >= self.capacity, "ztd: `T` must be smaller than `BackingInt`", .{});
            return self.rawPush(@bitSizeOf(T), v);
        }

        /// When thinking about front and back, don't think in terms of bits
        /// Think in terms of the API this `Deque` struct exposes
        /// That is front is front of the queue and back is back of the queue
        inline fn internalPop(self: *@This(), T: type, bitsz: BackingIndex, comptime front: bool) DequeError!T {
            @setRuntimeSafety(false);
            if (self.len == 0) return error.NoSpaceLeft;
            var ret: T = undefined;
            if (front) {
                switch (head) {
                    .right => {
                        if (bitsz >= self.len) {
                            const widen: BackingIndex = @truncate(bitsz - self.len);
                            ret = @truncate(self.value << widen);
                            self.value = 0;
                        } else {
                            const start: BackingIndex = @truncate(self.len - bitsz);
                            ret = @truncate(self.value >> start);
                            const shift: BackingIndex = self.tailIndex(start);
                            self.value <<= shift;
                            self.value >>= shift;
                        }
                        ztd.meta.debug(DebugOps, "PF {}", .{self});
                    },
                    .left => {
                        const shift: BackingIndex = self.tailIndex(self.len);
                        if (bitsz >= self.len) {
                            const widen: BackingIndex = @truncate(bitsz - self.len);
                            ret = @truncate((self.value >> shift) << widen);
                            self.value = 0;
                        } else {
                            ret = @truncate(self.value >> shift);
                            self.value >>= shift + bitsz;
                            self.value <<= shift + bitsz;
                        }
                        ztd.meta.debug(DebugOps, "PF {}", .{self});
                    },
                }
            } else {
                switch (head) {
                    .right => {
                        if (bitsz >= self.len) {
                            const widen: BackingIndex = @truncate(bitsz - self.len);
                            ret = @truncate(self.value << widen);
                            self.value = 0;
                        } else {
                            ret = @truncate((self.value << bitsz) >> bitsz);
                            self.value >>= bitsz;
                        }
                        ztd.meta.debug(DebugOps, "PB {}", .{self});
                    },
                    .left => {
                        if (bitsz >= self.len) {
                            const widen: BackingIndex = @truncate(bitsz - self.len);
                            ret = @truncate((self.value >> self.tailIndex(self.len)) << widen);
                            self.value = 0;
                        } else {
                            ret = @truncate(self.value >> self.tailIndex(bitsz));
                            self.value <<= bitsz;
                        }
                        ztd.meta.debug(DebugOps, "PB {}", .{self});
                    },
                }
            }
            self.len -= @min(bitsz, self.len);
            return ret;
        }

        /// Raw variant of the front pop without type safety
        /// Useful when need to align pops based on runtime variables
        pub inline fn rawPopFront(self: *@This(), T: type, bitsz: BackingIndex) DequeError!T {
            return self.internalPop(T, bitsz, true);
        }

        /// Raw variant of the back pop without type safety
        /// Useful when need to align pops based on runtime variables
        pub inline fn rawPopBack(self: *@This(), T: type, bitsz: BackingIndex) DequeError!T {
            return self.internalPop(T, bitsz, false);
        }

        /// Pops `T` from front of the `Deque`
        /// If pop would overflow, then the result will be widened to `@bitSizeOf(T)` and deque becomes empty
        /// Trying to pop from a empty deque returns error
        /// E.g. If empty `Deque` is backed by `u16` and `T` is `u8`, the result would look like:
        /// head: .right
        /// pop: 11111111 10101010
        /// pop: 00000000 11111111
        /// head: .left
        /// pop: 11111111 10101010
        /// pop: 10101010 00000000
        pub inline fn popFront(self: *@This(), T: type) DequeError!T {
            ztd.meta.comptimeError(@bitSizeOf(T) >= self.capacity, "ztd: `T` must be smaller than `BackingInt`", .{});
            return self.internalPop(T, @bitSizeOf(T), true);
        }

        /// Pops `T` from back of the `Deque`
        /// If pop would overflow, then the result will be widened to `@bitSizeOf(T)` and deque becomes empty
        /// Trying to pop from a empty deque returns error
        /// E.g. If empty `Deque` is backed by `u16` and `T` is `u8`, the result would look like:
        /// head: .right
        /// pop: 11111111 10101010
        /// pop: 00000000 10101010
        /// head: .left
        /// pop: 11111111 10101010
        /// pop: 11111111 00000000
        pub inline fn popBack(self: *@This(), T: type) DequeError!T {
            ztd.meta.comptimeError(@bitSizeOf(T) >= self.capacity, "ztd: `T` must be smaller than `BackingInt`", .{});
            return self.internalPop(T, @bitSizeOf(T), false);
        }

        /// Returns the value int as `T`, the result is truncated if `T` is smaller than `BackingInt`
        /// If `endianess` is not the same as native endianess the value will be byte swapped
        /// That is `endianess` indicates the endianess of the `BackingInt` not the endianess you want it to be returned in
        pub inline fn as(self: @This(), T: type, endianess: std.builtin.Endian) T {
            if (endianess != comptime builtin.target.cpu.arch.endian()) {
                return @truncate(@byteSwap(self.value));
            } else {
                return @truncate(self.value);
            }
        }

        /// Return range of bits from the value int as a `T`, the result is truncated if `T` is smaller than `BackingInt`
        pub inline fn rangeAs(self: @This(), T: type, start: BackingIndex, end: BackingIndex) DequeError!T {
            return @truncate(try extractRange(BackingInt, self.value, start, end));
        }

        /// Extract `T` from the deque with offset specified by `off`, the result is truncated if `T` is smaller than `BackingInt`
        pub inline fn extractAs(self: @This(), T: type, off: BackingCount) DequeError!T {
            return extract(BackingInt, self.value, T, off);
        }

        /// Extract `T` as bytes from the deque with offset specified by `off`
        pub inline fn extractAsBytes(self: @This(), T: type, off: BackingCount) DequeError![byteSizeOf(T)]u8 {
            return extractBytes(BackingInt, self.value, T, off);
        }

        pub inline fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            return std.fmt.formatInt(self.value, 2, .lower, .{ .width = self.capacity, .fill = '0' }, writer);
        }
    };
}

test "Deque" {
    const reverse_endian = switch (comptime builtin.target.cpu.arch.endian()) {
        inline .little => .big,
        inline .big => .little,
    };

    inline for (.{.left, .right}) |head| {
        var deque = Deque(u32, head){};
        try std.testing.expectEqual(0, deque.len);
        try deque.push(u8, 'i');
        try std.testing.expectEqual(8, deque.len);
        try deque.push(u8, 'o');
        try std.testing.expectEqual(16, deque.len);
        try deque.push(u8, 'm');
        try std.testing.expectEqual(24, deque.len);
        try deque.push(u8, 'e');
        try std.testing.expectError(error.NoSpaceLeft, deque.push(u8, 'e'));
        try std.testing.expectEqual(32, deque.len);

        switch (@as(Direction, head)) {
            .right => {
                try std.testing.expectEqualSlices(u8, "moi", (try deque.extractAsBytes(u24, 8))[0..]);
                try std.testing.expectEqualSlices(u8, "emoi", (try deque.extractAsBytes(u32, 0))[0..]);
                const swapped = Deque(u32, .right).init(deque.value, deque.len, reverse_endian);
                try std.testing.expectEqualSlices(u8, "ome", (try swapped.extractAsBytes(u24, 8))[0..]);
                try std.testing.expectEqualSlices(u8, "iome", (try swapped.extractAsBytes(u32, 0))[0..]);
                try std.testing.expectEqual(deque.value, swapped.as(u32, reverse_endian));
            },
            .left => {
                try std.testing.expectEqualSlices(u8, "ome", (try deque.extractAsBytes(u24, 8))[0..]);
                try std.testing.expectEqualSlices(u8, "iome", (try deque.extractAsBytes(u32, 0))[0..]);
                const swapped = Deque(u32, .right).init(deque.value, deque.len, reverse_endian);
                try std.testing.expectEqualSlices(u8, "moi", (try swapped.extractAsBytes(u24, 8))[0..]);
                try std.testing.expectEqualSlices(u8, "emoi", (try swapped.extractAsBytes(u32, 0))[0..]);
                try std.testing.expectEqual(deque.value, swapped.as(u32, reverse_endian));
            }
        }

        const saved = deque;

        try std.testing.expectEqual('e', deque.popBack(u8));
        try std.testing.expectEqual(24, deque.len);
        try std.testing.expectEqual('m', deque.popBack(u8));
        try std.testing.expectEqual(16, deque.len);
        try std.testing.expectEqual('o', deque.popBack(u8));
        try std.testing.expectEqual(8, deque.len);
        try std.testing.expectEqual('i', deque.popBack(u8));
        try std.testing.expectEqual(0, deque.len);
        try std.testing.expectEqual(0, deque.value);

        deque = saved;

        try std.testing.expectEqual('i', deque.popFront(u8));
        try std.testing.expectEqual(24, deque.len);
        try std.testing.expectEqual('o', deque.popFront(u8));
        try std.testing.expectEqual(16, deque.len);
        try std.testing.expectEqual('m', deque.popFront(u8));
        try std.testing.expectEqual(8, deque.len);
        try std.testing.expectEqual('e', deque.popFront(u8));
        try std.testing.expectEqual(0, deque.len);
        try std.testing.expectEqual(0, deque.value);
    }

    inline for (.{.left, .right}) |head| {
        var deque = Deque(u16, head){};
        try std.testing.expectEqual(0, deque.len);
        try deque.push(u5, 2);
        try std.testing.expectEqual(5, deque.len);
        try deque.push(u5, 1);
        try std.testing.expectEqual(10, deque.len);
        try deque.push(u5, 2);
        try std.testing.expectEqual(15, deque.len);
        try deque.push(u5, 31);
        try std.testing.expectEqual(16, deque.len);
        try std.testing.expectError(error.NoSpaceLeft, deque.push(u5, 9));

        const saved = deque;

        try std.testing.expectEqual(2, deque.popFront(u5));
        try std.testing.expectEqual(1, deque.popFront(u5));
        try std.testing.expectEqual(2, deque.popFront(u5));
        try std.testing.expectEqual(16, deque.popFront(u5));

        deque = saved;

        try std.testing.expectEqual(1, deque.popBack(u1));
        try std.testing.expectEqual(2, deque.popBack(u5));
        try std.testing.expectEqual(1, deque.popBack(u5));
        try std.testing.expectEqual(2, deque.popBack(u5));
    }
}
