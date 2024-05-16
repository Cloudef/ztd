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
pub fn isKind(comptime T: type, comptime filter: []const std.builtin.TypeId) bool {
    inline for (filter) |f| if (@typeInfo(T) == f) return true;
    return filter.len == 0;
}

/// Is the type a "container-like" type (.Union, .Struct)
pub fn isContainer(comptime T: type) bool {
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
    comptimeAssertType(T, "ztd", "T", &.{.Int});
    comptimeError(@typeInfo(T).Int.signedness != signedness, "{s}: `{s}` must be a `{s}` integer", .{ prefix, name, @tagName(signedness) });
}

/// Assert the signedness of a integer type comptime with a useful message
pub inline fn comptimeAssertValueTypeSignedness(v: anytype, comptime prefix: []const u8, comptime name: []const u8, comptime signedness: std.builtin.Signedness) void {
    comptimeAssertTypeSignedness(@TypeOf(v), prefix, name, signedness);
}

/// If `T` is an error union, returns the payload, otherwise reutrns `T` as is
pub fn WithoutError(T: type) type {
    return switch (@typeInfo(T)) {
        .ErrorUnion => |eu| eu.payload,
        else => T,
    };
}

/// If `T` is an error union, returns `T` as is, otherwise returns `error{}!T`
pub fn WithError(T: type) type {
    return switch (@typeInfo(T)) {
        .ErrorUnion => T,
        else => error{}!T,
    };
}

/// If `with_eu` is true, returns `WithError(fun.return_type)`
/// If `with_eu` is false, returns `WithoutError(fun.return_type)`
pub fn ReturnType(comptime fun: anytype, comptime with_eu: bool) type {
    comptimeAssertValueType(fun, "ztd", "fun", &.{.Fn});
    const fun_info = @typeInfo(@TypeOf(fun)).Fn;
    return if (with_eu) WithError(fun_info.return_type.?) else WithoutError(fun_info.return_type.?);
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
    try std.testing.expectEqual(anyerror!bool, ReturnType(tst.err, true));
    try std.testing.expectEqual(bool, ReturnType(tst.err, false));
    try std.testing.expectEqual(error{}!bool, ReturnType(tst.ok, true));
    try std.testing.expectEqual(bool, ReturnType(tst.ok, false));
}

/// Converts error union to optional
pub fn maybe(v: anytype) ?WithoutError(@TypeOf(v)) {
    comptimeAssertValueType(v, "ztd", "v", &.{.ErrorUnion});
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

/// Returns true if `v` is `null`
pub fn isNull(v: anytype) bool {
    return switch (@typeInfo(@TypeOf(v))) {
        .Null, .Optional => v == null,
        else => false,
    };
}

test "isNull" {
    const tst = struct {
        fn nil() ?bool {
            return null;
        }
        fn some() ?bool {
            return true;
        }
        fn fixed() bool {
            return true;
        }
    };
    try std.testing.expectEqual(true, isNull(tst.nil()));
    try std.testing.expectEqual(false, isNull(tst.some()));
    try std.testing.expectEqual(false, isNull(tst.fixed()));
}

pub fn StrippedOf(comptime T: type, comptime filter: []const std.builtin.TypeId) type {
    if (isKind(T, filter)) return std.meta.Child(T);
    return T;
}

/// Assigns every field that exists in both from `src` to `dst`
pub fn assign(dst: anytype, src: anytype) void {
    comptimeAssertValueType(dst, "ztd", "dst", &.{.Pointer});
    comptimeAssertValueType(src, "ztd", "src", &.{ .Struct, .Union });
    inline for (std.meta.fields(std.meta.Child(@TypeOf(dst)))) |f| {
        if (@hasField(StrippedOf(@TypeOf(src), &.{.Pointer}), f.name)) {
            @field(dst, f.name) = @field(src, f.name);
        }
    }
}

/// Derives `T` from `src`
/// That is creates empty `T` and does `assign(new, src)` on it and returns the result.
pub inline fn derive(T: type, init: anytype, src: anytype) T {
    comptimeAssertValueType(init, "ztd", "init", &.{.Struct});
    comptimeAssertValueType(src, "ztd", "src", &.{ .Struct, .Union });
    var dst: T = std.mem.zeroInit(T, init);
    assign(&dst, src);
    return dst;
}
