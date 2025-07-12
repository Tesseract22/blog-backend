//! This is enpoint responsible for any visist for /post
//! GET /post/<id> | /post
//! POST /post/<id> <= JSON(post)
//! PUT /post/<id> <= JSON(post)
//! DELETE /post/<id> <= JSON(post)
//! See also: `Post`
const std = @import("std");
const zap = @import("zap");
const Sqlite = @import("../sqlite.zig");
const Post = @import("../data.zig").Post;
const idFromPath = @import("../util.zig").idFromPath;
const VerifyCookie = @import("../util.zig").VerifyCookie;
// an Endpoint

pub const Self = @This();

path: []const u8,
error_strategy: zap.Endpoint.ErrorStrategy = .log_to_console,

fn postIdFromPath(self: *Self, path: []const u8) ?usize {
    return idFromPath(self.path.len, path);
}

fn trimPath(path: []const u8) []const u8 {
    return if (path[path.len - 1] == '/') path[0 .. path.len - 1] else path;
}

/// GET /post/<id> => post[<id>]
/// GET /post => []post
/// else => bad_request
pub fn get(self: *Self, arena: std.mem.Allocator, db: *Sqlite, r: zap.Request) !void {
    if (r.path) |path| {
        // /users
        const path_trim = trimPath(path);

        if (path_trim.len == self.path.len) {
            try self.listPost(arena, db, r);
            return r.setStatus(.ok);
        }

        if (self.postIdFromPath(path_trim)) |id| {
            const post_data = (try db.getPost(id, arena)) orelse return r.setStatus(.not_found);
            const json = try std.json.stringifyAlloc(arena, post_data, .{});
            try r.sendJson(json);
        }
        return r.setStatus(.ok);
    } else {
        return r.setStatus(.bad_request);
    }
}

fn listPost(_: *Self, arena: std.mem.Allocator, db: *Sqlite, r: zap.Request) !void {
    const posts = try db.listPost(arena);
    const json = try std.json.stringifyAlloc(arena, posts, .{});
    try r.sendJson(json);
}
/// POST /post/ (JSON.post) => ok
/// else => bad_request
/// The jso
pub fn post(_: *Self, arena: std.mem.Allocator, db: *Sqlite, r: zap.Request) !void {
    if (!VerifyCookie(r)) return r.setStatus(.unauthorized);
    if (r.body) |body| {
        const post_data = std.json.parseFromSlice(Post, arena, body, .{}) catch {
            std.log.err("Cannot Parse Json: {s}", .{body});
            return r.setStatus(.bad_request);
        };
        if (post_data.value.id != null) {
            return r.setStatus(.bad_request);
        }

        const id = db.insertPost(post_data.value) catch {
            return r.setStatus(.internal_server_error);
        };
        const json = try std.json.stringifyAlloc(arena, .{ .id = id }, .{});
        try r.sendJson(json);
        return r.setStatus(.ok);
    }
    r.setStatus(.bad_request);
}

pub fn put(self: *Self, arena: std.mem.Allocator, db: *Sqlite, r: zap.Request) !void {
    if (!VerifyCookie(r)) return r.setStatus(.unauthorized);
    if (r.body) |body| {
        var post_data = std.json.parseFromSlice(Post, arena, body, .{}) catch {
            std.log.err("Cannot parsed json {s}", .{body});
            return r.setStatus(.bad_request);
        };
        const id = self.postIdFromPath(trimPath(r.path orelse "")) orelse return r.setStatus(.bad_request);
        post_data.value.id = id;
        try db.updatePost(post_data.value);
        r.setStatus(.ok);
    } else {
        std.log.err("No body", .{});
        r.setStatus(.bad_request);
    }
}

pub fn patch(self: *Self, arena: std.mem.Allocator, db: *Sqlite, r: zap.Request) !void {
    if (r.path) |path| {
        if (self.postIdFromPath(path)) |id| {
            const post_data = try db.getPostMeta(id, arena) orelse return r.setStatus(.not_found);
            const json = try std.json.stringifyAlloc(arena, post_data, .{});
            try r.sendJson(json);
        }
    }
}

pub fn delete(self: *Self, _: std.mem.Allocator, db: *Sqlite, r: zap.Request) !void {
    if (!VerifyCookie(r)) return r.setStatus(.unauthorized);
    if (r.path) |path| {
        if (self.postIdFromPath(path)) |id| {
            std.log.debug("delete: {}", .{id});
            db.deletePost(id) catch {
                r.setStatus(.bad_request);
                return;
            };
            return;
        }
    }
    r.setStatus(.bad_request);
}

pub fn options(_: *Self, _: std.mem.Allocator, _: *Sqlite, _: zap.Request) !void {}
// TODO: retrieve post metadata with HEAD
pub fn head(_: *Self, _: std.mem.Allocator, _: *Sqlite, _: zap.Request) !void {}
