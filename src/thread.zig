const std = @import("std");
const ztd = @import("ztd.zig");

pub fn ThreadFieldStore(T: type) type {
    ztd.meta.comptimeAssertType(T, "ztd", "T", &.{.Struct});

    const FieldEnum = blk: {
        var fields: []const std.builtin.Type.EnumField = &.{};
        for (std.meta.fields(T), 0..) |field, idx| {
            fields = fields ++ .{.{
                .name = field.name,
                .value = idx,
            }};
        }
        break :blk @Type(.{
            .Enum = .{
                .tag_type = std.math.IntFittingRange(0, fields.len),
                .fields = fields,
                .decls = &.{},
                .is_exhaustive = true,
            },
        });
    };

    const Store = blk: {
        var fields: []const std.builtin.Type.StructField = &.{};
        for (std.meta.fields(T)) |field| {
            ztd.meta.comptimeError(field.is_comptime, "ztd: `T`.{s} is a comptime field", .{field.name});
            const MutexField = struct {
                mutex: std.Thread.RwLock = .{},
                value: field.type = if (field.default_value) |ptr| @as(*const field.type, @ptrCast(@alignCast(ptr))).* else undefined,

                pub fn unlockShared(self: *@This()) void {
                    self.mutex.unlockShared();
                }

                pub fn unlock(self: *@This()) void {
                    self.mutex.unlock();
                }
            };
            fields = fields ++ .{.{
                .name = field.name,
                .type = MutexField,
                .default_value = &MutexField{},
                .is_comptime = false,
                .alignment = std.atomic.cache_line,
            }};
        }
        break :blk @Type(.{
            .Struct = .{
                .layout = .auto,
                .fields = fields,
                .decls = @typeInfo(T).Struct.decls,
                .is_tuple = false,
            },
        });
    };

    return struct {
        unsafe: Store = .{},

        pub fn TypeOfField(comptime field: FieldEnum) type {
            inline for (std.meta.fields(Store), 0..) |fld, idx| {
                if (idx == @intFromEnum(field)) return fld.type;
            }
            unreachable;
        }

        pub const GetMethod = enum {
            exclusive,
            shared,
            unsafe,
        };

        pub fn get(self: *@This(), comptime field: FieldEnum, comptime method: GetMethod) *TypeOfField(field) {
            inline for (std.meta.fields(Store), 0..) |fld, idx| {
                if (idx == @intFromEnum(field)) {
                    const v = &@field(self.unsafe, fld.name);
                    switch (method) {
                        .exclusive => v.mutex.lock(),
                        .shared => v.mutex.lockShared(),
                        .unsafe => {},
                    }
                    return v;
                }
            }
            unreachable;
        }

        pub const LockMethod = enum {
            exclusive,
            shared,
        };

        pub fn lock(self: *@This(), comptime field: FieldEnum, comptime method: LockMethod) void {
            inline for (std.meta.fields(Store), 0..) |fld, idx| {
                if (idx == @intFromEnum(field)) {
                    const v = &@field(self.unsafe, fld.name);
                    switch (method) {
                        .exclusive => v.mutex.lock(),
                        .shared => v.mutex.lockShared(),
                    }
                    return;
                }
            }
            unreachable;
        }

        pub fn unlock(self: *@This(), comptime field: FieldEnum, comptime method: LockMethod) void {
            inline for (std.meta.fields(Store), 0..) |fld, idx| {
                if (idx == @intFromEnum(field)) {
                    const v = &@field(self.unsafe, fld.name);
                    switch (method) {
                        .exclusive => v.mutex.unlock(),
                        .shared => v.mutex.unlockShared(),
                    }
                    return;
                }
            }
            unreachable;
        }
    };
}

test "ThreadFieldStore" {
    const Store = ThreadFieldStore(struct {
        a: bool = false,
        b: u32 = 42,
    });
    var store: Store = .{};

    {
        var field = store.get(.a, .exclusive);
        defer field.unlock();
        try std.testing.expectEqual(false, field.value);
        field.value = true;
    }

    {
        var field = store.get(.a, .shared);
        defer field.unlockShared();
        try std.testing.expectEqual(true, field.value);
    }

    {
        var field = store.get(.b, .shared);
        defer field.unlockShared();
        try std.testing.expectEqual(42, field.value);
    }
}
