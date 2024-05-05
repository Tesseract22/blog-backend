const builtin = @import("builtin");
pub const PublicFolder = "public/";
pub const ImageFolder = "image/";
pub const AuthFile = "auth";
const fmt = @import("std").fmt;
pub const AuthPrefix = "Bearer ";
pub const Auth = fmt.parseInt(u64, @embedFile(AuthFile), 16) 
    catch @compileError(AuthFile ++ " must be a hex number"); 
pub const Port = switch (builtin.mode) {
    .Debug => 3300,
    else => 3000,
};
pub const Domain = "tesseract-cat.com";
pub const AdminCookieName = "admin-cookie";
pub const DbPath = if (builtin.mode == .Debug) "test.db" else "blog.db";