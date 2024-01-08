const std = @import("std");

pub fn build(b: *std.Build) !void {

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const pass = b.option([]const u8, "pass", "Generating Password for admin");
    if (pass) |password| {
        const hash = std.hash_map.hashString(password);
        const len = @typeInfo(@TypeOf(hash)).Int.bits / 4;
        var buf: [len]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "{x:0>16}", .{hash}) catch unreachable;
        var auth_file = try std.fs.cwd().openFile(b.pathFromRoot("src/auth"), .{.mode = .write_only});
        defer auth_file.close();
        _ = try auth_file.writeAll(&buf);        
    }



    const exe = b.addExecutable(.{
        .name = "backend",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // zap
    const zap = b.dependency("zap", .{});
    exe.addModule("zap", zap.module("zap"));
    exe.linkLibrary(zap.artifact("facil.io"));

    // spltie3
    const sqlite = b.dependency("sqlite", .{
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("sqlite", sqlite.module("sqlite"));
    exe.linkLibrary(sqlite.artifact("sqlite"));


    b.installArtifact(exe);
}
