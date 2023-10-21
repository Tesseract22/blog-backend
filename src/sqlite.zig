const sqlite = @import("sqlite");
const std = @import("std");
const Post = @import("post.zig");
const Comment = @import("comment.zig");
const Arena = std.heap.ArenaAllocator;
pub const PATH = "test.db";
const Sqlite = @This();
db: sqlite.Db,
pub fn init() !Sqlite {
    
    var res = Sqlite {.db = undefined};

    res.db = try sqlite.Db.init(.{
        .mode = sqlite.Db.Mode{ .File = PATH },
        .open_flags = .{
            .write = true,
            .create = true,
        },
        .threading_mode = .MultiThread,
    });
    return res;
}

pub fn deinit(self: *Sqlite) void {
    _ = self;
} 

// POST SCHEMA:
// ID, CREATE_TIME, MODIFIED_TIME, TITLE, CONTENT, VIEWS, AUTHOR

pub fn insertPost(self: *Sqlite, post: Post) !void {
    std.debug.assert(post.id == null);
    const q = 
        \\ INSERT INTO POST 
        \\  (CREATED_TIME, MODIFIED_TIME, TITLE, VIEWS, AUTHOR, CONTENT, ROWID) 
        \\  values (?, ?, ?, ?, ?, ?, ?)
    ;
    var stmt = try self.db.prepare(q);
    try stmt.exec(.{}, post);
    

}

pub fn deletePost(self: *Sqlite, id: usize) !void {
    const q = 
        \\DELETE FROM POST
        \\  WHERE ROWID = ?
    ;
    var stmt = try self.db.prepare(q);
    try stmt.exec(.{}, .{.id = id});
}




pub fn listPost(self: *Sqlite, arena: *Arena) ![]Post {
    const q = 
        \\ SELECT *, ROWID FROM POST
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    const rows = try stmt.all(Post, arena.allocator(), .{   }, .{});
    return rows;
    
}

pub fn getPostMeta(self: *Sqlite, id: usize, arena: *Arena) !?Post {

    const q = 
        \\ SELECT 
        \\  CREATED_TIME, MODIFIED_TIME, TITLE, VIEWS, AUTHOR, ROWID FROM POST 
        \\  WHERE ROWID = ?
    ;
    var stmt = self.db.prepare(q) catch unreachable; 
    const row = try stmt.oneAlloc(Post, arena.allocator(), .{   }, .{.ID = id});
    return row;
}


pub fn getPost(self: *Sqlite, id: usize, arena: *Arena) !?Post {
    const q = 
        \\ SELECT 
        \\  CREATED_TIME, MODIFIED_TIME, TITLE, VIEWS, AUTHOR, CONTENT, ROWID FROM POST 
        \\  WHERE ROWID = ?
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    const row = try stmt.oneAlloc(Post, arena.allocator(), .{   }, .{.ID = id});
    return row;
}

pub fn updatePost(self: *Sqlite, post: Post) !void {
    std.debug.assert(post.id != null);
    const q = 
        \\UPDATE POST
        \\SET  
        \\  CREATED_TIME = coalesce(?, CREATED_TIME), 
        \\  MODIFIED_TIME = coalesce(?, MODIFIED_TIME), 
        \\  TITLE = coalesce(?, TITLE), 
        \\  VIEWS = coalesce(?, VIEWS), 
        \\  AUTHOR = coalesce(?, AUTHOR), 
        \\  CONTENT = coalesce(?, CONTENT) 
        \\  WHERE ROWID = ?
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    try stmt.exec(.{}, post);
}

pub fn getComments(self: *Sqlite, post_id: usize, arena: *Arena) ![]Comment {
    const q = 
        \\SELECT *, ROWID FROM COMMENT WHERE POST = ?
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    return try stmt.all(Comment, arena.allocator(), .{}, .{.id = post_id});

}

pub fn insertComment(self: *Sqlite, comment: Comment) !void {
    const q = 
        \\INSERT INTO COMMENT (CREATED_TIME, CONTENT, COMMENTER, POST, ROWID) values (?,?,?,?,?)
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    try stmt.exec(.{}, comment);

}

pub fn deleteComment(self: *Sqlite, comment_id: usize) !void {
    const q = 
        \\DELETE FROM COMMENT 
        \\  WHERE ROWID = ?
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    try stmt.exec(.{}, .{.id = comment_id });

}

pub fn updateComment(self: *Sqlite, comment: Comment) !void {
    std.debug.assert(comment.id != null);
    const q = 
        \\UPDATE COMMENT
        \\SET  
        \\  CREATED_TIME = coalesce(?, CREATED_TIME), 
        \\  CONTENT = coalesce(?, CONTENT), 
        \\  COMMENTER = coalesce(?, COMMENTER), 
        \\  POST = coalesce(?, POST)
        \\  WHERE ROWID = ?
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    try stmt.exec(.{}, comment);
}

