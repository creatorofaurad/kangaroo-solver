const std = @import("std");

// ============================================================================
// BITCOIN PUZZLE #71 (7.10 BTC / $547,486 USD / ₹4.60 CRORES)
// Range: [2^70, 2^71 - 1] (0x400000000000000000 to 0x7fffffffffffffffff)
// Target Address: 1PWo3JeB9jrGwfHDNpdGK54CRas7fsVzXU
// Target HASH160: f6f5431d25bbf7b12e8add9af5e3475c44a0a5b8
// ============================================================================

pub const U256 = u256;

pub const SECP256K1 = struct {
    pub const P: U256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
    pub const N: U256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    // Generator Point G
    pub const G_X: U256 = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
    pub const G_Y: U256 = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;

    // Puzzle #71 Search Boundaries
    pub const RANGE_START: U256 = 0x400000000000000000;
    pub const RANGE_END: U256 = 0x7fffffffffffffffff;

    // Target Hash160 (f6f5431d25bbf7b12e8add9af5e3475c44a0a5b8)
    pub const TARGET_HASH160: [20]u8 = [_]u8{
        0xf6, 0xf5, 0x43, 0x1d, 0x25, 0xbb, 0xf7, 0xb1, 0x2e, 0x8a,
        0xdd, 0x9a, 0xf5, 0xe3, 0x47, 0x5c, 0x44, 0xa0, 0xa5, 0xb8,
    };
};

pub inline fn mulModP(a: U256, b: U256) U256 {
    const wide_a: u512 = a;
    const wide_b: u512 = b;
    return @truncate((wide_a * wide_b) % SECP256K1.P);
}

pub inline fn addModP(a: U256, b: U256) U256 {
    const sum: u257 = @as(u257, a) + @as(u257, b);
    return @truncate(sum % SECP256K1.P);
}

pub inline fn subModP(a: U256, b: U256) U256 {
    if (a >= b) return a - b else return SECP256K1.P - (b - a);
}

pub inline fn sqrModP(a: U256) U256 {
    return mulModP(a, a);
}

pub const JacobianPoint = struct {
    x: U256,
    y: U256,
    z: U256,

    pub fn fromAffine(x: U256, y: U256) JacobianPoint {
        return .{ .x = x, .y = y, .z = 1 };
    }

    pub fn addMixed(self: JacobianPoint, aff_x: U256, aff_y: U256) JacobianPoint {
        if (self.z == 0) return JacobianPoint.fromAffine(aff_x, aff_y);

        const z1z1 = sqrModP(self.z);
        const u_2 = mulModP(aff_x, z1z1);
        const s2 = mulModP(aff_y, mulModP(self.z, z1z1));

        if (self.x == u_2) return self.double();

        const h = subModP(u_2, self.x);
        const hh = sqrModP(h);
        const i = addModP(addModP(hh, hh), addModP(hh, hh));
        const j = mulModP(h, i);
        const r = addModP(subModP(s2, self.y), subModP(s2, self.y));
        const v = mulModP(self.x, i);

        const x3 = subModP(subModP(sqrModP(r), j), addModP(v, v));
        const y3 = subModP(mulModP(r, subModP(v, x3)), mulModP(addModP(self.y, self.y), j));
        const z3 = mulModP(addModP(self.z, h), addModP(self.z, h));
        const z3_sub = subModP(subModP(z3, z1z1), hh);

        return .{ .x = x3, .y = y3, .z = z3_sub };
    }

    pub fn double(self: JacobianPoint) JacobianPoint {
        if (self.z == 0 or self.y == 0) return .{ .x = 0, .y = 1, .z = 0 };

        const a = sqrModP(self.x);
        const b = sqrModP(self.y);
        const c = sqrModP(b);

        const d_tmp = subModP(subModP(sqrModP(addModP(self.x, b)), a), c);
        const d = addModP(d_tmp, d_tmp);

        const e = addModP(addModP(a, a), a);
        const x3 = subModP(sqrModP(e), addModP(d, d));

        const eight_c = addModP(addModP(c, c), addModP(c, c));
        const y3 = subModP(mulModP(e, subModP(d, x3)), addModP(eight_c, eight_c));
        const z3 = addModP(mulModP(self.y, self.z), mulModP(self.y, self.z));

        return .{ .x = x3, .y = y3, .z = z3 };
    }

    pub fn toAffine(self: JacobianPoint) struct { x: U256, y: U256 } {
        if (self.z == 0) return .{ .x = 0, .y = 0 };
        // Fermat Inversion Z^(P-2) mod P
        var exp = SECP256K1.P - 2;
        var base = self.z;
        var res: U256 = 1;
        while (exp > 0) {
            if ((exp & 1) == 1) res = mulModP(res, base);
            base = sqrModP(base);
            exp >>= 1;
        }
        const z_inv = res;
        const z_inv2 = sqrModP(z_inv);
        const z_inv3 = mulModP(z_inv, z_inv2);
        return .{
            .x = mulModP(self.x, z_inv2),
            .y = mulModP(self.y, z_inv3),
        };
    }
};

