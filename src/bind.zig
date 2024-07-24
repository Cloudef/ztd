const std = @import("std");
const meta = @import("meta.zig");

inline fn callWithReturnType(
    comptime ReturnType: type,
    comptime fun: anytype,
    system_bindings: anytype,
    user_bindings: anytype,
) ReturnType {
    const fun_info = @typeInfo(@TypeOf(fun)).Fn;
    var args: std.meta.ArgsTuple(@TypeOf(fun)) = undefined;
    inline for (&args, fun_info.params[0..]) |*arg, param| {
        arg.* = blk: {
            inline for (system_bindings) |bind| if (@TypeOf(bind) == param.type.?) break :blk bind;
            inline for (user_bindings) |bind| if (@TypeOf(bind) == param.type.?) break :blk bind;
            comptime var buf1 = std.fmt.comptimePrint("{}", .{@TypeOf(system_bindings)});
            comptime var buf2 = std.fmt.comptimePrint("{}", .{@TypeOf(user_bindings)});
            meta.comptimeError(
                true,
                \\ztd: bind: cannot call without a binding for a type: {}
                \\sys: {s}
                \\usr: {s}
                \\{}
            ,
                .{
                    param.type.?,
                    buf1[7 .. buf1.len - 1],
                    buf2[7 .. buf2.len - 1],
                    @TypeOf(fun),
                },
            );
        };
    }
    return @call(.auto, fun, args);
}

/// Call function `fun`, passing arguments from both `system_bindings` and `user_bindings`
/// if the function accepts any of them as a parameters
pub inline fn call(
    comptime fun: anytype,
    system_bindings: anytype,
    user_bindings: anytype,
) meta.ReturnType(fun, .without_error) {
    return callWithReturnType(meta.ReturnType(fun, .without_error), fun, system_bindings, user_bindings);
}

/// Call function `fun`, passing arguments from both `system_bindings` and `user_bindings`
/// if the function accepts any of them as a parameters, always returns a error union
pub inline fn errorCall(
    comptime fun: anytype,
    system_bindings: anytype,
    user_bindings: anytype,
) meta.ReturnType(fun, .with_error) {
    return callWithReturnType(meta.ReturnType(fun, .with_error), fun, system_bindings, user_bindings);
}

const Bind = @This();

/// Convenience function that wraps `fun` into a struct with the bind interface
pub fn Callable(comptime fun: anytype) type {
    return struct {
        comptime fun: @TypeOf(fun) = fun,

        pub inline fn call(
            self: @This(),
            system_bindings: anytype,
            user_bindings: anytype,
        ) meta.ReturnType(self.fun, .without_error) {
            return Bind.call(self.fun, system_bindings, user_bindings);
        }

        pub inline fn errorCall(
            self: @This(),
            system_bindings: anytype,
            user_bindings: anytype,
        ) meta.ReturnType(self.fun, .with_error) {
            return Bind.errorCall(self.fun, system_bindings, user_bindings);
        }
    };
}

const Thing = struct {
    whatever: bool = true,
};

fn fun1(num: u32) void {
    std.log.info("fun1: {}", .{num});
}

fn fun2(str: []const u8) void {
    std.log.info("fun2: {s}", .{str});
}

fn fun3(num: u32, str: []const u8, thing: Thing) !bool {
    std.log.info("fun3: {}, {s}, {}", .{ num, str, thing });
    return true;
}

test {
    const num: u32 = 69;
    const str: []const u8 = "hello world";
    const thing: Thing = .{};
    const sys: u16 = 42;
    const unused: u64 = 4;
    call(fun1, .{sys}, .{ num, str, thing, unused });
    try errorCall(fun2, .{sys}, .{ num, str, thing, unused });
    try std.testing.expectEqual(true, try errorCall(fun3, .{sys}, .{ num, str, thing, unused }));
}
