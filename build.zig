pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("upstream", .{ .target = target, .optimize = optimize });

    // rpmalloc_lib
    {
        const rpmalloc = rpmallocMod("static", b, upstream, target, optimize);

        const rpmalloc_static = b.addLibrary(.{
            .name = "rpmalloc_static",
            .root_module = rpmalloc,
            .linkage = .static,
        });
        b.installArtifact(rpmalloc_static);
    }

    // rpmalloc_test_lib
    const rpmalloc_test_lib: *Build.Step.Compile = blk: {
        const rpmalloc = rpmallocMod("test", b, upstream, target, optimize);
        rpmalloc.addCMacro("ENABLE_ASSERTS", "1");
        rpmalloc.addCMacro("ENABLE_STATISTICS", "1");
        rpmalloc.addCMacro("RPMALLOC_FIRST_CLASS_HEAPS", "1");

        const rpmalloc_test_static = b.addLibrary(.{
            .name = "rpmalloc-test",
            .root_module = rpmalloc,
            .linkage = .static,
        });
        b.installArtifact(rpmalloc_test_static);
        break :blk rpmalloc_test_static;
    };

    if (target.result.abi.isAndroid()) return;

    // rpmalloc_so
    {
        const rpmalloc = rpmallocMod("dynamic", b, upstream, target, optimize);

        const rpmalloc_dynamic = b.addLibrary(.{
            .name = "rpmalloc_dynamic",
            .root_module = rpmalloc,
            .linkage = .dynamic,
        });
        b.installArtifact(rpmalloc_dynamic);
    }

    // rpmalloc_wrap_so
    {
        const rpmalloc = rpmallocMod("wrap_static", b, upstream, target, optimize);
        rpmalloc.addCMacro("ENABLE_PRELOAD", "1");
        rpmalloc.addCMacro("ENABLE_OVERRIDE", "1");

        const rpmallocwrap_dynamic = b.addLibrary(.{
            .name = "rpmallocwrap_static",
            .root_module = rpmalloc,
            .linkage = .dynamic,
        });
        b.installArtifact(rpmallocwrap_dynamic);
    }

    // rpmalloc_wrap_lib
    const rpmalloc_wrap_lib: *Build.Step.Compile = blk: {
        const rpmalloc = rpmallocMod("wrap_dynamic", b, upstream, target, optimize);
        rpmalloc.addCMacro("ENABLE_PRELOAD", "1");
        rpmalloc.addCMacro("ENABLE_OVERRIDE", "1");

        const rpmallocwrap_static = b.addLibrary(.{
            .name = "rpmallocwrap_dynamic",
            .root_module = rpmalloc,
            .linkage = .static,
        });
        b.installArtifact(rpmallocwrap_static);

        break :blk rpmallocwrap_static;
    };

    // rpmalloc-test
    {
        const rpmalloc_test_mod = b.addModule("rpmalloc-test", .{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .stack_protector = false,
        });
        rpmalloc_test_mod.addCSourceFile(.{
            .file = upstream.path("test/thread.c"),
            .flags = &.{},
        });
        rpmalloc_test_mod.addCSourceFile(.{
            .file = upstream.path("test/main.c"),
            .flags = &.{},
        });
        rpmalloc_test_mod.addIncludePath(upstream.path("test"));
        rpmalloc_test_mod.addIncludePath(upstream.path("rpmalloc"));

        rpmalloc_test_mod.addCMacro("_GNU_SOURCE", "1");
        rpmalloc_test_mod.addCMacro("ENABLE_ASSERTS", "1");
        rpmalloc_test_mod.addCMacro("ENABLE_STATISTICS", "1");
        rpmalloc_test_mod.addCMacro("RPMALLOC_FIRST_CLASS_HEAPS", "1");
        rpmalloc_test_mod.addCMacro("RPMALLOC_CONFIGURABLE", "1");

        rpmalloc_test_mod.addImport("rpmalloc_test_lib", rpmalloc_test_lib.root_module);

        const rpmalloc_test = b.addExecutable(.{
            .name = "rpmalloc-test",
            .root_module = rpmalloc_test_mod,
        });
        b.installArtifact(rpmalloc_test);
    }

    // rpmallocwrap-test
    {
        const rpmalloc_test = b.addModule("rpmalloc-test", .{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
            .stack_protector = false,
        });
        rpmalloc_test.addCSourceFile(.{
            .file = upstream.path("test/thread.c"),
            .flags = &.{},
        });
        rpmalloc_test.addCSourceFile(.{
            .file = upstream.path("test/main-override.cc"),
            .flags = &.{},
        });
        rpmalloc_test.addIncludePath(upstream.path("test"));
        rpmalloc_test.addIncludePath(upstream.path("rpmalloc"));

        rpmalloc_test.addCMacro("_GNU_SOURCE", "1");
        rpmalloc_test.addCMacro("ENABLE_ASSERTS", "1");
        rpmalloc_test.addCMacro("ENABLE_STATISTICS", "1");

        rpmalloc_test.addImport("rpmallocwrap_lib", rpmalloc_wrap_lib.root_module);

        const rpmallocwrap_test = b.addExecutable(.{
            .name = "rpmallocwrap-test",
            .root_module = rpmalloc_test,
        });
        b.installArtifact(rpmallocwrap_test);
    }
}

fn rpmallocMod(name: []const u8, b: *Build, upstream: *Build.Dependency, target: Target, optimize: Optimize) *Module {
    const rpmalloc = b.addModule(name, .{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .stack_protector = false,
    });

    rpmalloc.addCSourceFile(.{
        .file = upstream.path("rpmalloc/rpmalloc.c"),
        .flags = &.{},
    });

    return rpmalloc;
}

const std = @import("std");

const Build = std.Build;
const Module = Build.Module;
const Target = Build.ResolvedTarget;
const Optimize = std.builtin.OptimizeMode;
