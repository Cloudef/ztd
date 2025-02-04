const std = @import("std");

/// Wrapper for @compileError(std.fmt.comptimePrint(...))
pub inline fn comptimeError(comptime emit: bool, comptime fmt: []const u8, args: anytype) void {
    comptime if (emit) @compileError(std.fmt.comptimePrint(fmt, args));
}

/// Wrapper for @compileLog(std.fmt.comptimePrint(...))
pub inline fn comptimeLog(comptime emit: bool, comptime fmt: []const u8, args: anytype) void {
    comptime if (emit) @compileLog(std.fmt.comptimePrint(fmt, args));
}

/// Conditional debug log
pub inline fn debug(comptime emit: bool, comptime fmt: []const u8, args: anytype) void {
    if (emit) std.debug.print(fmt ++ "\n", args);
}

/// Does the type match any of the types in `filter`?
pub inline fn isKind(comptime T: type, comptime filter: []const std.builtin.TypeId) bool {
    inline for (filter) |f| if (@typeInfo(T) == f) return true;
    return filter.len == 0;
}

/// Is the type a "container-like" type (.Union, .Struct)
pub inline fn isContainer(comptime T: type) bool {
    return comptime isKind(T, &.{ .Union, .Struct });
}

/// Assert type comptime with a useful message
pub inline fn comptimeAssertType(comptime T: type, comptime prefix: []const u8, comptime name: []const u8, comptime filter: []const std.builtin.TypeId) void {
    comptimeError(!isKind(T, filter), "{s}: `{s}` must be kind of: {any}", .{ prefix, name, filter });
}

/// Assert the type of value comptime with a useful message
pub inline fn comptimeAssertValueType(v: anytype, comptime prefix: []const u8, comptime name: []const u8, comptime filter: []const std.builtin.TypeId) void {
    comptimeAssertType(@TypeOf(v), prefix, name, filter);
}

/// Assert the signedness of a integer type comptime with a useful message
pub inline fn comptimeAssertTypeSignedness(comptime T: type, comptime prefix: []const u8, comptime name: []const u8, comptime signedness: std.builtin.Signedness) void {
    comptimeAssertType(T, "ztd", "T", &.{.int});
    comptimeError(@typeInfo(T).int.signedness != signedness, "{s}: `{s}` must be a `{s}` integer", .{ prefix, name, @tagName(signedness) });
}

/// Assert the signedness of a integer type comptime with a useful message
pub inline fn comptimeAssertValueTypeSignedness(v: anytype, comptime prefix: []const u8, comptime name: []const u8, comptime signedness: std.builtin.Signedness) void {
    comptimeAssertTypeSignedness(@TypeOf(v), prefix, name, signedness);
}

/// If `T` is an error union, returns the payload, otherwise reutrns `T` as is
pub fn WithoutError(T: type) type {
    return switch (@typeInfo(T)) {
        .error_union => |eu| eu.payload,
        else => T,
    };
}

/// If `T` is an error union, returns `T` as is, otherwise returns `error{}!T`
pub fn WithError(T: type) type {
    return switch (@typeInfo(T)) {
        .error_union => T,
        else => error{}!T,
    };
}

/// Returns the ReturnType of `fun`, `mode` can be used to transform the returned type
pub fn ReturnType(comptime fun: anytype, comptime mode: enum {
    as_is,
    with_error,
    without_error,
}) type {
    comptimeAssertValueType(fun, "ztd", "fun", &.{.@"fn"});
    const fun_info = @typeInfo(@TypeOf(fun)).@"fn";
    return switch (mode) {
        .as_is => fun_info.return_type.?,
        .with_error => WithError(fun_info.return_type.?),
        .without_error => WithoutError(fun_info.return_type.?),
    };
}

test "ReturnType" {
    const tst = struct {
        fn err() anyerror!bool {
            return true;
        }
        fn ok() bool {
            return true;
        }
    };
    try std.testing.expectEqual(anyerror!bool, ReturnType(tst.err, .with_error));
    try std.testing.expectEqual(bool, ReturnType(tst.err, .without_error));
    try std.testing.expectEqual(error{}!bool, ReturnType(tst.ok, .with_error));
    try std.testing.expectEqual(bool, ReturnType(tst.ok, .without_error));
    try std.testing.expectEqual(bool, ReturnType(tst.ok, .as_is));
    try std.testing.expectEqual(anyerror!bool, ReturnType(tst.err, .as_is));
}

/// Converts error union to optional
pub fn maybe(v: anytype) ?WithoutError(@TypeOf(v)) {
    comptimeAssertValueType(v, "ztd", "v", &.{.error_union});
    return if (v) |unwrapped| unwrapped else |_| null;
}

test "maybe" {
    const tst = struct {
        fn err() !bool {
            return error.fail;
        }
        fn ok() !bool {
            return true;
        }
    };
    try std.testing.expectEqual(null, maybe(tst.err()));
    try std.testing.expectEqual(true, maybe(tst.ok()));
}

pub fn StrippedOf(comptime T: type, comptime filter: []const std.builtin.TypeId) type {
    if (isKind(T, filter)) return std.meta.Child(T);
    return T;
}

/// Assigns every field that exists in both from `src` to `dst`
pub fn assign(dst: anytype, src: anytype) void {
    comptimeAssertValueType(dst, "ztd", "dst", &.{.pointer});
    comptimeAssertValueType(src, "ztd", "src", &.{ .@"struct", .@"union" });
    inline for (std.meta.fields(std.meta.Child(@TypeOf(dst)))) |f| {
        if (@hasField(StrippedOf(@TypeOf(src), &.{.pointer}), f.name)) {
            @field(dst, f.name) = @field(src, f.name);
        }
    }
}

test "assign" {
    const Src = struct {
        a: u32 = 42,
        b: bool = true,
        c: f32 = 66.6,
    };

    const Dst = struct {
        b: bool = false,
        a: u32 = 0,
    };

    var dst: Dst = .{};
    assign(&dst, Src{});
    try std.testing.expectEqual(42, dst.a);
    try std.testing.expectEqual(true, dst.b);
}

/// Derives `T` from `src`
/// That is creates empty `T` and does `assign(new, src)` on it and returns the result.
pub fn derive(T: type, init: anytype, src: anytype) T {
    comptimeAssertValueType(init, "ztd", "init", &.{.@"struct"});
    comptimeAssertValueType(src, "ztd", "src", &.{ .@"struct", .@"union" });
    var dst: T = std.mem.zeroInit(T, init);
    assign(&dst, src);
    return dst;
}

test "derive" {
    const Src = struct {
        a: u32 = 42,
        b: bool = true,
        c: f32 = 66.6,
    };

    const Dst = struct {
        b: bool = false,
        a: u32 = 0,
        d: u8 = 255,
    };

    const dst = derive(Dst, Dst{ .d = 69 }, Src{});
    try std.testing.expectEqual(42, dst.a);
    try std.testing.expectEqual(true, dst.b);
    try std.testing.expectEqual(69, dst.d);
}
