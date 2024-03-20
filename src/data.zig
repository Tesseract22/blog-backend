const std = @import("std");

pub const Post = struct {
    created_time: ?usize = null,
    modified_time: ?usize = null,
    title: ?[]const u8 = null,
    views: ?usize = null,
    author: ?[]const u8 = null,
    content: ?[]const u8 = null,
    published: ?bool = null,
    cover_url: ?[]const u8 = null,
    id: ?usize = null, // set to null to use AUTOINCREMENT in sqlite
    pub fn format(
        self: Post,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.print("{{id: {any}, created: {any}, modified: {any}, title: {any}, author: {any} views: {any}\n{any} }}\n", .{ self.id, self.created_time, self.modified_time, self.title, self.author, self.views, self.content });
    }
};

pub const Comment = struct {
    created_time: ?usize = null,
    content: ?[]const u8 = null,
    commenter: ?usize = null,
    post_id: ?usize = null,
    id: ?usize = null,
};

pub const CommentFull = struct {
    created_time: ?usize = null,
    content: ?[]const u8 = null,
    commenter: ?usize = null,
    post_id: ?usize = null,
    email: ?[]const u8 = null,
    username: ?[]const u8 = null,
    id: ?usize = null,
};

pub const Commenter = struct {
    email: ?[]const u8 = null,
    username: ?[]const u8 = null,
    id: ?usize = null,
};

pub const IP = struct {
    ip: ?u32 = null,
    id: ?usize = null,
};
