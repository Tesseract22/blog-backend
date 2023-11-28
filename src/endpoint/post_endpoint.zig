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

alloc: std.mem.Allocator,
endpoint: zap.SimpleEndpoint,
db: *Sqlite,
pub fn init(
    a: std.mem.Allocator,
    user_path: []const u8,
    db: *Sqlite,
) Self {
    return .{
        .alloc = a,
        .db = db,
        .endpoint = zap.SimpleEndpoint.init(.{
            .path = user_path,
            .get = getPost,
            .post = postPost,
            .put = putPost,
            .patch = putPost,
            .delete = deletePost,
        }),
    };
}




pub fn getEndpoint(self: *Self) *zap.SimpleEndpoint {
    return &self.endpoint;
}

fn postIdFromPath(self: *Self, path: []const u8) ?usize {
    return idFromPath(self.endpoint.settings.path.len, path);
}

fn trimPath(path: []const u8) []const u8 {
    return if (path[path.len - 1] == '/') path[0..path.len - 1] else path;
}

/// GET /post/<id> => post[<id>]
/// GET /post => []post
/// else => bad_request
fn getPost(end: *zap.SimpleEndpoint, req: zap.SimpleRequest) void {
    
    const status = struct {
        pub fn handle(e: *zap.SimpleEndpoint, r: zap.SimpleRequest) zap.StatusCode {
            const self = @fieldParentPtr(Self, "endpoint", e);
            var aa = std.heap.ArenaAllocator.init(self.alloc);
            defer aa.deinit();
            if (r.path) |path| {
                // /users
                const path_trim = trimPath(path);

                if (path_trim.len == e.settings.path.len) {
                    self.listPost(r) catch return .internal_server_error;
                    return .ok;
                }
        

                if (self.postIdFromPath(path_trim)) |id| {
                    var jsonbuf: [512]u8 = undefined;
                    const post = (self.db.getPost(id, &aa)  catch return .internal_server_error) 
                                                                            orelse return .not_found;
                    if (zap.stringifyBuf(&jsonbuf, post, .{})) |json| {
                        r.sendJson(json) catch return .internal_server_error;
                    }

                }
                return .ok;
            } else {
                return .bad_request;
            }
        }
    }.handle(end, req);
    req.setStatus(status);


}

fn listPost(self: *Self, r: zap.SimpleRequest) !void {
    var arena = std.heap.ArenaAllocator.init(self.alloc);
    defer arena.deinit();
    const posts = try self.db.listPost(&arena);
    const json = try std.json.stringifyAlloc(arena.allocator(), posts, .{});
    try r.sendJson(json) ;
    
}
/// POST /post/ (JSON.post) => ok
/// else => bad_request
/// The jso
fn postPost(e: *zap.SimpleEndpoint, r: zap.SimpleRequest) void {
    const self = @fieldParentPtr(Self, "endpoint", e);
    if (!VerifyCookie(r)) return r.setStatus(.unauthorized);
    if (r.body) |body| {
        
        var post = std.json.parseFromSlice(Post, self.alloc, body, .{}) catch {
            std.log.debug("here 1", .{});
            return r.setStatus(.bad_request);
        };        
        defer post.deinit();
        if (post.value.id != null) {
            return r.setStatus(.bad_request);
        }
        
        defer post.deinit();
        self.db.insertPost(post.value) catch {
            return r.setStatus(.bad_request);
        };
        return r.setStatus(.ok);
    }
    r.setStatus(.bad_request);

}

fn putPost(e: *zap.SimpleEndpoint, r: zap.SimpleRequest) void {
    if (!VerifyCookie(r)) return r.setStatus(.unauthorized);
    const self = @fieldParentPtr(Self, "endpoint", e);
    if (r.body) |body| {
        var post = std.json.parseFromSlice(Post, self.alloc, body, .{}) catch {
            std.log.debug("here 1", .{});
            return r.setStatus(.bad_request);
        };        
        defer post.deinit();
        const id = self.postIdFromPath(trimPath(r.path orelse ""));
        if ((id == null and post.value.id == null) and id != post.value.id) return r.setStatus(.bad_request);
        post.value.id = post.value.id orelse id;
        self.db.updatePost(post.value) catch {
            r.setStatus(.internal_server_error);
            return;
        };
        r.setStatus(.ok);
    } else {
         std.log.debug("here 3", .{});
        r.setStatus(.bad_request);
    }

}

fn deletePost(e: *zap.SimpleEndpoint, r: zap.SimpleRequest) void {
    const self = @fieldParentPtr(Self, "endpoint", e);
    if (!VerifyCookie(r)) return r.setStatus(.unauthorized);
    if (r.path) |path| {
        if (self.postIdFromPath(path)) |id| {
            self.db.deletePost(id) catch {
                r.setStatus(.bad_request);
                return;
            };
            return;
        }
    }
    r.setStatus(.bad_request);
}
