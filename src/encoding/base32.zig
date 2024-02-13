const std = @import("std");
const base_coder = @import("base_coder.zig");
const BaseCoder = base_coder.BaseCoder;

pub const Error = base_coder.Error;

pub const CrockfordImpl = struct {
    pub const Symbol = u5;
    pub const set = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
    pub fn lookup(c: u8) Error!Symbol {
        return switch (c) {
            inline '0', 'O', 'o' => 0,
            inline '1', 'I', 'i', 'L', 'l' => 1,
            inline '2'...'9' => |i| i - '0',
            inline 'A'...'H' => |i| i - 'A' + 10,
            inline 'a'...'h' => |i| i - 'a' + 10,
            inline 'J'...'K' => |i| i - 'J' + 18,
            inline 'j'...'k' => |i| i - 'j' + 18,
            inline 'M'...'N' => |i| i - 'M' + 20,
            inline 'm'...'n' => |i| i - 'm' + 20,
            inline 'P'...'T' => |i| i - 'P' + 22,
            inline 'p'...'t' => |i| i - 'p' + 22,
            inline 'V'...'Z' => |i| i - 'V' + 27,
            inline 'v'...'z' => |i| i - 'v' + 27,
            // Accidental obscenity
            inline 'U', 'u' => error.InvalidCharacter,
            inline else => error.InvalidCharacter,
        };
    }
};

/// NOTE: This only supports subset of crockford
///       - Hyphens are not allowed
///       - No check symbols
/// https://www.crockford.com/base32.html
pub const crockford = BaseCoder(CrockfordImpl);

/// The superset of crockford is exactly as clockwork
/// However there is no support for encoding to lowercase
/// https://gist.github.com/szktty/228f85794e4187882a77734c89c384a8
pub const clockwork = crockford;
