const std = @import("std");
const builtin = @import("builtin");
const zap = @import("zap");
const Enpoint = @import("endpoint.zig");
const util = @import("util.zig");
const Sqlite = @import("sqlite.zig");
const Config = @import("config.zig");
const memeql = std.mem.eql;
const Cli = @import("cli.zig");

const Option = struct {
    port: u32,
    interface: [:0]const u8,
    db_path: [:0]const u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    var args = std.process.ArgIterator.init(); 
    defer args.deinit();

    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var opt: Option = undefined;

    var arg_parser = Cli.ArgParser {.a = allocator, .pgm_name = args.next().?};
    defer arg_parser.deinit();
    arg_parser.add_opt(u32, &opt.port, &3000, .{.prefix = "-p"}, "<port>", "ip port");
    arg_parser.add_opt([:0]const u8, &opt.interface, null, .positional, "<interface>", "ip interface");
    arg_parser.add_opt([:0]const u8, &opt.db_path, &"mock.db", .{.prefix = "-db"}, "<db-path>", "database path");
    try arg_parser.parse(&args);

    var db = try Sqlite.init(opt.db_path);
    defer db.deinit();
    { 
        var rand = std.Random.Xoroshiro128.init(@intCast(std.time.microTimestamp()));
        var ctx = Enpoint.Ctx {.db = db, .rand = rand.random()};
        const App = zap.App.Create(Enpoint.Ctx);
        try App.init(allocator, &ctx, .{});
        defer App.deinit();

        var post_end = Enpoint.PostEndPoint { .path = "/post" };
        var image_end = Enpoint.ImageEndPoint.init("/image");
        try App.register(&post_end);
        try App.register(&image_end);
        //try app.register(&comment_end);

        try App.listen(.{
            .interface = opt.interface,
            .port = opt.port,
            .public_folder = Config.PublicFolder,
            .max_body_size = 100 * 1024 * 1024, 
            .tls = null
        });

        std.log.debug("Web Starting at {s}:{}, using db {s}", .{opt.interface, opt.port, opt.db_path});


        zap.start(.{
            .threads = 2,
            .workers = 1,
        });
        // show potential memory leaks when ZAP is shut down
    }
}
