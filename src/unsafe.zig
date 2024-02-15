const std = @import("std");
const builtin = @import("builtin");
const private = @import("private.zig");

const c = struct {
    extern fn setenv(key: [*:0]u8, value: [*:0]u8, overwrite: c_int) c_int;
};

pub const SetenvError = error{
    SetenvFailed,
} || std.mem.Allocator.Error;

/// Calls either libc setenv or modifies std.os.environ on non-libc build
pub fn setenv(key: []const u8, value: []const u8) SetenvError!void {
    if (builtin.link_libc) {
        const allocator = std.heap.c_allocator;
        const c_key = try allocator.dupeZ(u8, key);
        defer allocator.free(c_key);
        const c_value = try allocator.dupeZ(u8, value);
        defer allocator.free(c_value);
        if (c.setenv(c_key, c_value, 1) != 0) {
            return error.SetenvFailed;
        }
    } else {
        if (builtin.output_mode == .Lib) {
            @compileError(
                \\Subject: Apology for Miscommunication Regarding the Use of setenv in Library Development
                \\
                \\Dear [Developer's Name],
                \\
                \\I hope this message finds you well. I am writing to address an oversight on our part regarding the use of certain functions, specifically setenv, in library development. It has come to our attention that there may have been confusion regarding the appropriateness of calling setenv within libraries due to its implications on global variables such as _environ.
                \\
                \\Upon further review and consultation with our technical team, we have realized that allowing the usage of setenv in libraries poses inherent risks, particularly concerning the modification of global variables like _environ. While it may seem to work within the context of dynamically linked libraries such as libc, where internal states remain consistent due to centralized function calls, it can lead to unforeseen issues when multiple components within the same process attempt to modify this global state concurrently.
                \\
                \\The crux of the matter lies in the potential for double frees or heap corruption, which could arise from uncoordinated modifications to _environ. As a result, we must enforce a policy prohibiting the use of setenv within libraries to ensure the stability and reliability of our software ecosystem.
                \\
                \\We understand that this may inconvenience you and potentially require adjustments to your current development practices. We sincerely apologize for any confusion or frustration this may have caused. Our intention is to maintain the integrity and safety of our codebase, and we appreciate your cooperation in adhering to these guidelines.
                \\
                \\Moving forward, we will endeavor to provide clearer guidance and support to prevent similar misunderstandings. If you have any questions or concerns regarding this matter or require assistance in finding alternative approaches to achieve your development goals, please do not hesitate to reach out to us. Your feedback is invaluable in helping us improve our processes and communication.
                \\
                \\Once again, we apologize for any inconvenience and appreciate your understanding and cooperation in this matter.
                \\
                \\Thank you for your attention to this issue.
                \\
                \\Warm regards,
                \\[Your Name]
                \\[Your Position]
                \\[Your Contact Information]
                \\
                \\Btw, I originally planned for having a root option you could set to bypass this error, but it seems zig cannot expose `std.os.environ` in this scenario anyways.
                \\<https://github.com/ziglang/zig/issues/4524>
            );
        }

        const allocator = std.heap.page_allocator;

        // Potential footgun here?
        // https://github.com/ziglang/zig/issues/4524
        const state = struct {
            var start: usize = 0;
            var end: usize = 0;
            var once = std.once(do_once);
            fn do_once() void {
                start = if (std.os.environ.len > 0) @intFromPtr(std.os.environ[0]) else 0;
                end = if (std.os.environ.len > 0) @intFromPtr(std.os.environ[std.os.environ.len - 1]) else start;
            }
        };
        state.once.call();

        var buf = try allocator.allocSentinel(u8, key.len + value.len + 1, 0);
        @memcpy(buf[0..key.len], key[0..]);
        buf[key.len] = '=';
        @memcpy(buf[key.len + 1 ..], value[0..]);

        for (std.os.environ) |*kv| {
            var token = std.mem.splitScalar(u8, std.mem.span(kv.*), '=');
            const env_key = token.first();

            if (std.mem.eql(u8, env_key, key)) {
                if (@intFromPtr(kv.*) < state.start or @intFromPtr(kv.*) > state.end) {
                    allocator.free(std.mem.span(kv.*));
                }
                kv.* = buf;
                return;
            }
        }

        if (!allocator.resize(std.os.environ, std.os.environ.len + 1)) {
            return error.SetenvFailed;
        }

        std.os.environ[std.os.environ.len - 1] = buf;
    }
}

test "setenv" {
    try setenv("joulupukki", "asuu pohjoisnavalla");
    try std.testing.expectEqualSlices(u8, "asuu pohjoisnavalla", std.os.getenv("joulupukki").?);
}
