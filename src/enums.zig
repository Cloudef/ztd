const std = @import("std");

/// Array of enums bounded by the enum's length
pub fn BoundedEnumArray(E: type) type {
    return std.BoundedArray(E, std.meta.fields(E).len);
}

/// Takes fields of `T` and creates `packed struct` containing a `bool` for each field.
pub fn Bitfield(T: type) type {
    var fields: []const std.builtin.Type.StructField = &.{};
    for (std.meta.fields(T)) |field| {
        fields = fields ++ .{std.builtin.Type.StructField{
            .name = field.name,
            .type = bool,
            .default_value_ptr = &false,
            .is_comptime = false,
            .alignment = 0,
        }};
    }
    return @Type(.{
        .@"struct" = .{
            .layout = .@"packed",
            .fields = fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
}

/// Similar to `Bitfield`, but allow set and get of bits by a `enum` and `[]const u8`.
pub fn BitfieldSet(T: type) type {
    return struct {
        pub const Field = switch (@typeInfo(T)) {
            .@"enum" => T,
            else => std.meta.FieldEnum(T),
        };

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
