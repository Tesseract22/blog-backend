const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const password = b.option([]const u8, "password", "Generating Password for admin");
    const domain = b.option([]const u8, "domain", "Domain for the website, default to localhost in debug mode");

    if (password) |password_value| {
        const hash = std.hash_map.hashString(password_value);
        const len = @typeInfo(@TypeOf(hash)).int.bits / 4;
        var buf: [len]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "{x:0>16}", .{hash}) catch unreachable;
        var auth_file = try std.fs.cwd().createFile(b.pathFromRoot("src/auth"), .{});
        defer auth_file.close();
        _ = try auth_file.writeAll(&buf);
    }
    if (domain) |domain_value| {
        var file = try std.fs.cwd().createFile(b.pathFromRoot("src/domain"), .{});
        defer file.close();
        _ = try file.writeAll(domain_value);
    }    
    const main_mod = b.addModule("main", .{
        .root_source_file = .{ .src_path = .{ .owner = b, .sub_path = "src/main.zig" } },
        .target = target,
        .optimize = optimize,
    });
    // zap
    const zap = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
        .openssl = false,
    });
    main_mod.addImport("zap", zap.module("zap"));
    main_mod.linkLibrary(zap.artifact("facil.io"));

    // spltie3
    const sqlite = b.dependency("sqlite", .{
        .target = target,
        .optimize = optimize,
    });
    main_mod.addImport("sqlite", sqlite.module("sqlite"));
    // links the bundled sqlite3, so leave this out if you link the system one
    main_mod.linkLibrary(sqlite.artifact("sqlite"));
    // exe.linkSystemLibrary("sqlite3");

    const exe = b.addExecutable(.{
        .name = "backend",
        .root_module = main_mod,
    });

    b.installDirectory(.{
        .source_dir = exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "doc",
    });

    
    // tsc
    var tsc_exe = b.addSystemCommand(&.{"tsc"});
    tsc_exe.addArgs(&.{ "ts/admin.ts", "ts/common.ts", "--outDir", "public/js", "--target", "ES6" });
    var tsc_exe2 = b.addSystemCommand(&.{"tsc"});
    tsc_exe2.addArgs(&.{ "ts/article.ts", "ts/common.ts", "--outDir", "public/js", "--target", "ES6" });
    const tsc_step = b.step("tsc", "compile ts/*.ts -> public/js/*.js");
    tsc_step.dependOn(&tsc_exe2.step);
    tsc_step.dependOn(&tsc_exe.step);

    b.installArtifact(exe);
}

