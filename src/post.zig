const Post = @This();
const std = @import("std");


// POST SCHEMA:
// CREATE_TIME, MODIFIED_TIME, TITLE, CONTENT, VIEWS, TAG, AUTHOR


created_time: ?usize = null,
modified_time: ?usize = null,
title: ?[]const u8 = null,
views: ?usize = null,
author: ?[]const u8 = null,
content: ?[]const u8 = null,
id: ?usize = null, // set to null to use AUTOINCREMENT in sqlite


pub fn format(
    self: Post,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = fmt;
    _ = options;

    try writer.print("{{id: {any}, created: {any}, modified: {any}, title: {any}, author: {any} views: {any}\n{any} }}\n", 
                .{self.id, self.created_time, self.modified_time, self.title, self.author, self.views, self.content});


}



test "json deserialize" {

    const s = "{\"id\": 5, \"created_time\": 100, \"modified_time\": 100, \"title\": \"aa\", \"content\": \"bb\"}";
    const post = try std.json.parseFromSlice(Post, std.testing.allocator, s, .{});
    defer post.deinit();
    std.debug.print("{}\n", .{post.value});

}