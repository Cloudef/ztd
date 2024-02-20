const std = @import("std");

/// Welcome to the jungle
const CompileDebug = false;

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

// -- start of cursed but incredibly useful

// Probably not very useful outside this cursed code, so not making it pub
fn StrippedOf(comptime T: type, comptime filter: []const std.builtin.TypeId) type {
    if (isKind(T, filter)) return std.meta.Child(T);
    return T;
}

/// Gives comptime keypath representation of a "container-like" type
/// That is given struct:
/// struct {
///     a: struct {
///         b: struct {
///             c: bool,
///         }
///         d: []const u8
///     }
/// }
/// You would get a tree:
/// .a.b.c
/// .a.d
pub fn FieldTree(comptime T: type) type {
    return struct {
        comptime root_type: type = T,
        name: []const u8,
        type: []const u8,
        parent_index: usize,
        global_index: usize,

        inline fn init(comptime name: []const u8, comptime type_name: []const u8, comptime parent_index: usize, comptime global_index: usize) @This() {
            comptimeLog(CompileDebug, "FieldTree ({d}, {d}): {s}, {s}", .{ global_index, parent_index, name, type_name });
            return .{
                .name = name,
                .type = type_name,
                .parent_index = parent_index,
                .global_index = global_index,
            };
        }

        pub inline fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            return writer.print("{}. {s}: {s}", .{ self.global_index, self.name, self.type });
        }

        pub inline fn Type(comptime self: @This()) type {
            return allTypes()[self.global_index];
        }

        pub inline fn parent(comptime self: @This()) ?@This() {
            if (self.global_index == 0) return null;
            return allFields()[self.parent_index];
        }

        pub fn isInOptionalBranch(comptime self: @This()) bool {
            if (self.global_index == 0) return false;
            const optionalFields = comptime filteredFields(&.{ .Union, .Optional });
            inline for (optionalFields) |f| if (f.global_index == self.parent_index) return true;
            return self.parent().?.isInOptionalBranch();
        }

        pub fn children(comptime self: @This()) []const @This() {
            const fields = comptime allFields()[1..];
            comptime var childs: [fields.len]@This() = undefined;
            comptime var nchilds = 0;
            inline for (fields) |f| {
                if (f.parent_index == self.global_index) {
                    childs[nchilds] = f;
                    nchilds += 1;
                }
            }
            return childs[0..nchilds];
        }

        pub fn childNamed(comptime self: @This(), name: []const u8) ?@This() {
            inline for (comptime self.children()) |f| {
                if (f.name.len == self.name.len + name.len + 1 and std.mem.eql(u8, f.name[f.name.len - name.len ..], name))
                    return f;
            }
            return null;
        }

        fn filteredFieldsInner(comptime FT: anytype, comptime filter: []const std.builtin.TypeId, comptime name: []const u8, comptime parent_index: usize, comptime global_index: *usize, comptime fields: ?[]@This()) comptime_int {
            var index = 0;
            const thisIndex = global_index.*;
            if (isKind(FT, filter)) {
                if (fields) |fls| {
                    const tname = std.fmt.comptimePrint("{}", .{FT});
                    fls[index] = @This().init(name, tname, parent_index, global_index.*);
                }
                index += 1;
            }
            global_index.* += 1;
            switch (@typeInfo(FT)) {
                .Union, .Struct => inline for (std.meta.fields(FT)) |desc| {
                    const fname = std.fmt.comptimePrint("{s}.{s}", .{ name, desc.name });
                    index += filteredFieldsInner(desc.type, filter, fname, thisIndex, global_index, if (fields) |fls| fls[index..] else null);
                },
                .Optional, .Pointer => if (isContainer(std.meta.Child(FT))) {
                    inline for (std.meta.fields(std.meta.Child(FT))) |desc| {
                        const fname = std.fmt.comptimePrint("{s}.{s}", .{ name, desc.name });
                        index += filteredFieldsInner(desc.type, filter, fname, thisIndex, global_index, if (fields) |fls| fls[index..] else null);
                    }
                },
                else => {},
            }
            return index;
        }

        pub fn filteredFields(comptime filter: []const std.builtin.TypeId) []const @This() {
            comptime var global_index: usize = 0;
            const num = comptime filteredFieldsInner(T, filter, "", 0, &global_index, null);
            return comptime blk: {
                global_index = 0;
                var fields: [num]@This() = undefined;
                _ = filteredFieldsInner(T, filter, "", 0, &global_index, fields[0..]);
                break :blk fields[0..];
            };
        }

        pub inline fn allFields() []const @This() {
            return comptime filteredFields(&.{});
        }

        fn filteredTypesInner(comptime FT: anytype, comptime filter: []const std.builtin.TypeId, comptime types: ?[]type) comptime_int {
            var index = 0;
            if (isKind(FT, filter)) {
                if (types) |tps| tps[index] = FT;
                index += 1;
            }
            switch (@typeInfo(FT)) {
                .Union, .Struct => inline for (std.meta.fields(FT)) |desc| {
                    index += filteredTypesInner(desc.type, filter, if (types) |tps| tps[index..] else null);
                },
                .Optional, .Pointer => if (isContainer(std.meta.Child(FT))) {
                    inline for (std.meta.fields(std.meta.Child(FT))) |desc| {
                        index += filteredTypesInner(desc.type, filter, if (types) |tps| tps[index..] else null);
                    }
                },
                else => {},
            }
            return index;
        }

        pub fn filteredTypes(comptime filter: []const std.builtin.TypeId) []const type {
            const num = comptime filteredTypesInner(T, filter, null);
            return comptime blk: {
                var types: [num]type = undefined;
                _ = filteredTypesInner(T, filter, types[0..]);
                break :blk types[0..];
            };
        }

        pub inline fn allTypes() []const type {
            return comptime filteredTypes(&.{});
        }

        pub fn fromKeypath(keypath: []const u8) ?@This() {
            const fields = comptime allFields();
            inline for (fields) |f| {
                if (f.name.len == keypath.len and std.mem.eql(u8, f.name, keypath)) {
                    return f;
                }
            }
            return null;
        }
    };
}

