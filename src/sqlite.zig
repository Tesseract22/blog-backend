const sqlite = @import("sqlite");
const std = @import("std");
const data = @import("data.zig");
const Post = data.Post;
const Comment = data.Comment;
const Commenter = data.Commenter;
const Arena = std.heap.ArenaAllocator;
const Sqlite = @This();
db: sqlite.Db,
pub fn init() !Sqlite {
    
    var res = Sqlite {.db = undefined};

    res.db = try sqlite.Db.init(.{
        .mode = sqlite.Db.Mode{ .File = @import("config.zig").DbPath },
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

pub fn insertPost(self: *Sqlite, post: Post) !usize {
    std.debug.assert(post.id == null);
    const q = 
        \\ INSERT INTO POST 
        \\  (CREATED_TIME, MODIFIED_TIME, TITLE, VIEWS, AUTHOR, CONTENT, PUBLISHED, COVER_URL, ROWID) 
        \\  values (
        \\          coalesce(?, strftime('%s', 'now')), 
        \\          coalesce(?, strftime('%s', 'now')), 
        \\          ?, 
        \\          coalesce(?, 0), 
        \\          ?,
        \\          ?,
        \\          ?, 
        \\          ?, 
        \\          ?)
        \\ RETURNING ROWID
    ;
    var stmt = try self.db.prepare(q);
    defer stmt.deinit();
    return (try stmt.one(usize, .{}, post)) orelse unreachable;
    

}

pub fn deletePost(self: *Sqlite, id: usize) !void {
    const q = 
        \\DELETE FROM POST
        \\  WHERE ROWID = ?
    ;
    var stmt = try self.db.prepare(q);
    defer stmt.deinit();
    try stmt.exec(.{}, .{.id = id});
}




pub fn listPost(self: *Sqlite, arena: *Arena) ![]Post {
    const q = 
        \\ SELECT 
        \\ CREATED_TIME, MODIFIED_TIME, TITLE, VIEWS, AUTHOR, "", PUBLISHED, COVER_URL, ROWID FROM POST
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    defer stmt.deinit();
    const rows = try stmt.all(Post, arena.allocator(), .{   }, .{});
    return rows;
    
}

pub fn getPostMeta(self: *Sqlite, id: usize, arena: *Arena) !?Post {

    const q = 
        \\ SELECT 
        \\  CREATED_TIME, MODIFIED_TIME, TITLE, VIEWS, AUTHOR, "", PUBLISHED, COVER_URL, ROWID FROM POST 
        \\  WHERE ROWID = ?
    ;
    var stmt = self.db.prepare(q) catch unreachable; 
    defer stmt.deinit();
    const row = try stmt.oneAlloc(Post, arena.allocator(), .{   }, .{.ID = id});
    return row;
}


pub fn getPost(self: *Sqlite, id: usize, arena: *Arena) !?Post {
    const q = 
        \\ SELECT 
        \\  CREATED_TIME, MODIFIED_TIME, TITLE, VIEWS, AUTHOR, CONTENT, PUBLISHED, COVER_URL, ROWID FROM POST 
        \\  WHERE ROWID = ?
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    defer stmt.deinit();
    const row = try stmt.oneAlloc(Post, arena.allocator(), .{   }, .{.ID = id});
    return row;
}

pub fn updatePost(self: *Sqlite, post: Post) !void {
    std.debug.assert(post.id != null);
    const q = 
        \\UPDATE POST
        \\SET  
        \\  CREATED_TIME = coalesce(?, CREATED_TIME), 
        \\  MODIFIED_TIME = coalesce(?, strftime('%s', 'now')), 
        \\  TITLE = coalesce(?, TITLE), 
        \\  VIEWS = coalesce(?, VIEWS), 
        \\  AUTHOR = coalesce(?, AUTHOR), 
        \\  CONTENT = coalesce(?, CONTENT),
        \\  PUBLISHED = coalesce(?, PUBLISHED),
        \\  COVER_URL =  coalesce(?, COVER_URL)
        \\  WHERE ROWID = ?
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    defer stmt.deinit();
    try stmt.exec(.{}, post);
}

pub fn getCommentsByPost(self: *Sqlite, post_id: usize, arena: *Arena) ![]data.CommentFull {
    const q = 
        \\SELECT COMMENT.*,COMMENTER.USERNAME,COMMENT.ROWID
        \\  FROM COMMENT 
        \\  JOIN COMMENTER ON COMMENT.COMMENTER = COMMENTER.ROWID
        \\  WHERE POST = ?
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    defer stmt.deinit();
    return stmt.all(data.CommentFull, arena.allocator(), .{}, .{.id = post_id});

}

pub fn getCommentsById(self: *Sqlite, post_id: usize, arena: *Arena) ![]Comment {
    _ = arena;
    _ = post_id;
    _ = self;
    unreachable;

}

pub fn insertComment(self: *Sqlite, comment: Comment) !void {
    const q = 
        \\INSERT INTO COMMENT (CREATED_TIME, CONTENT, COMMENTER, POST, ROWID) values (?,?,?,?,?)
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    defer stmt.deinit();
    try stmt.exec(.{}, comment);

}

pub fn deleteComment(self: *Sqlite, comment_id: usize) !void {
    const q = 
        \\DELETE FROM COMMENT 
        \\  WHERE ROWID = ?
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    defer stmt.deinit();
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
    defer stmt.deinit();
    try stmt.exec(.{}, comment);
}

pub fn insertCommenter(self: *Sqlite, commenter: Commenter) !void {
    const q = 
        \\INSERT INTO COMMENTER (EMAIL, USERNAME, ROWID) values (?,?,?)
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    defer stmt.deinit();
    try stmt.exec(.{}, commenter);
}

pub fn insertCommenterIfNotExist(self: *Sqlite, commenter: Commenter) !usize {
    std.debug.assert(commenter.id == null);
    const id = try getCommenterId(self, commenter);
    if (id) |i| return i;
    const q = 
        \\INSERT INTO COMMENTER (EMAIL,USERNAME,ROWID) values (?,?,?) RETURNING ROWID
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    defer stmt.deinit();
    return (try stmt.one(usize, .{}, commenter)) orelse unreachable;
}

pub fn getCommenterId(self: *Sqlite, commenter: Commenter) !?usize {
    const q = 
        \\SELECT *, ROWID FROM COMMENTER 
        \\  WHERE EMAIL = ? and USERNAME = ?
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    defer stmt.deinit();
    return stmt.one(usize, .{}, .{commenter.email, commenter.username});
}

pub fn getCommenterById(self: *Sqlite, id: usize, arena: *Arena) !?Commenter{
    const q = 
        \\SELECT *, ROWID FROM COMMENTER WHERE ROWID = ?
    ;
    var stmt = self.db.prepare(q) catch unreachable;
    defer stmt.deinit();
    return stmt.oneAlloc(Commenter, arena.allocator(),.{}, .{id});
}


pub fn insertIpAddr(self: *Sqlite, ip: u32) !usize {
    const q1 = 
        \\ SELECT ROWID FROM IPADDR WHERE IP = ?
        ;
    var stmt_select = self.db.prepare(q1) catch unreachable;
    defer stmt_select.deinit();
    if (stmt_select.one(usize, .{}, .{ip}) catch |e| return e) |id| return id;
    const q2 = 
        \\ INSERT INTO IPADDR (IP) values (?) RETURNING ROWID
        ;
    var stmt_insert = self.db.prepare(q2) catch unreachable;
    defer stmt_insert.deinit();
    // uwnrap !?usize -> 
    return stmt_insert.one(usize, .{}, .{ip}) 
            catch |e| {return e; } 
            orelse unreachable;
}

pub fn insertIpMap(self: *Sqlite, ip_id: usize, post_id: usize) !void {
    const q = 
        \\ INSERT OR IGNORE INTO IPMAP (IPID, POSTID) values (?, ?)
        ;
    var stmt = self.db.prepare(q) catch unreachable;
    defer stmt.deinit();
    return stmt.exec(.{}, .{ip_id, post_id});
}

