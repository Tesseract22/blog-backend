const std = @import("std");
const zap = @import("zap");
const Config = @import("config.zig");
pub fn idFromPath(prefix_len: usize, path: []const u8) ?usize {
        return std.fmt.parseUnsigned(usize, pathRest(prefix_len, path) orelse return null, 10) catch null;
}
pub fn pathRest(prefix_len: usize, path: []const u8) ?[]const u8 {
    if (path.len >= prefix_len + 2) {
        if (path[prefix_len] != '/') {
            return null;
        }
        return path[prefix_len + 1 ..];
    }
    return null;
}
pub var SessionCookie: ?u64 = null;

pub fn AuthRequest(r: zap.Request) bool {
    // zap.BearerAuthSingle.authenticateRequest(self: *Self, r: *const zap.Request)
    const auth_header = r.getHeader("authorization") orelse return false;
    if (!std.mem.startsWith(u8, auth_header, Config.AuthPrefix)) return false;
    const hash = std.hash_map.hashString(auth_header[Config.AuthPrefix.len..]);
    return hash == Config.Auth;
}

pub fn GetSessionCookie(r: zap.Request) ?u64 {
    r.parseCookies(false);
    var buf = [_]u8{0} ** 256;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    var cookie_wrap = r.getCookieStr(fba.allocator(), Config.AdminCookieName, false) catch |e| {
        std.log.err("Cookie Allocation Failed: {any}\n", .{e});
        return null;
    } orelse {
        std.log.err("No Cookie named `" ++ Config.AdminCookieName ++ "`\n", .{});
        return null;
    };
    defer cookie_wrap.deinit();
    return std.fmt.parseInt(u64, cookie_wrap.str, 10) catch return null;
}
pub fn VerifyCookie(r: zap.Request) bool {
    const c = GetSessionCookie(r) orelse return false;
    const sc = SessionCookie orelse return false;
    return c == sc;
}
