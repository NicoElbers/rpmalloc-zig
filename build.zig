const Opts = struct {
    upstream: *Build.Dependency,
    target: Target,
    optimize: Optimize,
};

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("upstream", .{});

    const opts: Opts = .{
        .upstream = upstream,
        .target = target,
        .optimize = optimize,
    };

    // rpmalloc_lib
    {
        const rpmalloc = rpmallocMod("static", b, opts);

        const lib = b.addLibrary(.{
            .name = "rpmalloc_static",
            .root_module = rpmalloc,
            .linkage = .static,
        });

        b.installArtifact(lib);
    }

    // rpmalloc_test_lib
    const rpmalloc_test_lib: *Build.Step.Compile = blk: {
        const rpmalloc = rpmallocMod("test", b, opts);
        rpmalloc.addCMacro("ENABLE_ASSERTS", "1");
        rpmalloc.addCMacro("ENABLE_STATISTICS", "1");
        rpmalloc.addCMacro("RPMALLOC_FIRST_CLASS_HEAPS", "1");

        const lib = b.addLibrary(.{
            .name = "rpmalloc-test",
            .root_module = rpmalloc,
            .linkage = .static,
        });

        b.installArtifact(lib);
        break :blk lib;
    };

    if (target.result.abi.isAndroid()) return;

    // rpmalloc_so
    {
        const rpmalloc = rpmallocMod("dynamic", b, opts);

        const lib = b.addLibrary(.{
            .name = "rpmalloc_dynamic",
            .root_module = rpmalloc,
            .linkage = .dynamic,
        });

        b.installArtifact(lib);
    }

    // rpmalloc_wrap_so
    {
        const rpmalloc = rpmallocMod("wrap_static", b, opts);
        rpmalloc.addCMacro("ENABLE_PRELOAD", "1");
        rpmalloc.addCMacro("ENABLE_OVERRIDE", "1");

        const lib = b.addLibrary(.{
            .name = "rpmallocwrap_static",
            .root_module = rpmalloc,
            .linkage = .dynamic,
        });

        b.installArtifact(lib);
    }

    // rpmalloc_wrap_lib
    const rpmalloc_wrap_lib: *Build.Step.Compile = blk: {
        const rpmalloc = rpmallocMod("wrap_dynamic", b, opts);
        rpmalloc.addCMacro("ENABLE_PRELOAD", "1");
        rpmalloc.addCMacro("ENABLE_OVERRIDE", "1");

        const lib = b.addLibrary(.{
            .name = "rpmallocwrap_dynamic",
            .root_module = rpmalloc,
            .linkage = .static,
        });

        b.installArtifact(lib);

        break :blk lib;
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
        // rpmalloc_test_mod.addIncludePath(upstream.path("rpmalloc"));

        const art = rpmalloc_test_lib;
        for (art.root_module.include_dirs.items) |inc| {
            rpmalloc_test_mod.include_dirs.append(b.allocator, inc) catch @panic("OOM");
        }

        rpmalloc_test_mod.addCMacro("_GNU_SOURCE", "1");
        rpmalloc_test_mod.addCMacro("ENABLE_ASSERTS", "1");
        rpmalloc_test_mod.addCMacro("ENABLE_STATISTICS", "1");
        rpmalloc_test_mod.addCMacro("RPMALLOC_FIRST_CLASS_HEAPS", "1");
        rpmalloc_test_mod.addCMacro("RPMALLOC_CONFIGURABLE", "1");

        rpmalloc_test_mod.linkLibrary(rpmalloc_test_lib);

        const rpmalloc_test = b.addExecutable(.{
            .name = "rpmalloc-test",
            .root_module = rpmalloc_test_mod,
        });
        b.installArtifact(rpmalloc_test);
    }

    // rpmallocwrap-test
    {
        const rpmallocwrap_test_mod = b.addModule("rpmalloc-test", .{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
            .stack_protector = false,
        });
        rpmallocwrap_test_mod.addCSourceFile(.{
            .file = upstream.path("test/thread.c"),
            .flags = &.{},
        });
        rpmallocwrap_test_mod.addCSourceFile(.{
            .file = upstream.path("test/main-override.cc"),
            .flags = &.{},
        });

        rpmallocwrap_test_mod.addIncludePath(upstream.path("test"));
        // rpmallocwrap_test_mod.addIncludePath(upstream.path("rpmalloc"));

        const art = rpmalloc_wrap_lib;
        for (art.root_module.include_dirs.items) |inc| {
            rpmallocwrap_test_mod.include_dirs.append(b.allocator, inc) catch @panic("OOM");
        }

        rpmallocwrap_test_mod.addCMacro("_GNU_SOURCE", "1");
        rpmallocwrap_test_mod.addCMacro("ENABLE_ASSERTS", "1");
        rpmallocwrap_test_mod.addCMacro("ENABLE_STATISTICS", "1");

        rpmallocwrap_test_mod.linkLibrary(rpmalloc_wrap_lib);

        const rpmallocwrap_test = b.addExecutable(.{
            .name = "rpmallocwrap-test",
            .root_module = rpmallocwrap_test_mod,
        });
        b.installArtifact(rpmallocwrap_test);
    }
}

fn rpmallocMod(name: []const u8, b: *Build, opts: Opts) *Module {
    const rpmalloc = b.addModule(name, .{
        .target = opts.target,
        .optimize = opts.optimize,
        .link_libc = true,
        .stack_protector = false,
    });

    rpmalloc.addIncludePath(opts.upstream.path("rpmalloc"));

    rpmalloc.addCSourceFile(.{
        .file = opts.upstream.path("rpmalloc/rpmalloc.c"),
        .flags = &.{},
    });

    return rpmalloc;
}

const std = @import("std");

const Build = std.Build;
const Module = Build.Module;
const Target = Build.ResolvedTarget;
const Optimize = std.builtin.OptimizeMode;
