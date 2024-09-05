const std = @import("std");
const builtin = @import("builtin");
const zap = @import("zap");
const Enpoint = @import("endpoint.zig");
const util = @import("util.zig");
const Sqlite = @import("sqlite.zig");
const Config = @import("config.zig");
const memeql = std.mem.eql;
// this is just to demo that we can catch arbitrary slug
//s

const SubPath = enum {
    article,
    login,
    auth,
    admin,
    const MatchResult = struct {
        keyword: SubPath,
        remain: []const u8,
    };
    pub fn match(path: []const u8) ?MatchResult {
        const type_info = @typeInfo(SubPath);
        inline for (type_info.@"enum".fields) |f| {
            if (std.mem.startsWith(u8, path, f.name)) {
                return .{ .keyword = @enumFromInt(f.value), .remain = path[f.name.len..] };
            }
        }
        return null;
    }
};
var rand = std.Random.DefaultPrng.init(0);
fn on_request(r: zap.Request) void {
    blk: {
        const path = (r.path orelse break :blk)[1..];
        var it = std.mem.splitScalar(u8, path, '/');
        const sec = it.next() orelse break :blk;
        const match = SubPath.match(sec) orelse break :blk;
        switch (match.keyword) {
            .article => {
                const ip = r.getHeader("X-Forwarded-For") orelse r.getHeader("RemoteAddr") orelse r.getHeader("X-Real-Ip");
                std.log.debug("{s}", .{ip orelse "Not header named X-Forwarded-For"});
                const id = it.next() orelse "";
                if (id.len > 0) {
                    r.sendFile(Config.PublicFolder ++ "index.html") catch break :blk;
                    return;
                } else {
                    std.debug.print("redirect\n", .{});
                    return r.redirectTo("/", null) catch break :blk;
                }
            },
            .login => {
                r.sendFile(Config.PublicFolder ++ "html/login.html") catch break :blk;
                return;
            },
            .auth => {
                if (!util.AuthRequest(r)) {
                    std.debug.print("auth failed\n", .{});
                    // r.sendBody("Authentication Failed") catch break :blk;
                    return r.setStatus(.unauthorized);
                }
                var buf = [_]u8{0} ** 20;
                const cookie_val = rand.next();
                const val = std.fmt.bufPrint(&buf, "{}", .{cookie_val}) catch unreachable;
                const domain = switch (builtin.mode) {
                    .Debug => null, // localhost
                    else => Config.Domain,
                };
                r.setCookie(.{
                    .name = "admin-cookie",
                    .value = val,
                    .domain = domain,
                    .path = "/",
                }) catch break :blk;
                r.sendBody("Set Cookie") catch break :blk;
                util.SessionCookie = cookie_val;
                return;
            },
            .admin => {
                const cookie_count = r.getCookiesCount();
                std.log.debug("cookie_count: {}", .{cookie_count});

                // iterate over all cookies as strings

                const success = util.VerifyCookie(r);
                if (!success) {
                    const domain = switch (builtin.mode) {
                        .Debug => null, // localhost
                        else => Config.Domain,
                    };
                    r.setCookie(.{
                        .name = "login-redirect",
                        .value = r.path orelse "",
                        .domain = domain,
                        .path = "/"
                    }) catch return r.setStatus(.internal_server_error);
                    return r.redirectTo("/login", null) catch break :blk;
                }
                return r.sendFile(Config.PublicFolder ++ "html/admin.html") catch break :blk;
            },
        }
    }

    r.sendBody("<html><body><h1>404</h1></body></html>") catch return;
    r.setStatus(.not_found);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    const allocator = gpa.allocator();
    var db = try Sqlite.init();
    defer db.deinit();
    // we scope everything that can allocate within this block for leak detection
    {
        // setup listener
        var listener = zap.Endpoint.Listener.init(
            allocator,
            .{
                .port = Config.Port,
                .on_request = on_request,
                .log = true,
                .public_folder = Config.PublicFolder,
                .max_clients = 100000,
                .max_body_size = 5 * 1024 * 1024,
            },
        );
        defer listener.deinit();

        var post_end = Enpoint.PostEndPoint.init(allocator, "/post", &db);
        var comment_end = Enpoint.CommentEndPoint.init(allocator, "/comment", &db);
        var image_end = Enpoint.ImageEndPoint.init(allocator, "/image");
        try listener.register(post_end.getEndpoint());
        try listener.register(comment_end.getEndpoint());
        try listener.register(image_end.getEndpoint());

        // listen
        try listener.listen();

        std.debug.print("Listening on 0.0.0.0:{}\n", .{Config.Port});

        // and run
        zap.start(.{
            .threads = 100,
            .workers = 1,
        });
    }

    // show potential memory leaks when ZAP is shut down
    const has_leaked = gpa.detectLeaks();
    std.log.debug("Has leaked: {}\n", .{has_leaked});
}
