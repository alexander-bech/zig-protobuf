# zig-protobuf

<img src="logo.svg" width="50%">


## State of the implementation

This repository, so far, only aims at implementing [protocol buffers version 3](https://developers.google.com/protocol-buffers/docs/proto3#simple).

This project is mature enough to be used in production.

json encoding/decoding is considered a beta feature.

## Branches

There are 2 branches you can use for your development.

* `master` is the branch with current developments, working with the latest stable release of zig.
* `zig-master` is a branch that merges the developments in master, but works with the latest-ish master version of zig. 

## Zig version

This checkout targets Zig `0.17.0-dev.2056+79a9897cd` (see
`minimum_zig_version` in `build.zig.zon`). Older Zig releases are not supported
by these build scripts; later development snapshots may introduce further API changes.

Validate an upgrade with `zig build`, `zig build test`, `zig build bootstrap`,
then build and test again.

## How to use

1. Add `protobuf` to your `build.zig.zon`.  
    ```sh
    zig fetch --save "git+https://github.com/Arwalk/zig-protobuf#master"
    ```
1. Use the `protobuf` module. In your `build.zig`'s build function, add the dependency as module before
`b.installArtifact(exe)`.
    ```zig
    pub fn build(b: *std.Build) !void {
        // first create a build for the dependency
        const protobuf_dep = b.dependency("protobuf", .{
            .target = target,
            .optimize = optimize,
        });

        // and lastly use the dependency as a module
        exe.root_module.addImport("protobuf", protobuf_dep.module("protobuf"));
    }
    ```

## Generating .zig files out of .proto definitions

You can do this programatically as a compilation step for your application. The following snippet shows how to create a `zig build gen-proto` command for your project.

```zig
const protobuf = @import("protobuf");

pub fn build(b: *std.Build) !void {
    // first create a build for the dependency
    const protobuf_dep = b.dependency("protobuf", .{
        .target = target,
        .optimize = optimize,
    });
    
    ...

    const gen_proto = b.step("gen-proto", "generates zig files from protocol buffer definitions");

    const protoc_step = protobuf.RunProtocStep.create(protobuf_dep.builder, target, .{
        // out directory for the generated zig files
        .destination_directory = b.path("src/proto"),
        .source_paths = &.{b.path("protocol/all.proto")},
        .include_paths = &.{b.path("protocol")},
    });

    gen_proto.dependOn(&protoc_step.step);
}
```

Generation uses standard run steps: protoc writes to the build cache, Zig formats
those outputs, and a host-side helper copies them into `destination_directory`
without deleting unrelated files. `create` builds the plugin for the host;
`createWithGenerator` expects a host-runnable generator. Both return a
`*std.Build.Step.Run`, so `&protoc_step.step` and `protoc_step.setName(...)` work.
The legacy `source_files` and `include_directories` string options are relative
to the supplied builder's root; prefer lazy paths for files owned by another package.

-------

The zig-protobuf logo is licensed under the Attribution 4.0 International (CC BY 4.0).

The logo is inspired by the [official mascots](https://github.com/ziglang/logo?tab=readme-ov-file#official-mascots) of the Zig programming language, themselves licensed under the Attribution 4.0 International (CC BY 4.0)

Original art by vivisector.

-------

If you're really bored, you can buy me a coffee here.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/N4N7VMS4F)
