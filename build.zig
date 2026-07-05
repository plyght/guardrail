const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    // Ship a fast binary by default; `zig build -Doptimize=Debug` opts back in.
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    linkLibgit2(exe_mod);
    const exe = b.addExecutable(.{ .name = "gr", .root_module = exe_mod });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the gr binary");
    run_step.dependOn(&run_cmd.step);

    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        // Tests always run in Debug for leak detection and safety checks.
        .optimize = .Debug,
        .link_libc = true,
    });
    linkLibgit2(test_mod);
    const tests = b.addTest(.{ .root_module = test_mod });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
}

fn linkLibgit2(m: *std.Build.Module) void {
    // Homebrew locations (Apple Silicon + Intel).
    m.addIncludePath(.{ .cwd_relative = "/opt/homebrew/include" });
    m.addLibraryPath(.{ .cwd_relative = "/opt/homebrew/lib" });
    m.addIncludePath(.{ .cwd_relative = "/usr/local/include" });
    m.addLibraryPath(.{ .cwd_relative = "/usr/local/lib" });
    m.linkSystemLibrary("git2", .{});
}
