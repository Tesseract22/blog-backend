pub const PublicFolder = "public/";
pub const ImageFolder = "image/";
pub const AuthFile = "auth";
pub const Auth = "Bearer" ++ @embedFile(AuthFile);
pub const Port = 80;