inline fn UnwrappedType(comptime T: type) type {
    std.debug.assert(@typeInfo(T) == .Pointer);
    return if (@typeInfo(std.meta.Child(T)) == .Optional) *std.meta.Child(std.meta.Child(T)) else T;
}

inline fn unwrapOptional(any: anytype) UnwrappedType(@TypeOf(any)) {
    const T = @TypeOf(any);
    std.debug.assert(@typeInfo(T) == .Pointer);
    return if (@typeInfo(std.meta.Child(T)) == .Optional) &any.*.? else any;
}

/// Returns a pointer to a nested field of "container-like"
/// It acts like @field(), so there is no copy and you'll have direct access to the real field value
pub fn ptrKeypathField(root: anytype, comptime keypath: []const u8) *FieldTree(StrippedOf(@TypeOf(root), &.{.Pointer})).fromKeypath(keypath).?.Type() {
    comptimeAssertValueType(root, "ztd", "root", &.{.Pointer});

    const Parts = comptime blk: {
        var nparts = 0;
        var iter = std.mem.split(u8, keypath, ".");
        while (iter.next()) |_| nparts += 1;
        iter.reset();
        var parts: [nparts]struct { name: []const u8, full: []const u8 } = undefined;
        var i = 0;
        while (iter.next()) |v| : (i += 1) {
            parts[i].name = v;
            parts[i].full = if (i == 0) "" else std.fmt.comptimePrint("{s}.{s}", .{ parts[i - 1].full, v });
            comptimeLog(CompileDebug, "ptrKeypathField: {s}", .{parts[i].full});
        }
        break :blk parts;
    };

    const TypeWalkTuple = comptime blk: {
        var types: [Parts.len]std.builtin.Type.StructField = undefined;
        for (Parts, 0..) |part, i| {
            const T = *FieldTree(StrippedOf(@TypeOf(root), &.{.Pointer})).fromKeypath(part.full).?.Type();
            types[i] = .{
                .name = std.fmt.comptimePrint("{}", .{i}),
                .type = T,
                .alignment = 0,
                .default_value = null,
                .is_comptime = false,
            };
        }
        break :blk @Type(.{
            .Struct = .{
                .layout = .Auto,
                .fields = &types,
                .decls = &.{},
                .is_tuple = true,
            },
        });
    };

    var tmp: TypeWalkTuple = undefined;
    tmp[0] = @constCast(root);

    if (Parts.len > 1) {
        inline for (Parts[1..], 0..) |part, i| {
            const this = std.fmt.comptimePrint("{}", .{i});
            const next = std.fmt.comptimePrint("{}", .{i + 1});
            var thisptr = unwrapOptional(@field(tmp, this));
            @field(tmp, next) = @ptrCast(&@field(thisptr, part.name));
        }
    }

    const last = std.fmt.comptimePrint("{}", .{Parts.len - 1});
    return @field(tmp, last);
}

