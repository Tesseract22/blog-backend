const std = @import("std");
const zap = @import("zap");
const Sqlite = @import("../sqlite.zig");
const Data = @import("../data.zig");
const Comment = Data.Comment;
const CommentFull = Data.CommentFull;
const idFromPath = @import("../util.zig").idFromPath;
const AuthRequest = @import("../util.zig").AuthRequest;
pub const Self = @This();

path: []const u8 = "/post",
error_strategy: zap.Endpoint.ErrorStrategy = .log_to_console,

fn commentIdFromPath(self: *Self, path: []const u8) ?usize {
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
        if (self.commentIdFromPath(trimPath(path))) |id| {
            const comments = try db.getCommentsByPost(id, arena);
            const json = try std.json.stringifyAlloc(arena, comments, .{});
            try r.sendJson(json);
            return r.setStatus(.ok);
        }
    }
    return r.setStatus(.bad_request);
}

/// POST /post/<id> (JSON.post) => ok
/// else => bad_request
/// The jso
pub fn post(_: *Self, arena: std.mem.Allocator, db: *Sqlite, r: zap.Request) !void {
    if (r.body) |body| {
        var comment_ret = std.json.parseFromSlice(CommentFull, arena, body, .{}) catch return r.setStatus(.bad_request);
        defer comment_ret.deinit();
        var comment = comment_ret.value;
        if (comment.id != null or comment.commenter != null)
            return r.setStatus(.bad_request);
        comment.commenter = db.insertCommenterIfNotExist(.{ .email = comment.email, .username = comment.username }) catch {
            return r.setStatus(.unauthorized);
        };
        db.insertComment(.{ .created_time = comment.created_time, .content = comment.content, .commenter = comment.commenter, .post_id = comment.post_id }) catch return r.setStatus(.bad_request);
        return r.setStatus(.ok);
    }
    r.setStatus(.bad_request);
}

pub fn put(self: *Self, arena: std.mem.Allocator, db: *Sqlite, r: zap.Request) !void {
    if (!AuthRequest(r)) return r.setStatus(.unauthorized);
    if (r.body) |body| {
        var comment_ret = std.json.parseFromSlice(Comment, arena, body, .{}) catch return r.setStatus(.bad_request);
        defer comment_ret.deinit();
        var comment = comment_ret.value;
        const id = self.commentIdFromPath(trimPath(r.path orelse ""));
        if ((id == null and comment.id == null) and id != comment.id) return r.setStatus(.bad_request);
        comment.id = comment.id orelse id;
        db.updateComment(comment) catch return r.setStatus(.internal_server_error);
        return r.setStatus(.ok);
    }
    r.setStatus(.bad_request);
}

pub fn delete(self: *Self, _: std.mem.Allocator, db: *Sqlite, r: zap.Request) !void {
    if (r.path) |path| {
        if (self.commentIdFromPath(path)) |id| {
            db.deleteComment(id) catch return r.setStatus(.bad_request);
            return r.setStatus(.ok);
        }
    }
    r.setStatus(.bad_request);
}

pub fn patch(_: *Self, _: std.mem.Allocator, _: *Sqlite, _: zap.Request) !void {}
pub fn options(_: *Self, _: std.mem.Allocator, _: *Sqlite, _: zap.Request) !void {}
pub fn head(_: *Self, _: std.mem.Allocator, _: *Sqlite, _: zap.Request) !void {}
