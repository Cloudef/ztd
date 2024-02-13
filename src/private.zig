const meta = @import("meta.zig");

pub fn opt(comptime T: type, default: T, comptime keypath: []const u8) T {
    const root = @import("root");
    if (@hasDecl(root, "ztd_options")) {
        return meta.keypathField(root.ztd_options, keypath);
    }
    return default;
}
