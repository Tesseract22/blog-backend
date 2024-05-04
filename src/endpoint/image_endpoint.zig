const std = @import("std");
const zap = @import("zap");
const Sqlite = @import("../sqlite.zig");
const Data = @import("../data.zig");
const idFromPath = @import("../util.zig").idFromPath;
const memeql = std.mem.eql;
const Self = @This();
const Config = @import("../config.zig");
const PublicFolder = Config.PublicFolder;
const ImageFolder = Config.ImageFolder;

alloc: std.mem.Allocator,
endpoint: zap.Endpoint,
id: std.Thread.Id,
pub fn init(
    a: std.mem.Allocator,
    user_path: []const u8,
) Self {
    return .{
        .alloc = a,
        .endpoint = zap.Endpoint.init(.{
            .path = user_path,
            .post = postImage,
            .get = getImage,
        }),
        .id = std.Thread.getCurrentId(),
    };
}

const SaveImageError = error{UnsupportedFormat};
// TODO: Error handling
fn SaveImage(self: Self, filename: []const u8, data: []const u8) SaveImageError![ImageFolder.len + 10 + 5]u8 {
    const time_stamp = std.time.microTimestamp();
    const first_half: u32 = @intCast(time_stamp & 0x00000000ffffffff);
    const second_half: u32 = @intCast(time_stamp >> 32);
    var it = std.mem.splitBackwardsScalar(u8, filename, '.');
    const ext = it.first();
    if (ext.len > 4) {
        std.log.err("does not support ext ({s}) len > 4", .{ext});
        return error.UnsupportedFormat;
    }

    var hash = std.hash.XxHash32.hash(0, filename);
    hash ^= std.hash.uint32(first_half);
    hash ^= std.hash.uint32(second_half);
    hash ^= std.hash.uint32(self.id);

    var name_buf: [PublicFolder.len + ImageFolder.len + 10 + 5]u8 = undefined;
    @memset(&name_buf, 0);
    const hash_path = std.fmt.bufPrint(&name_buf, PublicFolder ++ ImageFolder ++ "{}.{s}", .{ hash, ext }) catch unreachable;
    const f = std.fs.cwd().createFile(hash_path, .{ .read = true, .truncate = true }) catch unreachable;
    f.writeAll(data) catch unreachable;
    return name_buf[PublicFolder.len..].*;
}

pub fn getEndpoint(self: *Self) *zap.Endpoint {
    return &self.endpoint;
}

fn postImage(e: *zap.Endpoint, r: zap.Request) void {
    const self = @as(*Self, @fieldParentPtr("endpoint", e));

    r.parseBody() catch |err| {
        std.log.err("Parse Body error: {any}. Expected if body is empty", .{err});
    };
    r.parseQuery();

    const params = r.parametersToOwnedList(self.alloc, false) catch unreachable;
    defer params.deinit();
    for (params.items) |kv| {
        if (kv.value) |v| {
            switch (v) {
                // single-file upload
                zap.Request.HttpParam.Hash_Binfile => |*file| {
                    const filename = file.filename orelse "(no filename)";
                    const data = file.data orelse "";
                    const hash_path = self.SaveImage(filename, data) catch return;
                    r.sendBody(&hash_path) catch return;

                    // std.log.debug("    contents: {any}\n", .{data});
                },
                // multi-file upload
                zap.Request.HttpParam.Array_Binfile => |*files| {
                    // for (files.*.items) |file| {
                    //     const filename = file.filename orelse "(no filename)";
                    //     const data = file.data orelse "";
                    //     self.SaveImage(filename, data);
                    //     // std.log.debug("    contents: {any}\n", .{data});
                    // }
                    std.log.err("Multiple files upload unsupported", .{});
                    r.sendBody("Multiple files upload unsupported") catch return;
                    files.*.deinit();
                },
                else => {
                    // might be a string param, we don't care
                    // let's just get it as string
                    // if (r.getParamStr(self.alloc, kv.key.str, self.alloc, false)) |maybe_str| {
                    //     const value: []const u8 = if (maybe_str) |s| s.str else "(no value)";

                    //     std.log.debug("   {s} = {s}", .{ kv.key.str, value });
                    // } else |err| {
                    //     std.log.err("Error: {any}\n", .{err});
                    // }
                },
            }
        }
    }
}

fn getImage(e: *zap.Endpoint, r: zap.Request) void {
    _ = e;
    std.log.debug("getImage", .{});
    const path = r.path orelse return r.setStatus(.not_found);
    const ext = std.fs.path.extension(path);
    const name = path[0 .. path.len - ext.len];
    std.log.info("{s} {s}", .{ name, ext });
    if (!std.mem.eql(u8, ext, ".webp")) return r.setStatus(.not_found);
    return;
}
