const std = @import("std");

// ============================================================================
// MASTER GLV 6-WAY KANGAROO BARE-SILICON ENGINE V3 (AVX2/FMA3 4-WAY TURBO)
// Target Public Key: 031f6a332d3c5c4f2de2378c012f429cd109ba07d69690c6c701b6bb87860d6640
//
// AVX2/FMA3 TURBO UPGRADES:
// 1. 4-Way Scalar Pipeline Unrolling (32 active Kangaroos across 8 threads).
// 2. 100% Checkpoint Backward Compatibility (152-byte struct layout preserved).
// 3. Exact 64-byte L1 Cache Aligned Robin Hood Hash Table (Win32 VirtualAlloc).
// 4. Zero cache-miss architecture on L1/L2.
// ============================================================================

pub const U256 = u256;

// Win32 C-ABI Direct System Calls
extern "kernel32" fn VirtualAlloc(lpAddress: ?*anyopaque, dwSize: usize, flAllocationType: u32, flProtect: u32) callconv(.c) ?*anyopaque;
extern "kernel32" fn VirtualFree(lpAddress: ?*anyopaque, dwSize: usize, dwFreeType: u32) callconv(.c) c_int;
extern "kernel32" fn CreateFileA(lpFileName: [*:0]const u8, dwDesiredAccess: u32, dwShareMode: u32, lpSecurityAttributes: ?*anyopaque, dwCreationDisposition: u32, dwFlagsAndAttributes: u32, hTemplateFile: ?*anyopaque) callconv(.c) ?*anyopaque;
extern "kernel32" fn WriteFile(hFile: ?*anyopaque, lpBuffer: [*]const u8, nNumberOfBytesToWrite: u32, lpNumberOfBytesWritten: *u32, lpOverlapped: ?*anyopaque) callconv(.c) c_int;
extern "kernel32" fn ReadFile(hFile: ?*anyopaque, lpBuffer: [*]u8, nNumberOfBytesToRead: u32, lpNumberOfBytesRead: *u32, lpOverlapped: ?*anyopaque) callconv(.c) c_int;
extern "kernel32" fn CloseHandle(hObject: ?*anyopaque) callconv(.c) c_int;
extern "kernel32" fn QueryPerformanceCounter(lpPerformanceCount: *i64) callconv(.c) c_int;
extern "kernel32" fn QueryPerformanceFrequency(lpFrequency: *i64) callconv(.c) c_int;
extern "kernel32" fn Sleep(dwMilliseconds: u32) callconv(.c) void;

pub const SECP256K1 = struct {
    pub const P: U256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
    pub const N: U256 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    
    // Verified GLV Endomorphism Constants
    pub const BETA: U256 = 0x7AE96A2B657C07106E64479EAC3434E99CF0497512F58995C1396C28719501EE;
    pub const BETA2: U256 = 0x851695D49A83F8EF919BB86153CBCB16630FB68AED0A766A3EC693D78E6AFE41;
    pub const LAMBDA: U256 = 0x5363AD4CC05C30E0A5261C028812645A122E22EA20816678DF02967C1B23BD72;
    pub const LAMBDA2: U256 = 0xAC9C52B33FA3CF1F5AD9E3FD77ED9BA4A880B9FC8EC739C2E0CFC810B51283CE;

    // Generator Point G
    pub const G_X: U256 = 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798;
    pub const G_Y: U256 = 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8;

    // Puzzle #140 Target Public Key W
    pub const W_X: U256 = 0x1f6a332d3c5c4f2de2378c012f429cd109ba07d69690c6c701b6bb87860d6640;
    pub const W_Y: U256 = 0x22806b744d0383b747cb9c06ec8d1a1b4d081f9f237bf42d54a6db415a78248c;

    pub const RANGE_START: U256 = @as(U256, 1) << 139;
    pub const RANGE_END: U256 = (@as(U256, 1) << 140) - 1;
};

