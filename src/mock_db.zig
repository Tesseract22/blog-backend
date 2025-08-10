const std = @import("std");
const Sqlite = @import("sqlite");

pub fn main() !void {
    std.fs.cwd().deleteFile("mock.db") catch {};
    var schema_f = try std.fs.cwd().openFile("schema.sql", .{});
    defer schema_f.close();
    var buf = [_]u8 {0} ** 1024;
    const schema = buf[0..try schema_f.readAll(&buf)];
    schema[schema.len-1] = 0;
    var db = try Sqlite.Db.init(.{.open_flags = .{ .create =  true, .write  = true}, .mode = .{.File = "mock.db"} });
    defer db.deinit();
    
    var diag: Sqlite.Diagnostics = .{};
    db.execMulti(schema, .{.diags = &diag}) catch |e| {
        std.log.debug("{}: {f}", .{e, diag});
    };

    const insert = 
        \\INSERT INTO POST 
        \\(CREATED_TIME, MODIFIED_TIME, TITLE, VIEWS, AUTHOR, CONTENT, PUBLISHED, COVER_URL, ROWID)
        \\  values (
        \\          strftime('%s', 'now'),
        \\          strftime('%s', 'now'),
        \\          "My Blog", 
        \\          114515, 
        \\          "Author X",
        \\          "This is a cool blog post...",
        \\          true, 
        \\          "/image/cover.jpg", 
        \\          NULL)
        ;
    db.exec(insert, .{.diags = &diag}, .{}) catch |e| {
        std.log.debug("{}: {f}", .{e, diag});
    };

}