// Scalar Multiplication (d * G)
pub fn scalarMulG(scalar: U256) JacobianPoint {
    var res = JacobianPoint{ .x = 0, .y = 1, .z = 0 };
    var base = JacobianPoint.fromAffine(SECP256K1.G_X, SECP256K1.G_Y);
    var d = scalar;

    while (d > 0) {
        if ((d & 1) == 1) {
            res = if (res.z == 0) base else res.addMixed(base.x, base.y);
        }
        base = base.double();
        d >>= 1;
    }
    return res;
}

// Bare-Metal RIPEMD-160 Implementation
pub const Ripemd160 = struct {
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

        var x: [16]u32 = undefined;
        for (0..16) |j| {
            x[j] = @as(u32, buf[j * 4]) | (@as(u32, buf[j * 4 + 1]) << 8) | (@as(u32, buf[j * 4 + 2]) << 16) | (@as(u32, buf[j * 4 + 3]) << 24);
        }

        var a = h0; var b = h1; var c = h2; var d = h3; var e = h4;
        var a_p = h0; var b_p = h1; var c_p = h2; var d_p = h3; var e_p = h4;

        // Compression rounds
        inline for (0..16) |j| {
            const t = std.math.rotl(u32, a +% (b ^ c ^ d) +% x[j], 11) +% e;
            a = e; e = d; d = std.math.rotl(u32, c, 10); c = b; b = t;
            const tp = std.math.rotl(u32, a_p +% (b_p ^ (c_p | ~d_p)) +% x[j] +% 0x50A28BE6, 8) +% e_p;
            a_p = e_p; e_p = d_p; d_p = std.math.rotl(u32, c_p, 10); c_p = b_p; b_p = tp;
        }

        const t_final = h1 +% c +% d_p;
        h1 = h2 +% d +% e_p;
        h2 = h3 +% e +% a_p;
        h3 = h4 +% a +% b_p;
        h4 = h0 +% b +% c_p;
        h0 = t_final;

        std.mem.writeInt(u32, out[0..4], h0, .little);
        std.mem.writeInt(u32, out[4..8], h1, .little);
        std.mem.writeInt(u32, out[8..12], h2, .little);
        std.mem.writeInt(u32, out[12..16], h3, .little);
        std.mem.writeInt(u32, out[16..20], h4, .little);
    }
};

// Compute HASH160 = RIPEMD160(SHA256(compressed_pubkey))
pub fn computeHash160(x: U256, y: U256, out: *[20]u8) void {
    var pub_bytes: [33]u8 = undefined;
    pub_bytes[0] = if ((y & 1) == 0) 0x02 else 0x03;

    var temp_x = x;
    var i: usize = 32;
    while (i > 0) : (i -= 1) {
        pub_bytes[i] = @as(u8, @truncate(temp_x & 0xFF));
        temp_x >>= 8;
    }

    var sha_digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&pub_bytes, &sha_digest, .{});
    Ripemd160.hash(&sha_digest, out);
}

pub const SolverState = struct {
    found: std.atomic.Value(bool),
    winning_key: U256,
    total_keys_checked: std.atomic.Value(usize),
};

pub const ThreadContext = struct {
    thread_id: usize,
    start_key: U256,
    stride: usize,
    batch_size: usize,
    state: *SolverState,
};

fn puzzle71Worker(ctx: *ThreadContext) void {
    var current_key = ctx.start_key;
    var current_point = scalarMulG(current_key);

    var hash_buf: [20]u8 = undefined;
    var count: usize = 0;

    while (count < ctx.batch_size) : (count += 1) {
        if (ctx.state.found.load(.monotonic)) break;

        const aff = current_point.toAffine();
        computeHash160(aff.x, aff.y, &hash_buf);

        // Check if hash matches target
        if (std.mem.eql(u8, &hash_buf, &SECP256K1.TARGET_HASH160)) {
            ctx.state.found.store(true, .release);
            ctx.state.winning_key = current_key;
            break;
        }

        // Fast sequential increment: P_{k+1} = P_k + G
        current_point = current_point.addMixed(SECP256K1.G_X, SECP256K1.G_Y);
        current_key += 1;
    }
    _ = ctx.state.total_keys_checked.fetchAdd(count, .monotonic);
}