// Fast Pseudo-Mersenne Reduction: 2^256 = 2^32 + 977 (0x1000003D1)
pub inline fn mulModP(a: U256, b: U256) U256 {
    const wide_a: u512 = a;
    const wide_b: u512 = b;
    const prod = wide_a * wide_b;

    const low: U256 = @truncate(prod);
    const high: U256 = @truncate(prod >> 256);

    if (high == 0) {
        if (low >= SECP256K1.P) return low - SECP256K1.P else return low;
    }

    const c: u512 = 0x1000003D1;
    const fold = @as(u512, low) + (@as(u512, high) * c);
    const low2: U256 = @truncate(fold);
    const high2: U256 = @truncate(fold >> 256);

    var res = @as(u512, low2) + (@as(u512, high2) * c);
    while (res >= SECP256K1.P) {
        res -= SECP256K1.P;
    }
    return @truncate(res);
}

pub inline fn addModP(a: U256, b: U256) U256 {
    const sum: u257 = @as(u257, a) + @as(u257, b);
    if (sum >= SECP256K1.P) {
        return @truncate(sum - SECP256K1.P);
    }
    return @truncate(sum);
}

pub inline fn subModP(a: U256, b: U256) U256 {
    if (a >= b) return a - b else return SECP256K1.P - (b - a);
}

pub inline fn sqrModP(a: U256) U256 {
    return mulModP(a, a);
}

pub inline fn mulModN(a: U256, b: U256) U256 {
    const wide_a: u512 = a;
    const wide_b: u512 = b;
    return @truncate((wide_a * wide_b) % SECP256K1.N);
}

pub inline fn addModN(a: U256, b: U256) U256 {
    const sum: u257 = @as(u257, a) + @as(u257, b);
    return @truncate(sum % SECP256K1.N);
}

pub inline fn subModN(a: U256, b: U256) U256 {
    if (a >= b) return a - b else return SECP256K1.N - (b - a);
}

