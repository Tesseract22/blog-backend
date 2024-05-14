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
image_dir: std.fs.Dir,
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
        .image_dir = std.fs.cwd().openDir(PublicFolder ++ ImageFolder, .{.iterate = true}) catch unreachable,
        .id = std.Thread.getCurrentId(),
    };
}

const SaveImageError = error{UnsupportedFormat, FileAccessError};
// TODO: Error handling
// fn SaveImage(self: Self, id: usize, filename: []const u8, data: []const u8) SaveImageError![ImageFolder.len + 10 + 5]u8 {
//     const time_stamp = std.time.microTimestamp();
//     const first_half: u32 = @intCast(time_stamp & 0x00000000ffffffff);
//     const second_half: u32 = @intCast(time_stamp >> 32);
//     var it = std.mem.splitBackwardsScalar(u8, filename, '.');
//     const ext = it.first();
//     if (ext.len > 4) {
//         std.log.err("does not support ext ({s}) len > 4", .{ext});
//         return error.UnsupportedFormat;
//     }

//     var hash = std.hash.XxHash32.hash(0, filename);
//     hash ^= std.hash.uint32(first_half);
//     hash ^= std.hash.uint32(second_half);
//     hash ^= std.hash.uint32(self.id);

//     var name_buf: [PublicFolder.len + ImageFolder.len + 10 + 5]u8 = undefined;
//     @memset(&name_buf, 0);
//     const hash_path = std.fmt.bufPrint(&name_buf, PublicFolder ++ ImageFolder ++ "{}.{s}", .{ hash, ext }) catch unreachable;
//     const f = std.fs.cwd().createFile(hash_path, .{ .read = true, .truncate = true }) catch unreachable;
//     f.writeAll(data) catch unreachable;
//     return name_buf[PublicFolder.len..].*;
// }
fn SaveImage(self: Self, id: usize, filename: []const u8, data: []const u8) SaveImageError!void {
    const cwd = std.fs.cwd();
    var buf = [_]u8 {0} ** 20;
    const id_buf = std.fmt.bufPrint(&buf, "{}", .{id}) catch unreachable;
    cwd.makeDir(id_buf) catch |e| switch (e) {
        std.posix.MakeDirError.PathAlreadyExists => {},
        else => return SaveImageError.FileAccessError,
    };
    var article_dir = self.image_dir.openDir(id_buf, .{}) catch return SaveImageError.FileAccessError;
    defer article_dir.close();
    var f = article_dir.createFile(filename, .{}) catch return SaveImageError.FileAccessError;
    defer f.close();
    _ = f.write(data) catch return SaveImageError.FileAccessError;
}
fn listImage(self: *Self) void {
    _ = self; // autofix
    
}

pub fn getEndpoint(self: *Self) *zap.Endpoint {
    return &self.endpoint;
}
fn postIdFromPath(self: *Self, path: []const u8) ?usize {
    return idFromPath(self.endpoint.settings.path.len, path);
}

/// POST  /image/<i>
fn postImage(e: *zap.Endpoint, r: zap.Request) void {
    const self = @as(*Self, @fieldParentPtr("endpoint", e));
    const path = r.path orelse return r.setStatus(.bad_request);
    const id = self.postIdFromPath(path) orelse return r.setStatus(.bad_request);
    r.parseBody() catch |err| {
        std.log.err("Parse Body error: {any}. Expected if body is empty", .{err});
        return r.setStatus(.bad_request);
    };
    r.parseQuery();

    const params = r.parametersToOwnedList(self.alloc, false) catch unreachable;
    defer params.deinit();
    for (params.items) |kv| {
        std.log.debug("param", .{});
        if (kv.value) |v| {
            switch (v) {
                // single-file upload
                zap.Request.HttpParam.Hash_Binfile => |*file| {
                    const filename = file.filename orelse "(no filename)";
                    const data = file.data orelse "";
                    self.SaveImage(id, filename, data) catch return r.setStatus(.internal_server_error);
                    
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
                    r.sendBody("Multiple files upload unsupported") catch return r.setStatus(.internal_server_error);
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
                    std.log.debug("unsupported param", .{});
                },
            }
        }
    }
}

fn getImage(e: *zap.Endpoint, r: zap.Request) void {
    const self = @as(*Self, @fieldParentPtr("endpoint", e));
    const path = r.path orelse return r.setStatus(.bad_request);
    const id = self.postIdFromPath(path) orelse return r.setStatus(.bad_request);
    std.log.debug("getImage on: {}", .{id});

    var buf = [_]u8 {0} ** 20;
    const id_buf = std.fmt.bufPrint(&buf, "{}", .{id}) catch unreachable;

    var dir = self.image_dir.openDir(id_buf, .{.iterate = true}) catch |err| switch (err) {
        error.FileNotFound => 
            return r.sendJson("[]") catch r.setStatus(.internal_server_error),
        else => return r.setStatus(.internal_server_error),
    };
    defer dir.close();
    var list = std.ArrayList([]const u8).init(self.alloc);
    defer {
        for (list.items) |s| {
            self.alloc.free(s);
        }
        list.deinit();
    }
    var it = dir.iterate();
    while (it.next() catch return r.setStatus(.internal_server_error)) |entry| {
        list.append(self.alloc.dupe(u8, entry.name) catch unreachable) catch r.setStatus(.internal_server_error);
    }
    const json = std.json.stringifyAlloc(self.alloc, list.items, .{}) catch return r.setStatus(.internal_server_error);
    defer self.alloc.free(json);
    r.sendJson(json) catch r.setStatus(.internal_server_error);
    r.markAsFinished(true);
    
}

fn deleteImage(e: *zap.Endpoint, r: zap.Request) void {
    const self = @as(*Self, @fieldParentPtr("endpoint", e));
    const path = r.path orelse return r.setStatus(.bad_request);
    self.image_dir.deleteFile(path) catch |err| {
        std.log.debug("Failed to delete file `{s}`: {}", .{path, err});
        return r.setStatus(.bad_request);
    };
    
}
