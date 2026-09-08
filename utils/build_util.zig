const std = @import("std");
const builtin = @import("builtin");

pub const PROTOC_VERSION = "32.1";

pub fn getProtocDependency(b: *std.Build) !?*std.Build.Dependency {
    const os: ?[]const u8 = switch (builtin.os.tag) {
        .macos => "osx",
        .linux => "linux",
        else => null,
    };
    const arch: ?[]const u8 = switch (builtin.cpu.arch) {
        .powerpcle, .powerpc64le => "ppcle",
        .aarch64, .aarch64_be => "aarch_64",
        .s390x => "s390",
        .x86_64 => "x86_64",
        .x86 => "x86_32",
        else => null,
    };
    const name = if (builtin.os.tag == .windows)
        "protoc-win64"
    else if (os != null and arch != null)
        b.fmt("protoc-{s}-{s}", .{ os.?, arch.? })
    else
        @panic("Platform not supported");
    return b.lazyDependency(name, .{});
}

/// Constructs standard build steps while preserving `&conversion.step` callers.
pub const RunProtocStep = struct {
    pub const Options = struct {
        /// Paths relative to the owner's build root (legacy convenience API).
        source_files: []const []const u8 = &.{},
        include_directories: []const []const u8 = &.{},
        source_paths: []const std.Build.LazyPath = &.{},
        include_paths: []const std.Build.LazyPath = &.{},
        destination_directory: std.Build.LazyPath,
    };

    pub fn create(owner: *std.Build, target: std.Build.ResolvedTarget, options: Options) *std.Build.Step.Run {
        // The plugin runs on the build host, even when generating for another target.
        _ = target;
        return createWithGenerator(owner, buildGenerator(owner, .{ .target = owner.graph.host }), options);
    }

    pub fn createWithGenerator(owner: *std.Build, generator: *std.Build.Step.Compile, options: Options) *std.Build.Step.Run {
        const fmt = std.Build.Step.Run.create(owner, "format protobuf sources");
        fmt.addFileArg(.zig_exe);
        fmt.addArg("fmt");
        fmt.has_side_effects = true;
        const protoc = getProtocDependency(owner) catch @panic("Unable to load protoc dependency");
        if (protoc == null) return fmt; // Build will reconfigure after fetching lazy dependencies.

        const run = std.Build.Step.Run.create(owner, "run protoc");
        run.addFileArg(protoc.?.path(if (builtin.os.tag == .windows) "bin/protoc.exe" else "bin/protoc"));
        run.addPrefixedArtifactArg("--plugin=protoc-gen-zig=", generator);
        const generated = run.addPrefixedOutputDirectoryArg("--zig_out=", "generated");
        fmt.addDirectoryArg(generated);
        run.addPrefixedDirectoryArg("-I", protoc.?.path("include"));
        if (options.include_directories.len == 0 and options.include_paths.len == 0)
            run.addPrefixedDirectoryArg("-I", owner.path("."));
        for (options.include_directories) |path| run.addPrefixedDirectoryArg("-I", owner.path(path));
        for (options.include_paths) |path| run.addPrefixedDirectoryArg("-I", path);
        for (options.source_files) |path| run.addFileArg(owner.path(path));
        for (options.source_paths) |path| run.addFileArg(path);

        // Generated filenames depend on proto package declarations, so copy the
        // output tree at execution time rather than guessing filenames here.
        const copier = owner.addExecutable(.{
            .name = "copy-protobuf-sources",
            .root_module = owner.createModule(.{
                .root_source_file = owner.path(std.fs.path.dirname(@src().file) orelse ".").path(owner, "copy_generated.zig"),
                .target = owner.graph.host,
            }),
        });
        const copy = owner.addRunArtifact(copier);
        copy.addDirectoryArg(generated);
        copy.addDirectoryArg(options.destination_directory);
        copy.has_side_effects = true;

        copy.step.dependOn(&fmt.step);
        return copy;
    }
};

pub const GenOptions = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode = .Debug,
};

pub fn buildGenerator(b: *std.Build, opt: GenOptions) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "protoc-gen-zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bootstrapped-generator/main.zig"),
            .target = opt.target,
            .optimize = opt.optimize,
        }),
    });
    const module = b.createModule(.{
        .root_source_file = b.path("src/protobuf.zig"),
    });
    exe.root_module.addImport("protobuf", module);
    return exe;
}
