const std = @import("std");

pub fn BoundedEnumArray(E: type) type {
    return std.BoundedArray(E, std.meta.fields(E).len);
}

pub fn Bitfield(T: type) type {
    var fields: []const std.builtin.Type.StructField = &.{};
    for (std.meta.fields(T)) |field| {
        fields = fields ++ .{.{
            .name = field.name,
            .type = bool,
            .default_value = &false,
            .is_comptime = false,
            .alignment = 0,
        }};
    }
    return @Type(.{
        .Struct = .{
            .layout = .@"packed",
            .fields = fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}

pub fn BitfieldWrapper(T: type) type {
    const Fields = blk: {
        if (@typeInfo(T) == .Enum) break :blk T;
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
    return struct {
        pub const Field = Fields;
        bits: Bitfield(T) = .{},

        pub fn set(self: *@This(), field: Field, value: bool) void {
            inline for (std.meta.fields(T), 0..) |fld, idx| {
                if (idx == @intFromEnum(field)) {
                    @field(self.bits, fld.name) = value;
                    return;
                }
            }
            unreachable;
        }

        pub fn get(self: *@This(), field: Field) bool {
            inline for (std.meta.fields(T), 0..) |fld, idx| {
                if (idx == @intFromEnum(field)) return @field(self.bits, fld.name);
            }
            unreachable;
        }

        pub fn setStr(self: *@This(), field: []const u8, value: bool) void {
            if (std.meta.stringToEnum(Field, field)) |f| return self.set(f, value);
        }

        pub fn getStr(self: *@This(), field: []const u8) bool {
            if (std.meta.stringToEnum(Field, field)) |f| return self.get(f);
            return false;
        }
    };
}
