
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

pub fn AuthRequest(r: zap.SimpleRequest) bool {
    // zap.BearerAuthSingle.authenticateRequest(self: *Self, r: *const zap.SimpleRequest)
    const auth_header = r.getHeader("authorization") orelse return false;
    return std.mem.eql(u8, auth_header, Config.Auth);
}