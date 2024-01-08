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
            .patch = patchPost,
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
fn getPost(e: *zap.SimpleEndpoint, r: zap.SimpleRequest) void {
        const self = @fieldParentPtr(Self, "endpoint", e);
        var aa = std.heap.ArenaAllocator.init(self.alloc);
        defer aa.deinit();

        const ip_str = r.getHeader("x-real-ip") 
            orelse return std.log.warn("No header named \"x-real-ip\"", .{});
        const ip_addr = std.net.Ip4Address.parse(ip_str, 0) 
            catch |err| return std.log.warn("{any} Can not parse {s} as \"ip\"", .{err, ip_str});
        std.log.warn("ip: {}", .{ip_addr});


        const path = r.path orelse return r.setStatus(.bad_request);
            // /users
        const path_trim = trimPath(path);

        if (path_trim.len == e.settings.path.len) {
            self.listPost(r) catch return r.setStatus(.internal_server_error);
            return;
        }
        // post as in article post, not the method POST
        const post_id = self.postIdFromPath(path_trim) orelse return r.setStatus(.bad_request);
        const post = (self.db.getPost(post_id, &aa)  
            catch return r.setStatus(.internal_server_error))
            orelse return r.setStatus(.not_found);
        const json = std.json.stringifyAlloc(aa.allocator(), post, .{}) 
            catch return r.setStatus(.internal_server_error);
        r.sendJson(json) catch return r.setStatus(.internal_server_error);
        // storing ip
        const ip_id = self.db.insertIpAddr(ip_addr.sa.addr)
            catch |err| return std.log.warn("{any} Unexpected Error while inserting ip address", .{err});
        self.db.insertIpMap(ip_id, post_id) 
            catch |err| return std.log.warn("{any} Unexpected Error while storing ip records", .{err});
        
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
            std.log.err("Cannot Parse Json: {s}", .{body});
            return r.setStatus(.bad_request);
        }; 
        defer post.deinit();
        if (post.value.id != null) {
            return r.setStatus(.bad_request);
        }
        
        const id = self.db.insertPost(post.value) catch {
            return r.setStatus(.internal_server_error);
        };
        var buf = [_]u8 {0} ** 64;
        r.sendJson(zap.stringifyBuf(&buf, .{.id=id}, .{}).?) catch return r.setStatus(.internal_server_error);
        return r.setStatus(.ok);
    }
    r.setStatus(.bad_request);

}

fn putPost(e: *zap.SimpleEndpoint, r: zap.SimpleRequest) void {
    if (!VerifyCookie(r)) return r.setStatus(.unauthorized);
    const self = @fieldParentPtr(Self, "endpoint", e);
    if (r.body) |body| {
        var post = std.json.parseFromSlice(Post, self.alloc, body, .{}) catch {
            std.log.err("Cannot parsed json {s}", .{body});
            return r.setStatus(.bad_request);
        };        
        defer post.deinit();
        const id = self.postIdFromPath(trimPath(r.path orelse "")) orelse return r.setStatus(.bad_request);
        post.value.id = id;
        self.db.updatePost(post.value) catch {
            r.setStatus(.internal_server_error);
            return;
        };
        r.setStatus(.ok);
    } else {
        std.log.err("No body", .{});
        r.setStatus(.bad_request);
    }

}

fn patchPost(e: *zap.SimpleEndpoint, r: zap.SimpleRequest) void {

    const self = @fieldParentPtr(Self, "endpoint", e);
    var arena = std.heap.ArenaAllocator.init(self.alloc);
    defer arena.deinit();
    if (r.path) |path| {
        if (self.postIdFromPath(path)) |id| {
            const post = (self.db.getPostMeta(id, &arena) catch return r.setStatus(.internal_server_error)) orelse return r.setStatus(.not_found);
            var jsonbuf: [512]u8 = undefined;
            if (zap.stringifyBuf(&jsonbuf, post, .{})) |json| {
                r.sendJson(json) catch return r.setStatus(.internal_server_error);
            }
        }
    }
}

fn deletePost(e: *zap.SimpleEndpoint, r: zap.SimpleRequest) void {
    const self = @fieldParentPtr(Self, "endpoint", e);
    if (!VerifyCookie(r)) return r.setStatus(.unauthorized);
    if (r.path) |path| {
        if (self.postIdFromPath(path)) |id| {
            std.log.debug("delete: {}", .{id});
            self.db.deletePost(id) catch {
                r.setStatus(.bad_request);
                return;
            };
            return;
        }
    }
    r.setStatus(.bad_request);
}