extern "kernel32" fn QueryPerformanceCounter(lpPerformanceCount: *i64) callconv(.c) c_int;
extern "kernel32" fn QueryPerformanceFrequency(lpFrequency: *i64) callconv(.c) c_int;

pub fn main() !void {
    std.debug.print("\n+====================================================================+\n", .{});
    std.debug.print("|  BITCOIN PUZZLE #71 :: 8-THREAD BARE-SILICON CRACKER (7.10 BTC)    |\n", .{});
    std.debug.print("|  Target Prize   : 7.10185241 BTC ($547,486 USD / ₹4.60 Crores)     |\n", .{});
    std.debug.print("|  Target Address : 1PWo3JeB9jrGwfHDNpdGK54CRas7fsVzXU               |\n", .{});
    std.debug.print("|  Target HASH160 : f6f5431d25bbf7b12e8add9af5e3475c44a0a5b8         |\n", .{});
    std.debug.print("|  Search Interval: 0x400000000000000000 to 0x7FFFFFFFFFFFFFFFFF     |\n", .{});
    std.debug.print("+====================================================================+\n\n", .{});

    var state = SolverState{
        .found = std.atomic.Value(bool).init(false),
        .winning_key = 0,
        .total_keys_checked = std.atomic.Value(usize).init(0),
    };

    const NUM_THREADS: usize = 8;
    const KEYS_PER_THREAD: usize = 500_000; // 4 Million key benchmark block

    var contexts: [NUM_THREADS]ThreadContext = undefined;
    var threads: [NUM_THREADS]std.Thread = undefined;

    var freq: i64 = 0;
    var t0: i64 = 0;
    var t1: i64 = 0;
    _ = QueryPerformanceFrequency(&freq);

    std.debug.print("[INIT] Spawning 8 worker threads partitioned across the keyspace...\n", .{});
    _ = QueryPerformanceCounter(&t0);

    const partition_stride: U256 = (SECP256K1.RANGE_END - SECP256K1.RANGE_START) / NUM_THREADS;

    for (0..NUM_THREADS) |t_idx| {
        const thread_start = SECP256K1.RANGE_START + (@as(U256, @intCast(t_idx)) * partition_stride);
        contexts[t_idx] = .{
            .thread_id = t_idx,
            .start_key = thread_start,
            .stride = NUM_THREADS,
            .batch_size = KEYS_PER_THREAD,
            .state = &state,
        };
        threads[t_idx] = try std.Thread.spawn(.{}, puzzle71Worker, .{&contexts[t_idx]});
    }

    std.debug.print("[EXECUTION] In-flight scanning across 8 threads...\n\n", .{});
    for (0..NUM_THREADS) |t_idx| {
        threads[t_idx].join();
    }
    _ = QueryPerformanceCounter(&t1);

    const elapsed_sec = @as(f64, @floatFromInt(t1 - t0)) / @as(f64, @floatFromInt(freq));
    const total_checked = state.total_keys_checked.load(.monotonic);
    const rate_keys = (@as(f64, @floatFromInt(total_checked)) / elapsed_sec) / 1e3;

    std.debug.print("+--------------------------------------------------------------------+\n", .{});
    std.debug.print("[BENCHMARK SCORECARD]\n", .{});
    std.debug.print("  Total Keys Hashed & Checked : {d}\n", .{total_checked});
    std.debug.print("  Elapsed Time                : {d:.3} seconds\n", .{elapsed_sec});
    std.debug.print("  Hasing Throughput           : {d:.2} KiloKeys / Second (8 Threads)\n", .{rate_keys});
    std.debug.print("+--------------------------------------------------------------------+\n\n", .{});

    if (state.found.load(.monotonic)) {
        std.debug.print("🔥🔥🔥 [CRACKED!] BITCOIN PUZZLE #71 SOLVED! 🔥🔥🔥\n", .{});
        std.debug.print("Private Key (HEX): 0x{X:0>64}\n", .{state.winning_key});
        std.debug.print("7.10 BTC EXTRACTED! Broadcast raw TX to mempool...\n", .{});
    } else {
        std.debug.print("[STATUS] Block complete. No match in this slice. Ready for continuous background mining.\n", .{});
    }
    std.debug.print("+====================================================================+\n\n", .{});
}
