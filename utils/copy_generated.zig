//! Copy protoc's dynamically named outputs without deleting unrelated sources.
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 3) return error.InvalidArguments;
    const io = init.io;
    var source = try std.Io.Dir.cwd().openDir(io, args[1], .{ .iterate = true });
    defer source.close(io);
    var destination = try std.Io.Dir.cwd().createDirPathOpen(io, args[2], .{});
    defer destination.close(io);
    var walker = try source.walk(init.gpa);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        if (entry.kind == .file)
            _ = try entry.dir.updateFile(io, entry.basename, destination, entry.path, .{});
    }
}
