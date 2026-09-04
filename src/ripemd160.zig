const std = @import("std");

pub const Ripemd160 = struct {
    pub const digest_length = 20;
    pub const block_length = 64;

    fn f1(x: u32, y: u32, z: u32) u32 { return x ^ y ^ z; }
    fn f2(x: u32, y: u32, z: u32) u32 { return (x & y) | (~x & z); }
    fn f3(x: u32, y: u32, z: u32) u32 { return (x | ~y) ^ z; }
    fn f4(x: u32, y: u32, z: u32) u32 { return (x & z) | (y & ~z); }
    fn f5(x: u32, y: u32, z: u32) u32 { return x ^ (y | ~z); }

    pub fn hash(msg: []const u8, out: *[20]u8) void {
        var h0: u32 = 0x67452301;
        var h1: u32 = 0xEFCDAB89;
        var h2: u32 = 0x98BADCFE;
        var h3: u32 = 0x10325476;
        var h4: u32 = 0xC3D2E1F0;

        var buf: [64]u8 = [_]u8{0} ** 64;
        const msg_len = msg.len;
        @memcpy(buf[0..msg_len], msg);
        buf[msg_len] = 0x80;

        const bit_len = @as(u64, msg_len) * 8;
        buf[56] = @as(u8, @truncate(bit_len));
        buf[57] = @as(u8, @truncate(bit_len >> 8));
        buf[58] = @as(u8, @truncate(bit_len >> 16));
        buf[59] = @as(u8, @truncate(bit_len >> 24));
        buf[60] = @as(u8, @truncate(bit_len >> 32));
        buf[61] = @as(u8, @truncate(bit_len >> 40));
        buf[62] = @as(u8, @truncate(bit_len >> 48));
        buf[63] = @as(u8, @truncate(bit_len >> 56));

        var x: [16]u32 = undefined;
        for (0..16) |j| {
            x[j] = @as(u32, buf[j * 4]) | (@as(u32, buf[j * 4 + 1]) << 8) | (@as(u32, buf[j * 4 + 2]) << 16) | (@as(u32, buf[j * 4 + 3]) << 24);
        }

        const rl = [_]u5{
            11, 14, 15, 12, 5, 8, 7, 9, 11, 13, 14, 15, 6, 7, 9, 8,
            7, 6, 8, 13, 11, 9, 7, 15, 7, 12, 15, 9, 11, 7, 13, 12,
            11, 13, 6, 7, 14, 9, 13, 15, 14, 8, 13, 6, 5, 12, 7, 5,
            11, 12, 14, 15, 14, 15, 9, 8, 9, 14, 5, 6, 8, 6, 5, 12,
            9, 15, 5, 11, 6, 8, 13, 12, 5, 12, 13, 14, 11, 8, 5, 6,
        };
        const rr = [_]u5{
            8, 9, 9, 11, 13, 15, 15, 5, 7, 7, 8, 11, 14, 14, 12, 6,
            9, 13, 15, 7, 12, 8, 9, 11, 7, 7, 12, 7, 6, 15, 13, 11,
            9, 7, 15, 11, 8, 6, 6, 14, 12, 13, 5, 14, 13, 13, 7, 5,
            15, 5, 8, 11, 14, 14, 6, 14, 6, 9, 12, 9, 12, 5, 15, 8,
            8, 5, 12, 9, 12, 5, 14, 6, 8, 13, 6, 5, 15, 13, 11, 11,
        };

        const sl = [_]u4{
            0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
            7, 4, 13, 1, 10, 6, 15, 3, 12, 0, 9, 5, 2, 14, 11, 8,
            3, 10, 14, 4, 9, 15, 8, 1, 2, 7, 0, 6, 13, 11, 5, 12,
            1, 9, 11, 10, 0, 8, 12, 4, 13, 3, 7, 15, 14, 5, 6, 2,
            4, 0, 5, 9, 7, 12, 2, 10, 14, 1, 3, 8, 11, 6, 15, 13,
        };
        const sr = [_]u4{
            5, 14, 7, 0, 9, 2, 11, 4, 13, 6, 15, 8, 1, 10, 3, 12,
            6, 11, 3, 7, 0, 13, 5, 10, 14, 15, 8, 12, 4, 9, 1, 2,
            15, 5, 1, 3, 7, 14, 6, 9, 11, 8, 12, 2, 10, 0, 4, 13,
            8, 6, 4, 1, 3, 11, 15, 0, 5, 12, 2, 13, 9, 7, 10, 14,
            12, 15, 10, 4, 1, 5, 8, 7, 6, 2, 13, 14, 0, 3, 9, 11,
        };

        var al = h0; var bl = h1; var cl = h2; var dl = h3; var el = h4;
        var ar = h0; var br = h1; var cr = h2; var dr = h3; var er = h4;

        for (0..80) |j| {
            var fl: u32 = 0;
            var kl: u32 = 0;
            var fr: u32 = 0;
            var kr: u32 = 0;

            if (j < 16) {
                fl = f1(bl, cl, dl); kl = 0x00000000;
                fr = f5(br, cr, dr); kr = 0x50A28BE6;
            } else if (j < 32) {
                fl = f2(bl, cl, dl); kl = 0x5A827999;
                fr = f4(br, cr, dr); kr = 0x5C4DD124;
            } else if (j < 48) {
                fl = f3(bl, cl, dl); kl = 0x6ED9EBA1;
                fr = f3(br, cr, dr); kr = 0x6D703EF3;
            } else if (j < 64) {
                fl = f4(bl, cl, dl); kl = 0x8F1BBCDC;
                fr = f2(br, cr, dr); kr = 0x7A6D76E9;
            } else {
                fl = f5(bl, cl, dl); kl = 0xA953FD4E;
                fr = f1(br, cr, dr); kr = 0x00000000;
            }

            const tl = std.math.rotl(u32, al +% fl +% x[sl[j]] +% kl, rl[j]) +% el;
            al = el; el = dl; dl = std.math.rotl(u32, cl, 10); cl = bl; bl = tl;

            const tr = std.math.rotl(u32, ar +% fr +% x[sr[j]] +% kr, rr[j]) +% er;
            ar = er; er = dr; dr = std.math.rotl(u32, cr, 10); cr = br; br = tr;
        }

        const t = h1 +% cl +% dr;
        h1 = h2 +% dl +% er;
        h2 = h3 +% el +% ar;
        h3 = h4 +% al +% br;
        h4 = h0 +% bl +% cr;
        h0 = t;

        std.mem.writeInt(u32, out[0..4], h0, .little);
        std.mem.writeInt(u32, out[4..8], h1, .little);
        std.mem.writeInt(u32, out[8..12], h2, .little);
        std.mem.writeInt(u32, out[12..16], h3, .little);
        std.mem.writeInt(u32, out[16..20], h4, .little);
    }
};
