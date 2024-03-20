const std = @import("std");
const zap = @import("zap");
const Sqlite = @import("../sqlite.zig");
const Data = @import("../data.zig");
const Comment = Data.Comment;
const CommentFull = Data.CommentFull;
const idFromPath = @import("../util.zig").idFromPath;
const AuthRequest = @import("../util.zig").AuthRequest;
pub const Self = @This();

alloc: std.mem.Allocator,
endpoint: zap.Endpoint,
db: *Sqlite,
pub fn init(
    a: std.mem.Allocator,
    user_path: []const u8,
    db: *Sqlite,
) Self {
    return .{
        .alloc = a,
        .db = db,
        .endpoint = zap.Endpoint.init(.{
            .path = user_path,
            .get = getComments,
            .post = postComment,
            .put = putComment,
            .patch = putComment,
            .delete = deleteComment,
        }),
    };
}

pub fn getEndpoint(self: *Self) *zap.Endpoint {
    return &self.endpoint;
}

fn commentIdFromPath(self: *Self, path: []const u8) ?usize {
    return idFromPath(self.endpoint.settings.path.len, path);
}

fn trimPath(path: []const u8) []const u8 {
    return if (path[path.len - 1] == '/') path[0 .. path.len - 1] else path;
}

/// GET /post/<id> => post[<id>]
/// GET /post => []post
/// else => bad_request
fn getComments(end: *zap.Endpoint, req: zap.Request) void {
    const status = struct {
        pub fn handle(e: *zap.Endpoint, r: zap.Request) zap.StatusCode {
            const self = @fieldParentPtr(Self, "endpoint", e);
            if (r.path) |path| {
                if (self.commentIdFromPath(trimPath(path))) |id| {
                    var arena = std.heap.ArenaAllocator.init(self.alloc);
                    defer arena.deinit();
                    var jsonbuf: [512]u8 = undefined;
                    const comments = self.db.getCommentsByPost(id, &arena) catch return .internal_server_error;
                    if (zap.stringifyBuf(&jsonbuf, comments, .{})) |json| {
                        r.sendJson(json) catch return .internal_server_error;
                    }
                    return .ok;
                }
            }
            return .bad_request;
        }
    }.handle(end, req);
    req.setStatus(status);
}

/// POST /post/<id> (JSON.post) => ok
/// else => bad_request
/// The jso
fn postComment(e: *zap.Endpoint, r: zap.Request) void {
    const self = @fieldParentPtr(Self, "endpoint", e);
    var arena = std.heap.ArenaAllocator.init(self.alloc);
    defer arena.deinit();
    if (r.body) |body| {
        var comment_ret = std.json.parseFromSlice(CommentFull, arena.allocator(), body, .{}) catch return r.setStatus(.bad_request);
        defer comment_ret.deinit();
        var comment = comment_ret.value;
        if (comment.id != null or comment.commenter != null)
            return r.setStatus(.bad_request);
        comment.commenter = self.db.insertCommenterIfNotExist(.{ .email = comment.email, .username = comment.username }) catch {
            return r.setStatus(.unauthorized);
        };
        self.db.insertComment(.{ .created_time = comment.created_time, .content = comment.content, .commenter = comment.commenter, .post_id = comment.post_id }) catch return r.setStatus(.bad_request);
        return r.setStatus(.ok);
    }
    r.setStatus(.bad_request);
}

fn putComment(e: *zap.Endpoint, r: zap.Request) void {
    if (!AuthRequest(r)) return r.setStatus(.unauthorized);
    const self = @fieldParentPtr(Self, "endpoint", e);
    var arena = std.heap.ArenaAllocator.init(self.alloc);
    defer arena.deinit();
    if (r.body) |body| {
        var comment_ret = std.json.parseFromSlice(Comment, arena.allocator(), body, .{}) catch return r.setStatus(.bad_request);
        defer comment_ret.deinit();
        var comment = comment_ret.value;
        const id = self.commentIdFromPath(trimPath(r.path orelse ""));
        if ((id == null and comment.id == null) and id != comment.id) return r.setStatus(.bad_request);
        comment.id = comment.id orelse id;
        self.db.updateComment(comment) catch return r.setStatus(.internal_server_error);
        return r.setStatus(.ok);
    }
    r.setStatus(.bad_request);
}

fn deleteComment(e: *zap.Endpoint, r: zap.Request) void {
    if (!AuthRequest(r)) return r.setStatus(.unauthorized);
    const self = @fieldParentPtr(Self, "endpoint", e);
    if (r.path) |path| {
        if (self.commentIdFromPath(path)) |id| {
            self.db.deleteComment(id) catch return r.setStatus(.bad_request);
            return r.setStatus(.ok);
        }
    }
    r.setStatus(.bad_request);
}
