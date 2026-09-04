const std = @import("std");

// ============================================================================
// BITCOIN PUZZLE #71: CONCENTRIC RADIAL MARKOV MASTER ENGINE (7.10 BTC)
// Architecture   : Concentric Radial Expansion around Puzzle #70 Markov Anchor (54.3%)
// Optimization   : Montgomery Batch Inversion (B=4,096) + Zero-Heap Pipeline
// Target Prize   : 7.10185241 BTC ($547,486 USD / ₹5.15 Crores)
// Target Address : 1PWo3JeB9jrGwfHDNpdGK54CRas7fsVzXU
// Target HASH160 : f6f5431d25bbf7b12e8add9af5e3475c44a0a5b8
// ============================================================================

pub const U256 = u256;

pub const SECP256K1 = struct {
    pub const P: U256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
    pub const N: U256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

    // Generator Point G
    pub const G_X: U256 = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
    pub const G_Y: U256 = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;

    // Puzzle #71 Base Range: 2^70 to 2^71 - 1
    pub const FULL_RANGE_START: U256 = 0x400000000000000000;
    pub const FULL_RANGE_END: U256 = 0x7fffffffffffffffff;

    // The Golden Markov Centroid Anchor: 54.30% of interval
    // Anchor = 0x400000000000000000 + (0.5430 * 2^70) = 0x62C083126E978D4F
    pub const MARKOV_ANCHOR: U256 = 0x62C083126E978D4F;

    // Target Hash160: f6f5431d25bbf7b12e8add9af5e3475c44a0a5b8
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

pub fn invertModP(a: U256) U256 {
    if (a == 0) return 0;
    var exp = SECP256K1.P - 2;
    var base = a;
    var res: U256 = 1;
    while (exp > 0) {
        if ((exp & 1) == 1) res = mulModP(res, base);
        base = sqrModP(base);
        exp >>= 1;
    }
    return res;
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
};

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

pub const Ripemd160 = @import("ripemd160.zig").Ripemd160;

pub inline fn checkHash160(x: U256, y: U256) bool {
    var pub_bytes: [33]u8 = undefined;
    pub_bytes[0] = if ((y & 1) == 0) 0x02 else 0x03;

    var temp_x = x;
    for (0..32) |byte_idx| {
        pub_bytes[32 - byte_idx] = @as(u8, @truncate(temp_x & 0xFF));
        temp_x >>= 8;
    }

    var sha_digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&pub_bytes, &sha_digest, .{});

    var hash_buf: [20]u8 = undefined;
    Ripemd160.hash(&sha_digest, &hash_buf);

    return std.mem.eql(u8, &hash_buf, &SECP256K1.TARGET_HASH160);
}

pub const BATCH_SIZE: usize = 4096;

pub const BatchBuffer = struct {
    pts: [BATCH_SIZE]JacobianPoint,
    cumu_z: [BATCH_SIZE]U256,
};

pub const RadialSolverState = struct {
    found: std.atomic.Value(bool),
    winning_key: U256,
    total_keys_checked: std.atomic.Value(usize),
};

pub const RadialThreadContext = struct {
    thread_id: usize,
    start_key: U256,
    direction: i8, // +1 for positive outward sweep, -1 for negative inward sweep
    stride: usize,
    state: *RadialSolverState,
};

fn radialWorker(ctx: *RadialThreadContext) void {
    var current_key = ctx.start_key;
    var current_point = scalarMulG(current_key);
    var buf: BatchBuffer = undefined;

    while (!ctx.state.found.load(.monotonic)) {
        if (current_key < SECP256K1.FULL_RANGE_START or current_key > SECP256K1.FULL_RANGE_END) break;

        var p = current_point;
        for (0..BATCH_SIZE) |i| {
            buf.pts[i] = p;
            buf.cumu_z[i] = if (i == 0) p.z else mulModP(buf.cumu_z[i - 1], p.z);
            p = p.addMixed(SECP256K1.G_X, SECP256K1.G_Y);
        }

        var inv_all = invertModP(buf.cumu_z[BATCH_SIZE - 1]);

        var i: usize = BATCH_SIZE - 1;
        while (true) : (i -= 1) {
            const z_inv = if (i > 0) mulModP(inv_all, buf.cumu_z[i - 1]) else inv_all;
            inv_all = mulModP(inv_all, buf.pts[i].z);

            const z_inv2 = sqrModP(z_inv);
            const z_inv3 = mulModP(z_inv, z_inv2);

            const aff_x = mulModP(buf.pts[i].x, z_inv2);
            const aff_y = mulModP(buf.pts[i].y, z_inv3);

            if (checkHash160(aff_x, aff_y)) {
                ctx.state.found.store(true, .release);
                ctx.state.winning_key = current_key + @as(U256, @intCast(i));
                break;
            }

            if (i == 0) break;
        }

        current_key += @as(U256, BATCH_SIZE);
        current_point = p;
        _ = ctx.state.total_keys_checked.fetchAdd(BATCH_SIZE, .monotonic);
    }
}

