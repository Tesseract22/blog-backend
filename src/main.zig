const std = @import("std");
const zap = @import("zap");
const Enpoint = @import("endpoint.zig");
const Sqlite = @import("sqlite.zig");
const Config = @import("config.zig");
const memeql = std.mem.eql;
// this is just to demo that we can catch arbitrary slugs


fn on_request(r: zap.SimpleRequest) void {
    blk: {
        const path =(r.path orelse break :blk)[1..];
        var it = std.mem.splitScalar(u8, path, '/');
        const sec = it.next() orelse break :blk;
        if (std.mem.eql(u8, sec, "article")) {
            const id = it.next() orelse "";
            if (id.len > 0) {
                r.sendFile(Config.PublicFolder ++ "index.html") catch break: blk;
                return;
            } else {
                std.debug.print("redirect\n", .{});
                return r.redirectTo("/", null) catch break: blk;
            }
        } else if (std.mem.eql(u8, sec, "login")) {
            r.sendFile(Config.PublicFolder ++ "html/login.html") catch break: blk;
            return;
        }
        
    }

    r.sendBody("<html><body><h1>404</h1></body></html>") catch return;
    r.setStatus(.not_found);
}

pub fn main() !void {
    
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    var allocator = gpa.allocator();
    var db = try Sqlite.init();
    defer db.deinit();
    // we scope everything that can allocate within this block for leak detection
    {
        // setup listener
        var listener = zap.SimpleEndpointListener.init(
            allocator,
            .{
                .port = Config.Port,
                .on_request = on_request,
                .log = true,
                .public_folder = Config.PublicFolder,
                .max_clients = 100000,
                .max_body_size = 100 * 1024 * 1024,
            },
        );
        defer listener.deinit();

        var post_end = Enpoint.PostEndPoint.init(allocator, "/post", &db);
        var comment_end = Enpoint.CommentEndPoint.init(allocator, "/comment", &db);
        var image_end = Enpoint.ImageEndPoint.init(allocator, "/image");
        try listener.addEndpoint(post_end.getEndpoint());
        try listener.addEndpoint(comment_end.getEndpoint());
        try listener.addEndpoint(image_end.getEndpoint());

        // listen
        try listener.listen();

        std.debug.print("Listening on 0.0.0.0:3000\n", .{});

        // and run
        zap.start(.{
            .threads = 2000,
            .workers = 1,
        });
    }

    // show potential memory leaks when ZAP is shut down
    const has_leaked = gpa.detectLeaks();
    std.log.debug("Has leaked: {}\n", .{has_leaked});
}
