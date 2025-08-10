const builtin = @import("builtin");
pub const PublicFolder = "public/";
pub const ImageFolder = "image/";
pub const AuthFile = "auth";
const fmt = @import("std").fmt;
pub const AuthPrefix = "Bearer ";
pub const Auth = fmt.parseInt(u64, @embedFile(AuthFile), 16) 
    catch @compileError(AuthFile ++ " must be a hex number"); 
pub const Domain = @embedFile("domain");
pub const AdminCookieName = "admin-cookie";
pub const DbPath = if (builtin.mode == .Debug) "mock.db" else "blog.db";
