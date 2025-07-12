const std = @import("std");
const zap = @import("zap");
const Config = @import("config.zig");
pub fn idFromPath(prefix_len: usize, path: []const u8) ?usize {
    if (path.len >= prefix_len + 2) {
        if (path[prefix_len] != '/') {
            return null;
        }
        const idstr = path[prefix_len + 1 ..];
        return std.fmt.parseUnsigned(usize, idstr, 10) catch null;
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
    const cookie = r.getCookieStr(fba.allocator(), Config.AdminCookieName) catch |e| {
        std.log.err("Cookie Allocation Failed: {any}\n", .{e});
        return null;
    } orelse {
        std.log.err("No Cookie named `" ++ Config.AdminCookieName ++ "`\n", .{});
        return null;
    };
    return std.fmt.parseInt(u64, cookie, 10) catch return null;
}
pub fn VerifyCookie(r: zap.Request) bool {
    const c = GetSessionCookie(r) orelse return false;
    const sc = SessionCookie orelse return false;
    return c == sc;
}