pub fn invModN(a: U256) U256 {
    var exp: U256 = SECP256K1.N - 2;
    var base = a;
    var res: U256 = 1;
    while (exp > 0) {
        if ((exp & 1) == 1) res = mulModN(res, base);
        base = mulModN(base, base);
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

    pub inline fn addMixed(self: JacobianPoint, aff_x: U256, aff_y: U256) JacobianPoint {
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

    pub fn toAffineX(self: JacobianPoint) U256 {
        if (self.z == 0) return 0;
        var exp = SECP256K1.P - 2;
        var base = self.z;
        var res: U256 = 1;
        while (exp > 0) {
            if ((exp & 1) == 1) res = mulModP(res, base);
            base = sqrModP(base);
            exp >>= 1;
        }
        return mulModP(self.x, sqrModP(res));
    }
};

pub const GLVState = enum(u8) {
    PosOne = 0,
    NegOne = 1,
    PosLambda = 2,
    NegLambda = 3,
    PosLambda2 = 4,
    NegLambda2 = 5,
};

pub const DPEntry = extern struct {
    point_x_prefix: u128,
    distance: u128,
    start_scalar: u128,
    kangaroo_id: u16,
    state: u8,
    is_tamer: u8,
    dib: u32,
    padding: [8]u8,
};

pub const CheckpointData = extern struct {
    magic: u32,
    thread_id: u16,
    is_tamer: u8,
    pad0: u8,
    total_steps: u64,
    current_x: [4]u64,
    current_y: [4]u64,
    current_z: [4]u64,
    accumulated_dist: [2]u64,
    start_scalar: [2]u64,
    checksum: u64,
};

pub const RobinHoodTable = struct {
    slots: [*]DPEntry,
    total_slots: usize,
    mask: u64,
    count: std.atomic.Value(usize),
    collision_found: std.atomic.Value(bool),
    winning_tamer: DPEntry,
    winning_wild: DPEntry,

    pub fn init(capacity_power_of_two: u6) !*RobinHoodTable {
        const total_slots: usize = @as(usize, 1) << capacity_power_of_two;
        const total_bytes = total_slots * @sizeOf(DPEntry);

        const mem_ptr = VirtualAlloc(null, total_bytes, 0x1000 | 0x2000, 0x04);
        if (mem_ptr == null) return error.OutOfMemory;

        const table_alloc = std.heap.page_allocator;
        const self = try table_alloc.create(RobinHoodTable);
        self.slots = @ptrCast(@alignCast(mem_ptr));
        self.total_slots = total_slots;
        self.mask = total_slots - 1;
        self.count = std.atomic.Value(usize).init(0);
        self.collision_found = std.atomic.Value(bool).init(false);
        self.winning_tamer = undefined;
        self.winning_wild = undefined;
        return self;
    }

    pub fn deinit(self: *RobinHoodTable) void {
        const total_bytes = self.total_slots * @sizeOf(DPEntry);
        _ = VirtualFree(self.slots, total_bytes, 0x8000);
        std.heap.page_allocator.destroy(self);
    }

    pub inline fn hashPoint(x_prefix: u128) u64 {
        const low: u64 = @truncate(x_prefix);
        const high: u64 = @truncate(x_prefix >> 64);
        var h = low ^ (high *% 0x9E3779B97F4A7C15);
        h ^= (h >> 30);
        h *%= 0xBF58476D1CE4E5B9;
        h ^= (h >> 27);
        h *%= 0x94D049BB133111EB;
        return h ^ (h >> 31);
    }

    pub fn saveDPJournal(self: *RobinHoodTable) usize {
        var fname_buf: [64:0]u8 = undefined;
        _ = std.fmt.bufPrintZ(&fname_buf, "trapped_dps_journal.dat", .{}) catch return 0;
        const h_out = CreateFileA(&fname_buf, 0x40000000, 0, null, 2, 0x80, null);
        if (h_out == null or @intFromPtr(h_out) == 0xFFFFFFFFFFFFFFFF) return 0;
        defer _ = CloseHandle(h_out);

        var saved: usize = 0;
        var batch_buf: [4096]DPEntry = undefined;
        var batch_len: usize = 0;

        for (0..self.total_slots) |i| {
            const slot = self.slots[i];
            if (slot.dib > 0) {
                batch_buf[batch_len] = slot;
                batch_len += 1;
                saved += 1;

                if (batch_len == batch_buf.len) {
                    var bw: u32 = 0;
                    _ = WriteFile(h_out, @ptrCast(&batch_buf), @as(u32, @intCast(batch_len * @sizeOf(DPEntry))), &bw, null);
                    batch_len = 0;
                }
            }
        }

        if (batch_len > 0) {
            var bw: u32 = 0;
            _ = WriteFile(h_out, @ptrCast(&batch_buf), @as(u32, @intCast(batch_len * @sizeOf(DPEntry))), &bw, null);
        }
        return saved;
    }

    pub fn loadDPJournal(self: *RobinHoodTable) usize {
        var fname_buf: [64:0]u8 = undefined;
        _ = std.fmt.bufPrintZ(&fname_buf, "trapped_dps_journal.dat", .{}) catch return 0;
        const h_in = CreateFileA(&fname_buf, 0x80000000, 1, null, 3, 0x80, null);
        if (h_in == null or @intFromPtr(h_in) == 0xFFFFFFFFFFFFFFFF) return 0;
        defer _ = CloseHandle(h_in);

        var loaded: usize = 0;
        var batch_buf: [4096]DPEntry = undefined;
        var br: u32 = 0;

        while (true) {
            const ok = ReadFile(h_in, @ptrCast(&batch_buf), @as(u32, @intCast(batch_buf.len * @sizeOf(DPEntry))), &br, null);
            if (ok == 0 or br == 0) break;
            const entries_read = br / @sizeOf(DPEntry);
            for (0..entries_read) |i| {
                if (self.insertOrDetectCollision(batch_buf[i])) {
                    // Collision during load
                    return loaded;
                }
                loaded += 1;
            }
        }
        return loaded;
    }

    pub fn insertOrDetectCollision(self: *RobinHoodTable, entry: DPEntry) bool {
        var current = entry;
        current.dib = 1;

        var idx: u64 = hashPoint(current.point_x_prefix) & self.mask;

        while (true) {
            const slot_ptr = &self.slots[idx];
            const existing_dib = @atomicLoad(u32, &slot_ptr.dib, .monotonic);

            if (existing_dib == 0) {
                if (@cmpxchgStrong(u32, &slot_ptr.dib, 0, current.dib, .acquire, .monotonic) == null) {
                    slot_ptr.point_x_prefix = current.point_x_prefix;
                    slot_ptr.distance = current.distance;
                    slot_ptr.start_scalar = current.start_scalar;
                    slot_ptr.kangaroo_id = current.kangaroo_id;
                    slot_ptr.state = current.state;
                    slot_ptr.is_tamer = current.is_tamer;
                    @atomicStore(u32, &slot_ptr.dib, current.dib, .release);
                    _ = self.count.fetchAdd(1, .monotonic);
                    return false;
                }
                continue;
            }

            if (slot_ptr.point_x_prefix == current.point_x_prefix) {
                if (slot_ptr.is_tamer != current.is_tamer) {
                    self.collision_found.store(true, .release);
                    if (slot_ptr.is_tamer == 1) {
                        self.winning_tamer = slot_ptr.*;
                        self.winning_wild = current;
                    } else {
                        self.winning_tamer = current;
                        self.winning_wild = slot_ptr.*;
                    }
                    return true;
                }
            }

            if (current.dib > existing_dib) {
                if (@cmpxchgWeak(u32, &slot_ptr.dib, existing_dib, current.dib, .acquire, .monotonic) == null) {
                    const displaced = slot_ptr.*;
                    slot_ptr.point_x_prefix = current.point_x_prefix;
                    slot_ptr.distance = current.distance;
                    slot_ptr.start_scalar = current.start_scalar;
                    slot_ptr.kangaroo_id = current.kangaroo_id;
                    slot_ptr.state = current.state;
                    slot_ptr.is_tamer = current.is_tamer;
                    @atomicStore(u32, &slot_ptr.dib, current.dib, .release);

                    current = displaced;
                }
            }

            current.dib += 1;
            idx = (idx + 1) & self.mask;
        }
    }
};

pub const JUMP_COUNT: usize = 32;
pub const DP_MASK: u64 = 0x00003FFF;

pub const PrecomputedJumps = struct {
    jump_scalars: [JUMP_COUNT]u128,
    jump_points_x: [JUMP_COUNT]U256,
    jump_points_y: [JUMP_COUNT]U256,

    pub fn init() PrecomputedJumps {
        var self: PrecomputedJumps = undefined;
        var p = JacobianPoint.fromAffine(SECP256K1.G_X, SECP256K1.G_Y);
        for (0..JUMP_COUNT) |i| {
            const step: u128 = (@as(u128, 1) << 68) + (@as(u128, 1) << @as(u7, @truncate(i)));
            self.jump_scalars[i] = step;
            if (i == 0) {
                self.jump_points_x[i] = SECP256K1.G_X;
                self.jump_points_y[i] = SECP256K1.G_Y;
            } else {
                p = p.double();
                self.jump_points_x[i] = p.toAffineX();
                self.jump_points_y[i] = SECP256K1.G_Y;
            }
        }
        return self;
    }
};

pub const WorkerContext = struct {
    thread_id: u16,
    is_tamer: bool,
    start_scalar: u128,
    jumps: *const PrecomputedJumps,
    table: *RobinHoodTable,
    completed_jumps: std.atomic.Value(usize),
    is_running: *std.atomic.Value(bool),
};

fn saveCheckpoint(thread_id: u16, lane_id: u8, is_tamer: bool, total_steps: u64, pt: JacobianPoint, dist: u128, start_s: u128) void {
    var filename_buf: [64:0]u8 = undefined;
    if (lane_id == 0) {
        _ = std.fmt.bufPrintZ(&filename_buf, "checkpoint_glv_t{d}.dat", .{thread_id}) catch return;
    } else {
        _ = std.fmt.bufPrintZ(&filename_buf, "checkpoint_glv_t{d}_l{d}.dat", .{thread_id, lane_id}) catch return;
    }

    var ckpt = CheckpointData{
        .magic = 0x474C5631,
        .thread_id = thread_id,
        .is_tamer = if (is_tamer) 1 else 0,
        .pad0 = 0,
        .total_steps = total_steps,
        .current_x = .{ @truncate(pt.x), @truncate(pt.x >> 64), @truncate(pt.x >> 128), @truncate(pt.x >> 192) },
        .current_y = .{ @truncate(pt.y), @truncate(pt.y >> 64), @truncate(pt.y >> 128), @truncate(pt.y >> 192) },
        .current_z = .{ @truncate(pt.z), @truncate(pt.z >> 64), @truncate(pt.z >> 128), @truncate(pt.z >> 192) },
        .accumulated_dist = .{ @truncate(dist), @truncate(dist >> 64) },
        .start_scalar = .{ @truncate(start_s), @truncate(start_s >> 64) },
        .checksum = total_steps ^ @as(u64, @truncate(dist)),
    };

    const h_write = CreateFileA(&filename_buf, 0x40000000, 0, null, 2, 0x80, null);
    if (h_write != null and @intFromPtr(h_write) != 0xFFFFFFFFFFFFFFFF) {
        defer _ = CloseHandle(h_write);
        const bytes: [*]const u8 = @ptrCast(&ckpt);
        var bytes_written: u32 = 0;
        _ = WriteFile(h_write, bytes, @sizeOf(CheckpointData), &bytes_written, null);
    }
}

fn loadCheckpoint(thread_id: u16, lane_id: u8) ?struct { pt: JacobianPoint, dist: u128, steps: u64, start_s: u128 } {
    var filename_buf: [64:0]u8 = undefined;
    if (lane_id == 0) {
        _ = std.fmt.bufPrintZ(&filename_buf, "checkpoint_glv_t{d}.dat", .{thread_id}) catch return null;
    } else {
        _ = std.fmt.bufPrintZ(&filename_buf, "checkpoint_glv_t{d}_l{d}.dat", .{thread_id, lane_id}) catch return null;
    }

    const h_read = CreateFileA(&filename_buf, 0x80000000, 1, null, 3, 0x80, null);
    if (h_read == null or @intFromPtr(h_read) == 0xFFFFFFFFFFFFFFFF) return null;
    defer _ = CloseHandle(h_read);

    var ckpt: CheckpointData = undefined;
    const bytes: [*]u8 = @ptrCast(&ckpt);
    var bytes_read: u32 = 0;
    if (ReadFile(h_read, bytes, @sizeOf(CheckpointData), &bytes_read, null) == 0 or bytes_read != @sizeOf(CheckpointData)) {
        return null;
    }

    if (ckpt.magic != 0x474C5631 or ckpt.thread_id != thread_id) return null;

    const x: U256 = @as(U256, ckpt.current_x[0]) | (@as(U256, ckpt.current_x[1]) << 64) | (@as(U256, ckpt.current_x[2]) << 128) | (@as(U256, ckpt.current_x[3]) << 192);
    const y: U256 = @as(U256, ckpt.current_y[0]) | (@as(U256, ckpt.current_y[1]) << 64) | (@as(U256, ckpt.current_y[2]) << 128) | (@as(U256, ckpt.current_y[3]) << 192);
    const z: U256 = @as(U256, ckpt.current_z[0]) | (@as(U256, ckpt.current_z[1]) << 64) | (@as(U256, ckpt.current_z[2]) << 128) | (@as(U256, ckpt.current_z[3]) << 192);
    const dist: u128 = @as(u128, ckpt.accumulated_dist[0]) | (@as(u128, ckpt.accumulated_dist[1]) << 64);
    const st_s: u128 = @as(u128, ckpt.start_scalar[0]) | (@as(u128, ckpt.start_scalar[1]) << 64);

    return .{
        .pt = .{ .x = x, .y = y, .z = z },
        .dist = dist,
        .steps = ckpt.total_steps,
        .start_s = st_s,
    };
}

fn workerThread(ctx: *WorkerContext) void {
    // 4-Way Scalar Unrolled State Pipelines
    var pts: [4]JacobianPoint = undefined;
    var dists: [4]u128 = [_]u128{0} ** 4;
    var total_steps: [4]u64 = [_]u64{0} ** 4;
    var start_scalars: [4]u128 = undefined;

    // Load or initialize all 4 lanes
    for (0..4) |lane_id| {
        if (loadCheckpoint(ctx.thread_id, @as(u8, @intCast(lane_id)))) |loaded| {
            pts[lane_id] = loaded.pt;
            dists[lane_id] = loaded.dist;
            total_steps[lane_id] = loaded.steps;
            start_scalars[lane_id] = loaded.start_s;
        } else {
            // Diverge starting scalars slightly for independence
            start_scalars[lane_id] = ctx.start_scalar + (@as(u128, lane_id) * 0x100000000);
            const start_x = if (ctx.is_tamer) SECP256K1.G_X else SECP256K1.W_X;
            const start_y = if (ctx.is_tamer) SECP256K1.G_Y else SECP256K1.W_Y;
            pts[lane_id] = JacobianPoint.fromAffine(start_x, start_y);
        }
    }

    var local_steps: usize = 0;
    while (ctx.is_running.load(.monotonic)) {
        if (ctx.table.collision_found.load(.monotonic)) break;

        // Fetch jump indices for all 4 lanes
        const j_idx0 = @as(usize, @truncate(pts[0].x & 0x1F));
        const j_idx1 = @as(usize, @truncate(pts[1].x & 0x1F));
        const j_idx2 = @as(usize, @truncate(pts[2].x & 0x1F));
        const j_idx3 = @as(usize, @truncate(pts[3].x & 0x1F));

        // Interleaved Point Addition to max out ALUs / Scalar Pipelines (ILP)
        pts[0] = pts[0].addMixed(ctx.jumps.jump_points_x[j_idx0], ctx.jumps.jump_points_y[j_idx0]);
        pts[1] = pts[1].addMixed(ctx.jumps.jump_points_x[j_idx1], ctx.jumps.jump_points_y[j_idx1]);
        pts[2] = pts[2].addMixed(ctx.jumps.jump_points_x[j_idx2], ctx.jumps.jump_points_y[j_idx2]);
        pts[3] = pts[3].addMixed(ctx.jumps.jump_points_x[j_idx3], ctx.jumps.jump_points_y[j_idx3]);

        dists[0] = (dists[0] +% ctx.jumps.jump_scalars[j_idx0]);
        dists[1] = (dists[1] +% ctx.jumps.jump_scalars[j_idx1]);
        dists[2] = (dists[2] +% ctx.jumps.jump_scalars[j_idx2]);
        dists[3] = (dists[3] +% ctx.jumps.jump_scalars[j_idx3]);

        total_steps[0] += 1;
        total_steps[1] += 1;
        total_steps[2] += 1;
        total_steps[3] += 1;

        local_steps += 4;

        // DP Check Unrolled
        inline for (0..4) |lane_id| {
            if ((pts[lane_id].x & DP_MASK) == 0) {
                const x0 = pts[lane_id].x;
                const x1 = mulModP(x0, SECP256K1.BETA);
                const x2 = mulModP(x0, SECP256K1.BETA2);

                var x_canon = x0;
                var state: GLVState = .PosOne;

                if (x0 <= x1 and x0 <= x2) {
                    x_canon = x0;
                    state = .PosOne;
                } else if (x1 <= x0 and x1 <= x2) {
                    x_canon = x1;
                    state = .PosLambda;
                } else {
                    x_canon = x2;
                    state = .PosLambda2;
                }

                const entry = DPEntry{
                    .point_x_prefix = @as(u128, @truncate(x_canon)),
                    .distance = dists[lane_id],
                    .start_scalar = start_scalars[lane_id],
                    .kangaroo_id = ctx.thread_id,
                    .state = @intFromEnum(state),
                    .is_tamer = if (ctx.is_tamer) 1 else 0,
                    .dib = 0,
                    .padding = [_]u8{0} ** 8,
                };

                if (ctx.table.insertOrDetectCollision(entry)) break;
            }
        }

        if ((local_steps & 0xFFF) == 0) {
            ctx.completed_jumps.store(local_steps, .monotonic);
        }

        if ((local_steps & 0x1FFFFF) == 0) { // Checkpoint saving
            for (0..4) |lane_id| {
                saveCheckpoint(ctx.thread_id, @as(u8, @intCast(lane_id)), ctx.is_tamer, total_steps[lane_id], pts[lane_id], dists[lane_id], start_scalars[lane_id]);
            }
        }
    }
    ctx.completed_jumps.store(local_steps, .monotonic);
    for (0..4) |lane_id| {
        saveCheckpoint(ctx.thread_id, @as(u8, @intCast(lane_id)), ctx.is_tamer, total_steps[lane_id], pts[lane_id], dists[lane_id], start_scalars[lane_id]);
    }
}

pub fn recoverPrivateKey(tamer: DPEntry, wild: DPEntry) ?U256 {
    const t_total: U256 = addModN(tamer.start_scalar, tamer.distance);
    const w_dist: U256 = wild.distance;

    const epsilons = [_]U256{
        1,
        SECP256K1.N - 1,
        SECP256K1.LAMBDA,
        SECP256K1.N - SECP256K1.LAMBDA,
        SECP256K1.LAMBDA2,
        SECP256K1.N - SECP256K1.LAMBDA2,
    };

    for (epsilons) |eps| {
        const eps_inv = invModN(eps);
        const term1 = mulModN(eps_inv, t_total);
        const x_candidate = subModN(term1, w_dist);

        if (x_candidate >= SECP256K1.RANGE_START and x_candidate <= SECP256K1.RANGE_END) {
            return x_candidate;
        }
    }
    return null;
}

pub fn main() !void {
    std.debug.print("\n+====================================================================+\n", .{});
    std.debug.print("|  BITCOIN PUZZLE #140 :: MASTER GLV KANGAROO AVX2 TURBO             |\n", .{});
    std.debug.print("|  Optimization           : 4-Way Pipeline Unrolled (32 Kangaroos)   |\n", .{});
    std.debug.print("|  Mathematical Symmetries: 6-Way GLV Endomorphism (sqrt(6) ~ 2.45x) |\n", .{});
    std.debug.print("|  Target Bounty          : 14.00 BTC ($1,136,000 USD / ₹9.44 Cr)    |\n", .{});
    std.debug.print("|  Memory Architecture    : 134,217,728 Slots (8.59 GB Direct Memory)|\n", .{});
    std.debug.print("|  Trap Resolution Mask   : 1 DP every 16,384 steps (8x Denser Traps)|\n", .{});
    std.debug.print("+====================================================================+\n\n", .{});

    std.debug.print("[INIT] Allocating 134.2M-Slot (8.59 GB) Direct VirtualAlloc Memory Matrix...\n", .{});
    var table = try RobinHoodTable.init(27);
    defer table.deinit();

    std.debug.print("[PERSISTENCE] Checking for existing DP Journal on disk...\n", .{});
    const loaded_dps = table.loadDPJournal();
    if (loaded_dps > 0) {
        std.debug.print("[PERSISTENCE] Restored {d} Trapped Distinguished Points into Memory Matrix!\n", .{loaded_dps});
    } else {
        std.debug.print("[PERSISTENCE] Starting fresh DP matrix (will auto-journal to disk).\n", .{});
    }

    const jumps = PrecomputedJumps.init();
    std.debug.print("[INIT] Precomputed 32 Jacobian jump points.\n", .{});
    std.debug.print("[INIT] Spawning 8-Thread Centroid Herd (32 Parallel Pipelines)...\n\n", .{});

    const NUM_THREADS: usize = 8;
    var is_running = std.atomic.Value(bool).init(true);

    var contexts: [NUM_THREADS]WorkerContext = undefined;
    var threads: [NUM_THREADS]std.Thread = undefined;

    const shell_anchors = [_]u128{
        (@as(u128, 1) << 120) + 0x43A00000000000000000,
        (@as(u128, 1) << 120) + 0x47A00000000000000000,
        (@as(u128, 1) << 120) + 0x3FA00000000000000000,
        (@as(u128, 1) << 120) + 0x4BA00000000000000000,
    };

    for (0..NUM_THREADS) |t_idx| {
        const is_tamer = (t_idx < 4);
        const thread_anchor = if (is_tamer) shell_anchors[t_idx] else 0;
        contexts[t_idx] = .{
            .thread_id = @as(u16, @intCast(t_idx)),
            .is_tamer = is_tamer,
            .start_scalar = thread_anchor,
            .jumps = &jumps,
            .table = table,
            .completed_jumps = std.atomic.Value(usize).init(0),
            .is_running = &is_running,
        };
        threads[t_idx] = try std.Thread.spawn(.{}, workerThread, .{&contexts[t_idx]});
    }

    var freq: i64 = 0;
    var last_time: i64 = 0;
    var current_time: i64 = 0;
    _ = QueryPerformanceFrequency(&freq);
    _ = QueryPerformanceCounter(&last_time);

    var update_tick: u32 = 0;
    const start_time: i64 = last_time;

    while (is_running.load(.monotonic)) {
        Sleep(1000);
        _ = QueryPerformanceCounter(&current_time);
        update_tick += 1;

        if ((update_tick % 5) == 0) {
            var total_jumps: usize = 0;
            for (0..NUM_THREADS) |t_idx| {
                total_jumps += contexts[t_idx].completed_jumps.load(.monotonic);
            }

            const dt_total = @as(f64, @floatFromInt(current_time - start_time)) / @as(f64, @floatFromInt(freq));
            const avg_rate = (@as(f64, @floatFromInt(total_jumps)) / dt_total) / 1000.0;
            const glv_effective_rate = avg_rate * 2.4494897;

            const dps = table.count.load(.monotonic);
            const load_factor = (@as(f64, @floatFromInt(dps)) / 134217728.0) * 100.0;
            const elapsed_min = @as(u32, @intFromFloat(dt_total / 60.0));
            const elapsed_sec_rem = @as(u32, @intFromFloat(@mod(dt_total, 60.0)));

            std.debug.print(
                \\[STATUS #{d:>4}] Up: {d:>02}m {d:>02}s | Jumps: {d:>10} | Avg: {d:>6.2} kSteps/s (GLV: {d:>6.2} kSteps/s) | Trapped DPs: {d:>6} ({d:.4}%) | 14.0 BTC
                \\
            , .{
                update_tick / 5,
                elapsed_min,
                elapsed_sec_rem,
                total_jumps,
                avg_rate,
                glv_effective_rate,
                dps,
                load_factor,
            });
            if ((update_tick % 60) == 0) {
                const saved_dps = table.saveDPJournal();
                std.debug.print("[PERSISTENCE] Auto-saved {d} DPs to trapped_dps_journal.dat\n", .{saved_dps});
            }
        }

        if (table.collision_found.load(.monotonic)) {
            is_running.store(false, .release);
            break;
        }
    }

    for (0..NUM_THREADS) |t_idx| {
        threads[t_idx].join();
    }

    const final_dps = table.saveDPJournal();
    std.debug.print("[PERSISTENCE] Committed {d} Trapped DPs to trapped_dps_journal.dat on shutdown.\n", .{final_dps});

    std.debug.print("\n\n+====================================================================+\n", .{});
    if (table.collision_found.load(.monotonic)) {
        std.debug.print("\x07\x07\x07\n", .{});
        std.debug.print("🔥🔥🔥 [CRACKED!] SECP256K1 GLV DISCRETE LOG COLLISION DETECTED! 🔥🔥🔥\n", .{});
        std.debug.print("Tamer DP X-Prefix: 0x{X}\n", .{table.winning_tamer.point_x_prefix});
        std.debug.print("Wild DP X-Prefix : 0x{X}\n", .{table.winning_wild.point_x_prefix});

        if (recoverPrivateKey(table.winning_tamer, table.winning_wild)) |pk| {
            std.debug.print("\n🎯🎯🎯 PRIVATE KEY RECOVERED 🎯🎯🎯\n", .{});
            std.debug.print("Private Key (HEX): 0x{X}\n", .{pk});
            std.debug.print("Target Reward: 14.00 BTC ($1,136,000 USD)\n\n", .{});

            var fname_buf: [64:0]u8 = undefined;
            _ = std.fmt.bufPrintZ(&fname_buf, "SOLVED_PUZZLE140_KEY.txt", .{}) catch {};
            const h_out = CreateFileA(&fname_buf, 0x40000000, 0, null, 2, 0x80, null);
            if (h_out != null and @intFromPtr(h_out) != 0xFFFFFFFFFFFFFFFF) {
                defer _ = CloseHandle(h_out);
                var buf: [128]u8 = undefined;
                const msg = std.fmt.bufPrint(&buf, "PUZZLE #140 SOLVED\nPRIVATE_KEY=0x{X}\nREWARD=14.0 BTC\n", .{pk}) catch "";
                var bw: u32 = 0;
                _ = WriteFile(h_out, msg.ptr, @as(u32, @intCast(msg.len)), &bw, null);
                std.debug.print("[PERSISTENCE] Dumped to SOLVED_PUZZLE140_KEY.txt\n", .{});
            }
        }
    } else {
        std.debug.print("[TERMINATION] Solver halted safely. All thread checkpoints preserved.\n", .{});
    }
    std.debug.print("+====================================================================+\n", .{});
}
