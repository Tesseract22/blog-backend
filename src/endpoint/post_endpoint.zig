//! This is enpoint responsible for any visist for /post
//! GET /post/<id> | /post
//! PATCH /post/<id> | /post (retreives only metadata)
//! POST /post/<id> <= JSON(post)
//! PUT /post/<id> <= JSON(post)
//! DELETE /post/<id> <= JSON(post)
//! See also: `Post`
const std = @import("std");
const builtin = @import("builtin");
const zap = @import("zap");
const Sqlite = @import("../sqlite.zig");
const SqliteError = Sqlite.SqliteError;
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
    const path = r.path orelse return r.setStatus(.bad_request);
    // /users
    const path_trim = trimPath(path);

    if (path_trim.len == self.path.len) {
        self.listPost(arena, db, r, !VerifyCookie(r)) catch return r.setStatus(.internal_server_error);
        return r.setStatus(.ok);
    }
    // get the ip from headers
    // this must be done before we send the final result
    const ip_str = if (builtin.mode == .Debug) "127.0.0.1" else r.getHeader("x-forwarded-for") orelse r.getHeader("remote_addr") orelse r.getHeader("x-real-ip") orelse r.getHeader("host") orelse "";
    const ip_addr: ?std.net.Ip4Address = std.net.Ip4Address.parse(ip_str, 0) catch null;
    // post as in article post, not the method POST
    const post_id = self.postIdFromPath(path_trim) orelse return r.setStatus(.bad_request);
    const post_data = (db.getPost(post_id, arena) catch return r.setStatus(.internal_server_error)) orelse return r.setStatus(.not_found);
    if (!post_data.published.? and !VerifyCookie(r)) return r.setStatus(.unauthorized);
    const json = std.json.stringifyAlloc(arena, post_data, .{}) catch return r.setStatus(.internal_server_error);
    r.sendJson(json) catch return r.setStatus(.internal_server_error);
    // storing ip
    if (ip_addr) |addr| {
        const ip_id = db.insertIpAddr(addr.sa.addr) catch |err| return std.log.warn("{any} Unexpected Error while inserting ip address", .{err});
        if (db.insertIpMap(ip_id, post_id, @divTrunc(std.time.microTimestamp(), 1000))) {
            db.updatePostViews(post_id, 1) catch return r.setStatus(.internal_server_error);
        } else |err| {
            switch (err) {
                SqliteError.SQLiteConstraint => {},
                else => std.log.warn("Unexpected error {} while inserting into ipmap", .{err}),
            }
        }
    } else {
        std.log.warn("Unable to get IP from header", .{});
    }
    return r.setStatus(.ok);
}

fn listPost(_: *Self, arena: std.mem.Allocator, db: *Sqlite, r: zap.Request, published_only: bool) !void {
    const posts = if (published_only) try db.listPostPublished(arena) else try db.listPost(arena);
    const json = try std.json.stringifyAlloc(arena, posts, .{});
    try r.sendJson(json);
}

/// POST /post/ (JSON.post) => ok
/// else => bad_request
/// The jso
pub fn post(_: *Self, arena: std.mem.Allocator, db: *Sqlite, r: zap.Request) !void {
    if (!VerifyCookie(r)) return r.setStatus(.unauthorized);
    if (r.body) |body| {
        const post_data = std.json.parseFromSlice(Post, arena, body, .{}) catch |err| {
            std.log.err("[{}] Failedt to parse Json: {s}", .{ err, body });
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
