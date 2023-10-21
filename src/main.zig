const std = @import("std");
const zap = @import("zap");
const PostEndpoint = @import("post_endpoint.zig");
const CommentEndPoint = @import("comment_endpoint.zig");
const Sqlite = @import("sqlite.zig");
// this is just to demo that we can catch arbitrary slugs
fn on_request(r: zap.SimpleRequest) void {
    if (r.path) |the_path| {
        std.debug.print("REQUESTED PATH: {s}\n", .{the_path});
    }
    r.sendBody("<html><body><h1>Hello from ZAP!!!</h1></body></html>") catch return;
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
                .port = 3000,
                .on_request = on_request,
                .log = true,
                .public_folder = "html",
                .max_clients = 100000,
                .max_body_size = 100 * 1024 * 1024,
            },
        );
        defer listener.deinit();

        var post_end = PostEndpoint.init(allocator, "/post", &db);
        var comment_end = CommentEndPoint.init(allocator, "/comment", &db);

        // add endpoint
        try listener.addEndpoint(post_end.getEndpoint());
        try listener.addEndpoint(comment_end.getEndpoint());

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
