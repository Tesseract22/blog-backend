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
    //const config_opts = b.addOptions();
    //config_opts.addOption([]const u8, "domain", domain);

    const exe = b.addExecutable(.{
        .name = "backend",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    //exe.root_module.addOptions("meta_config", config_opts);

    // zap
    const zap = b.dependency("zap", .{
        .target = target,
        .optimize = optimize,
        .openssl = false,
    });
    exe.root_module.addImport("zap", zap.module("zap"));
    exe.linkLibrary(zap.artifact("facil.io"));

    // spltie3
    const sqlite = b.dependency("sqlite", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("sqlite", sqlite.module("sqlite"));

    // links the bundled sqlite3, so leave this out if you link the system one
    exe.linkLibrary(sqlite.artifact("sqlite"));
    // exe.linkSystemLibrary("sqlite3");

    b.installArtifact(exe);
}
