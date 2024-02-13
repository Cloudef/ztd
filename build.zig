const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("ztd", .{
        .root_source_file = .{ .path = "src/ztd.zig" },
        .imports = &.{},
    });

    const exe_test = b.addTest(.{
        .root_source_file = .{ .path = "src/ztd.zig" },
        .target = target,
        .optimize = optimize,
    });
    const run_test_exe = b.addRunArtifact(exe_test);
    const run_test = b.step("test", "Run unit tests");
    run_test.dependOn(&run_test_exe.step);

    const docs_step = b.step("docs", "Build the project documentation");

    const doc_obj = b.addObject(.{
        .name = "docs",
        .root_source_file = .{ .path = "src/ztd.zig" },
        .target = target,
        .optimize = optimize,
    });

    const install_docs = b.addInstallDirectory(.{
        .source_dir = doc_obj.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = std.fmt.comptimePrint("docs/{s}", .{"ztd"}),
    });

    docs_step.dependOn(&install_docs.step);
}