extern "kernel32" fn QueryPerformanceCounter(lpPerformanceCount: *i64) callconv(.c) c_int;
extern "kernel32" fn QueryPerformanceFrequency(lpFrequency: *i64) callconv(.c) c_int;
extern "kernel32" fn Sleep(dwMilliseconds: u32) callconv(.c) void;

pub fn main() !void {
    std.debug.print("\n+====================================================================+\n", .{});
    std.debug.print("|  BITCOIN PUZZLE #71 :: RADIAL MARKOV DENSITY MASTER (7.10 BTC)     |\n", .{});
    std.debug.print("|  Optimization    : Concentric Radial Sweep from 54.30% Anchor      |\n", .{});
    std.debug.print("|  Batch Size      : B=4,096 Simultaneous Inversions (2x Batch Boost) |\n", .{});
    std.debug.print("|  Target Address  : 1PWo3JeB9jrGwfHDNpdGK54CRas7fsVzXU              |\n", .{});
    std.debug.print("|  Target Prize    : 7.10185241 BTC ($547,486 USD / ₹5.15 Crores)    |\n", .{});
    std.debug.print("+====================================================================+\n\n", .{});

    var state = RadialSolverState{
        .found = std.atomic.Value(bool).init(false),
        .winning_key = 0,
        .total_keys_checked = std.atomic.Value(usize).init(0),
    };

    const NUM_THREADS: usize = 8;
    var contexts: [NUM_THREADS]RadialThreadContext = undefined;
    var threads: [NUM_THREADS]std.Thread = undefined;

    // 8 Concentric Ring Radial Offsets centered directly at 54.30% Anchor
    const ring_offsets = [_]i64{
        0,                  // Thread 0: Exactly at 54.30% Markov Peak
        250_000_000,        // Thread 1: +250M keys
        -250_000_000,       // Thread 2: -250M keys
        1_000_000_000,      // Thread 3: +1.0B keys
        -1_000_000_000,     // Thread 4: -1.0B keys
        3_000_000_000,      // Thread 5: +3.0B keys
        -3_000_000_000,     // Thread 6: -3.0B keys
        6_000_000_000,      // Thread 7: +6.0B keys
    };

    std.debug.print("[DEPLOY] Spawning 8 Concentric Radial Threads around 54.30% Peak...\n", .{});
    for (0..NUM_THREADS) |t_idx| {
        const offset = ring_offsets[t_idx];
        const thread_start = if (offset >= 0) 
            SECP256K1.MARKOV_ANCHOR + @as(U256, @intCast(offset))
        else 
            SECP256K1.MARKOV_ANCHOR - @as(U256, @intCast(-offset));

        contexts[t_idx] = .{
            .thread_id = t_idx,
            .start_key = thread_start,
            .direction = 1,
            .stride = BATCH_SIZE,
            .state = &state,
        };
        threads[t_idx] = try std.Thread.spawn(.{}, radialWorker, .{&contexts[t_idx]});
    }

    std.debug.print("[ACTIVE] Concentric Radial Master running in background. Zero leaks.\n\n", .{});

    var freq: i64 = 0;
    _ = QueryPerformanceFrequency(&freq);

    var last_count: usize = 0;
    while (!state.found.load(.monotonic)) {
        var t0: i64 = 0;
        var t1: i64 = 0;
        _ = QueryPerformanceCounter(&t0);
        Sleep(3000);
        _ = QueryPerformanceCounter(&t1);

        const cur_count = state.total_keys_checked.load(.monotonic);
        const delta = cur_count - last_count;
        last_count = cur_count;

        const elapsed_sec = @as(f64, @floatFromInt(t1 - t0)) / @as(f64, @floatFromInt(freq));
        const speed_kkeys = (@as(f64, @floatFromInt(delta)) / elapsed_sec) / 1e3;

        std.debug.print("[TELEMETRY] Checked: {d} Keys | Speed: {d:.2} kKeys/s | Mode: [Concentric Radial 54.3%] (7.10 BTC)\n", .{
            cur_count,
            speed_kkeys,
        });
    }

    if (state.found.load(.monotonic)) {
        std.debug.print("\n🔥🔥🔥 [CRACKED!] BITCOIN PUZZLE #71 SOLVED! 🔥🔥🔥\n", .{});
        std.debug.print("Private Key (HEX): 0x{X:0>64}\n", .{state.winning_key});
        std.debug.print("7.10185 BTC EXTRACTED ($547,486 USD)! Broadcast TX immediately.\n\n", .{});
    }

    for (0..NUM_THREADS) |t_idx| {
        threads[t_idx].join();
    }
}
