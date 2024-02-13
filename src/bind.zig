const std = @import("std");
const meta = @import("meta.zig");
const ReturnType = meta.ReturnType;

inline fn callRT(comptime RT: type, comptime fun: anytype, system_bindings: anytype, user_bindings: anytype) RT {
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
pub inline fn call(comptime fun: anytype, system_bindings: anytype, user_bindings: anytype) ReturnType(fun, false) {
    return callRT(ReturnType(fun, false), fun, system_bindings, user_bindings);
}

/// Call function `fun`, passing arguments from both `system_bindings` and `user_bindings`
/// if the function accepts any of them as a parameters, always returns error
pub inline fn errorCall(comptime fun: anytype, system_bindings: anytype, user_bindings: anytype) ReturnType(fun, true) {
    return callRT(ReturnType(fun, true), fun, system_bindings, user_bindings);
}

/// Convenience function that wraps `fun` into a struct with the bind interface
pub fn Callable(comptime fun: anytype) type {
    return struct {
        comptime fun: @TypeOf(fun) = fun,
        pub inline fn call(self: @This(), system_bindings: anytype, user_bindings: anytype) ReturnType(self.fun, false) {
            return callRT(ReturnType(self.fun, false), self.fun, system_bindings, user_bindings);
        }
        pub inline fn errorCall(self: @This(), system_bindings: anytype, user_bindings: anytype) ReturnType(self.fun, true) {
            return callRT(ReturnType(self.fun, true), self.fun, system_bindings, user_bindings);
        }
    };
}
