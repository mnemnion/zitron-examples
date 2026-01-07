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
        .define = "TRACE",
    });

    const zitron_exe = zitron_dep.artifact("zitron");

    const calc_run = b.addRunArtifact(zitron_exe);

    const calc_write_in = b.addWriteFiles();

    const calc_input_dir = calc_write_in.addCopyDirectory(b.path("src"), "calc_in", .{});

    calc_run.setCwd(calc_input_dir);
    calc_run.addArg("calc.zy");
    calc_run.step.dependOn(&calc_write_in.step);

    const calc_write_out = b.addWriteFiles();
    calc_write_out.step.dependOn(&calc_run.step);

    const calc_rootdir = calc_write_out.addCopyDirectory(calc_input_dir, "", .{
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

    const run_calc_unit_tests = b.addRunArtifact(calc_unit_tests);

    const calc_grammar_install = b.addInstallFile(calc_rootdir.path(b, "calc.zig"), "calc/calc.zig");
    calc_grammar_install.step.dependOn(&calc_write_out.step);
    const calc_tokens_install = b.addInstallFile(calc_rootdir.path(b, "TokenKind.zig"), "calc/TokenKind.zig");
    calc_tokens_install.step.dependOn(&calc_write_out.step);

    const prolog_run = b.addRunArtifact(zitron_exe);

    const prolog_write_in = b.addWriteFiles();

    const prolog_input_dir = prolog_write_in.addCopyDirectory(b.path("src/gamelog/"), "prolog_in", .{});

    prolog_run.setCwd(prolog_input_dir);
    prolog_run.addArg("-q"); // Not-quiet for now
    prolog_run.addArg("parse.zy");
    prolog_run.step.dependOn(&prolog_write_in.step);

    const prolog_write_out = b.addWriteFiles();
    prolog_write_out.step.dependOn(&prolog_run.step);

    const prolog_rootdir = prolog_write_out.addCopyDirectory(prolog_input_dir, "", .{
        .exclude_extensions = &.{"zy"},
    });

    const prolog_grammar_install = b.addInstallFile(prolog_rootdir.path(b, "parse.zig"), "gamelog/parse.zig");
    prolog_grammar_install.step.dependOn(&prolog_write_out.step);
    const prolog_tokens_install = b.addInstallFile(prolog_rootdir.path(b, "TokenKind.zig"), "gamelog/TokenKind.zig");
    prolog_tokens_install.step.dependOn(&prolog_write_out.step);
    const prolog_out_install = b.addInstallFile(prolog_rootdir.path(b, "parse.out"), "gamelog/parse.out");
    prolog_out_install.step.dependOn(&prolog_write_out.step);

    const prolog_mod = b.addModule("prolog_parser", .{
        .root_source_file = prolog_rootdir.path(b, "parse.zig"),
        .target = target,
        .optimize = optimize,
    });

    const prolog_unit_tests = b.addTest(.{
        .filters = test_filters,
        .root_module = prolog_mod,
    });

    const run_prolog_unit_tests = b.addRunArtifact(prolog_unit_tests);

    const edn_run = b.addRunArtifact(zitron_exe);

    const edn_write_in = b.addWriteFiles();

    const edn_input_dir = edn_write_in.addCopyDirectory(b.path("src/edn/"), "edn_in", .{});

    edn_run.setCwd(edn_input_dir);
    edn_run.addArg("-q"); // Not-quiet for now
    edn_run.addArg("--clean-exit");
    edn_run.addArg("edn.zy");
    edn_run.step.dependOn(&edn_write_in.step);

    const edn_write_out = b.addWriteFiles();
    edn_write_out.step.dependOn(&edn_run.step);

    const edn_rootdir = edn_write_out.addCopyDirectory(edn_input_dir, "", .{
        .exclude_extensions = &.{"zy"},
    });

    const edn_grammar_install = b.addInstallFile(edn_rootdir.path(b, "edn.zig"), "edn/edn.zig");
    edn_grammar_install.step.dependOn(&edn_write_out.step);
    const edn_tokens_install = b.addInstallFile(edn_rootdir.path(b, "TokenKind.zig"), "edn/TokenKind.zig");
    edn_tokens_install.step.dependOn(&edn_write_out.step);
    const edn_out_install = b.addInstallFile(edn_rootdir.path(b, "edn.out"), "edn/edn.out");
    edn_out_install.step.dependOn(&edn_write_out.step);

    const edn_mod = b.addModule("edn_parser", .{
        .root_source_file = edn_rootdir.path(b, "edn.zig"),
        .target = target,
        .optimize = optimize,
    });

    const edn_unit_tests = b.addTest(.{
        .filters = test_filters,
        .root_module = edn_mod,
    });

    const run_edn_unit_tests = b.addRunArtifact(edn_unit_tests);

    const edn_step = b.step("edn", "Run edn tests");
    edn_step.dependOn(&run_edn_unit_tests.step);

    const grammars_step = b.step("grammars", "Install grammar files");
    grammars_step.dependOn(&prolog_grammar_install.step);
    grammars_step.dependOn(&prolog_tokens_install.step);
    grammars_step.dependOn(&prolog_out_install.step);
    grammars_step.dependOn(&calc_grammar_install.step);
    grammars_step.dependOn(&calc_tokens_install.step);
    grammars_step.dependOn(&edn_grammar_install.step);
    grammars_step.dependOn(&edn_tokens_install.step);
    grammars_step.dependOn(&edn_out_install.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_calc_unit_tests.step);
    test_step.dependOn(&run_prolog_unit_tests.step);
    test_step.dependOn(&run_edn_unit_tests.step);
}