/// Returns a value of a nested field in a "container-like"
pub fn keypathField(root: anytype, comptime keypath: []const u8) FieldTree(StrippedOf(@TypeOf(root), &.{.Pointer})).fromKeypath(keypath).?.Type() {
    return switch (@typeInfo(@TypeOf(root))) {
        .Pointer => ptrKeypathField(root, keypath).*,
        else => ptrKeypathField(&root, keypath).*,
    };
}

test "cursed keypath meta stuff" {
    const Test = struct {
        const Inner = struct {
            ptr: *u32,
            str: []const u8,
        };
        bool: bool,
        u: union(enum) {
            str: []const u8,
            int: u32,
            opt: ?Inner,
            ptr: *Inner,
            st: Inner,
        },
    };

    const thing: Test = .{
        .bool = true,
        .u = .{
            .str = "hello world",
        },
    };

    try std.testing.expect(ptrKeypathField(&thing, "") == &thing);
    try std.testing.expect(ptrKeypathField(&thing, ".bool") == &thing.bool);
    try std.testing.expect(ptrKeypathField(&thing, ".u") == &thing.u);
    try std.testing.expect(ptrKeypathField(&thing, ".u.str") == &thing.u.str);

    try std.testing.expect(@TypeOf(keypathField(&thing, "")) == Test);
    try std.testing.expect(isKind(@TypeOf(keypathField(&thing, ".u")), &.{.Union}));
    try std.testing.expect(std.meta.activeTag(keypathField(&thing, ".u")) == .str);
    try std.testing.expectEqualSlices(u8, "hello world", keypathField(&thing, ".u.str"));
    try std.testing.expectEqual(true, keypathField(&thing, ".bool"));

    try std.testing.expectEqualSlices(u8, comptime FieldTree(Test).fromKeypath(".u.str").?.parent().?.name, ".u");
    try std.testing.expect(comptime FieldTree(Test).fromKeypath(".u").?.childNamed("str") != null);
    try std.testing.expect(comptime FieldTree(Test).fromKeypath(".u").?.childNamed("int") != null);
    try std.testing.expect(comptime FieldTree(Test).fromKeypath(".u").?.childNamed("opt") != null);
    try std.testing.expect(comptime FieldTree(Test).fromKeypath(".u").?.childNamed("ptr") != null);
    try std.testing.expect(comptime FieldTree(Test).fromKeypath(".u.opt").?.childNamed("ptr") != null);
    try std.testing.expect(comptime FieldTree(Test).fromKeypath(".u.opt").?.childNamed("str") != null);
    try std.testing.expect(comptime FieldTree(Test).fromKeypath(".u.ptr").?.childNamed("ptr") != null);
    try std.testing.expect(comptime FieldTree(Test).fromKeypath(".u.ptr").?.childNamed("str") != null);
    try std.testing.expect(comptime FieldTree(Test).fromKeypath(".u.st").?.childNamed("ptr") != null);
    try std.testing.expect(comptime FieldTree(Test).fromKeypath(".u.st").?.childNamed("str") != null);
    try std.testing.expect(comptime FieldTree(Test).fromKeypath(".not_found") == null);

    try std.testing.expect(comptime FieldTree(Test).fromKeypath(".u.str").?.isInOptionalBranch());
    try std.testing.expect(!comptime FieldTree(Test).fromKeypath(".u").?.isInOptionalBranch());
}

// -- end of cursed but incredibly useful
