const std = @import("std");
const Sqlite = @import("sqlite.zig");
const Post = @import("post.zig");
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var aa = std.heap.ArenaAllocator.init(gpa.allocator());
    defer aa.deinit();
    var db = try Sqlite.init();
    const t: usize = @intCast(std.time.timestamp()); 
    var post1 = Post {.created_time = t, .modified_time = t, .content = "Today is a nice day.", .title = "This is Title", .author = "Cat", .views = 0};
    try db.insertPost(post1);
    const post = (try db.getPost(100, &aa)).?;
    std.debug.print("post: {}\n", .{post});

    const post2 = (try db.getPostMeta(1, &aa)).?;
    std.debug.print("post: {}", .{post2});

    const posts = try db.listPost(&aa);
    for (posts) |p| {
        std.debug.print("{}", .{p});
    }

    

}