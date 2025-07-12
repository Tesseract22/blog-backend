const std = @import("std");
const builtin = @import("builtin");
const zap = @import("zap");
const Enpoint = @import("endpoint.zig");
const util = @import("util.zig");
const Sqlite = @import("sqlite.zig");
const Config = @import("config.zig");
const memeql = std.mem.eql;
// this is just to demo that we can catch arbitrary slugs
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
fn on_request(r: zap.Request) anyerror!void {
    //blk: {
    //    const path = (r.path orelse break :blk)[1..];
    //    var it = std.mem.splitScalar(u8, path, '/');
    //    const sec = it.next() orelse break :blk;
    //    const match = SubPath.match(sec) orelse break :blk;
    //    //std.debug.print("sec: {s}\n", .{sec});
    //    switch (match.keyword) {
    //        .article => {
    //            const id = it.next() orelse "";
    //            if (id.len > 0) {
    //                r.sendFile(Config.PublicFolder ++ "index.html") catch break :blk;
    //                return;
    //            } else {
    //                std.debug.print("redirect\n", .{});
    //                return r.redirectTo("/", null) catch break :blk;
    //            }
    //        },
    //        .login => {
    //            r.sendFile(Config.PublicFolder ++ "html/login.html") catch break :blk;
    //            return;
    //        },
    //        .auth => {
    //            if (!util.AuthRequest(r)) {
    //                std.debug.print("auth failed\n", .{});
    //                // r.sendBody("Authentication Failed") catch break :blk;
    //                return r.setStatus(.unauthorized);
    //            }
    //            var buf = [_]u8{0} ** 20;
    //            const cookie_val = rand.next();
    //            const val = std.fmt.bufPrint(&buf, "{}", .{cookie_val}) catch unreachable;
    //            const domain = switch (builtin.mode) {
    //                .Debug => null, // localhost
    //                else => Config.Domain,
    //            };
    //            r.setCookie(.{
    //                .name = "admin-cookie",
    //                .value = val,
    //                .domain = domain,
    //                .path = "/",
    //            }) catch break :blk;
    //            r.sendBody("Set Cookie") catch break :blk;
    //            util.SessionCookie = cookie_val;
    //            return;
    //        },
    //        .admin => {
    //            const cookie_count = r.getCookiesCount();
    //            std.log.debug("cookie_count: {}", .{cookie_count});

    //            // iterate over all cookies as strings

    //            const success = util.VerifyCookie(r);
    //            if (!success) {
    //                return r.redirectTo("/login", null) catch break :blk;
    //            }
    //            return r.sendFile(Config.PublicFolder ++ "html/admin.html") catch break :blk;
    //        },
    //    }
    //}
    
    std.log.debug("here", .{});
    r.sendBody("<html><body><h1>404</h1></body></html>") catch return;
    r.setStatus(.not_found);
}


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var db = try Sqlite.init();
    defer db.deinit();
    {   
        const App = zap.App.Create(Sqlite);
        var app = try App.init(allocator, &db, .{});
        defer app.deinit();

        //var index_end = IndexEndPoint { .path = "/" };
        var post_end = Enpoint.PostEndPoint { .path = "/post" };
        ////_ = Enpoint.CommentEndPoint {.path = "/comment" };
        ////_ = Enpoint.ImageEndPoint.init("/image");

        //var listener = zap.HttpListener.init(.{
        //    .interface = Config.Interface,
        //    .port = Config.Port,
        //    .on_request = on_request,
        //    .public_folder = Config.PublicFolder,
        //    .max_body_size = 100 * 1024 * 1024, 
        //});

        //try listener.listen();

        //try app.register(&index_end);
        try app.register(&post_end);
        //try app.register(&comment_end);
        //try app.register(&image_end);

        try app.listen(.{
            .interface = Config.Interface,
            .port = Config.ApiPort,
            //.on_request = on_request,
            .public_folder = Config.PublicFolder,
            .max_body_size = 100 * 1024 * 1024, 
        });

        std.log.debug("Web Starting at {s}:{}", .{Config.Interface, Config.Port});
        std.log.debug("Api Starting at {s}:{}", .{Config.Interface, Config.ApiPort});


        zap.start(.{
            .threads = 2,
            .workers = 1,
        });
        // show potential memory leaks when ZAP is shut down
    }
}
