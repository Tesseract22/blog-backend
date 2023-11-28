const builtin = @import("builtin");
pub const PublicFolder = "public/";
pub const ImageFolder = "image/";
pub const AuthFile = "auth";
pub const Auth = "Bearer " ++ @embedFile(AuthFile);
pub const Port = switch (builtin.mode) {
    .Debug => 3300,
    else => 3000,
};
pub const Domain = "tesseract.cat";
pub const AdminCookieName = "admin-cookie";