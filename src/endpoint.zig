const std = @import("std");

const zap = @import("zap");
const Sqlite = @import("sqlite.zig");
const Config = @import("config.zig");
const util = @import("util.zig");
pub const CommentEndPoint = @import("endpoint/comment_endpoint.zig");
pub const PostEndPoint = @import("endpoint/post_endpoint.zig");
pub const ImageEndPoint = @import("endpoint/image_endpoint.zig");

const SubPath = enum {
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


pub const Ctx = struct {
    db: Sqlite,
    rand: std.Random,
    index: []const u8,

    pub fn unhandledRequest(self: *Ctx, _: std.mem.Allocator, r: zap.Request) anyerror!void {
        blk: {
            const path = (r.path orelse break :blk)[1..];
                var it = std.mem.splitScalar(u8, path, '/');
                const sec = it.next() orelse break :blk;
                const match = SubPath.match(sec) orelse break :blk;
                std.debug.print("sec: {s}\n", .{sec});
                switch (match.keyword) {
                    .auth => {
                        if (!util.AuthRequest(r)) {
                            std.debug.print("auth failed\n", .{});
                                r.sendBody("Authentication Failed") catch break :blk;
                                return r.setStatus(.unauthorized);
                        }
                        var buf = [_]u8{0} ** 20;
                            const cookie_val = self.rand.int(u64);
                            const val = std.fmt.bufPrint(&buf, "{}", .{cookie_val}) catch unreachable;
                        r.setCookie(.{
                            .name = "admin-cookie",
                            .value = val,
                            .domain = null,
                            .path = null,
                            .secure = @import("builtin").mode != .Debug,
                        }) catch break :blk;
                        r.sendBody("Set Cookie") catch break :blk;
                            util.SessionCookie = cookie_val;
                            return;
                    },
                    .admin => {
                        const success = util.VerifyCookie(r);
                        std.log.debug("cookie_count: {}", .{r.getCookiesCount()});
                        if (!success) {
                            return r.redirectTo("/login", null) catch break :blk;
                        }
                        return r.sendFile(Config.PublicFolder ++ "html/admin.html") catch break :blk;
                    },
                }
        }
        
        try r.sendFile("public/index.html");
    }
};
