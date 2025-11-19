// Build script for zitron-examples
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const zitron_dep = b.dependency("zitron", .{
        .target = b.graph.host,
        .optimize = .Debug,
        .enum_file = true,
        .quiet = true,
    });

    const zitron_exe = zitron_dep.artifact("zitron");

    const zitron_run = b.addRunArtifact(zitron_exe);

    const zitron_write_in = b.addWriteFiles();

    const calc_input_dir = zitron_write_in.addCopyDirectory(b.path("src"), "calc_in", .{});

    zitron_run.setCwd(calc_input_dir);
    zitron_run.addArg("calc.zy");
    zitron_run.step.dependOn(&zitron_write_in.step);

    const zitron_write_out = b.addWriteFiles();
    zitron_write_out.step.dependOn(&zitron_run.step);

    const calc_rootdir = zitron_write_out.addCopyDirectory(calc_input_dir, "", .{
        .exclude_extensions = &.{"zy"},
    });

    const calc_mod = b.addModule("calc_parser", .{
        .root_source_file = calc_rootdir.path(b, "calc.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_filters = b.option(
        []const []const u8,
        "test-filter",
        "Skip tests that do not match any filter",
    ) orelse &[0][]const u8{};

    const calc_unit_tests = b.addTest(.{
        .filters = test_filters,
        .root_module = calc_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(calc_unit_tests);

    const test_step = b.step("test", "Run unit tests");

    test_step.dependOn(&run_exe_unit_tests.step);
}
