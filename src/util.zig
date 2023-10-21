
const std = @import("std");

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