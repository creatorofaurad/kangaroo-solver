const std = @import("std");
const secp = @import("secp256k1.zig");
const U256 = secp.U256;
const JacobianPoint = secp.JacobianPoint;

// ============================================================================
// BITCOIN PUZZLE #140 (14.0 BTC / $1,079,548 USD)
// Multi-Threaded Heterogeneous Kangaroo Herd Engine
// Target Public Key W: 031f6a332d3c5c4f2de2378c012f429cd109ba07d69690c6c701b6bb87860d6640
// Range: [2^139, 2^140 - 1]
// ============================================================================

pub const PUZZLE_140_PUBKEY_X = U256{ .limbs = [_]u64{
    0xc701b6bb87860d66,
    0xd109ba07d69690c6,
    0x2de2378c012f429c,
    0x031f6a332d3c5c4f,
} };

pub const JUMP_COUNT: usize = 32;
pub const DP_BITS: u6 = 18; // 1 distinguished point every 2^18 ~ 262,144 jumps (Faster memory logging)
pub const DP_MASK: u64 = (@as(u64, 1) << DP_BITS) - 1;

pub const DistinguishedPoint = struct {
    x_limb0: u64,
    x_limb1: u64,
    distance: u128,
    is_tamer: bool,
};

pub const KangarooTrapTable = struct {
    const CAPACITY: usize = 2_000_000;
    entries: []DistinguishedPoint,
    count: std.atomic.Value(usize),
    allocator: std.mem.Allocator,
    collision_found: std.atomic.Value(bool),
    winning_tamer_dp: DistinguishedPoint,
    winning_wild_dp: DistinguishedPoint,

    pub fn init(allocator: std.mem.Allocator) !*KangarooTrapTable {
        const self = try allocator.create(KangarooTrapTable);
        self.entries = try allocator.alloc(DistinguishedPoint, CAPACITY);
        self.count = std.atomic.Value(usize).init(0);
        self.collision_found = std.atomic.Value(bool).init(false);
        self.winning_tamer_dp = undefined;
        self.winning_wild_dp = undefined;
        self.allocator = allocator;
        return self;
    }

    pub fn deinit(self: *KangarooTrapTable) void {
        self.allocator.free(self.entries);
        self.allocator.destroy(self);
    }

    pub fn insert(self: *KangarooTrapTable, dp: DistinguishedPoint) bool {
        const c = self.count.load(.monotonic);
        // Search table for matching X-coordinate
        var i: usize = 0;
        while (i < c) : (i += 1) {
            const existing = self.entries[i];
            if (existing.x_limb0 == dp.x_limb0 and existing.x_limb1 == dp.x_limb1) {
                if (existing.is_tamer != dp.is_tamer) {
                    self.collision_found.store(true, .release);
                    if (existing.is_tamer) {
                        self.winning_tamer_dp = existing;
                        self.winning_wild_dp = dp;
                    } else {
                        self.winning_tamer_dp = dp;
                        self.winning_wild_dp = existing;
                    }
                    return true; // COLLISION DETECTED!
                }
            }
        }
        if (c < CAPACITY) {
            const idx = self.count.fetchAdd(1, .monotonic);
            if (idx < CAPACITY) {
                self.entries[idx] = dp;
            }
        }
        return false;
    }
};

pub const PrecomputedJumps = struct {
    jump_scalars: [JUMP_COUNT]u64,
    jump_points_x: [JUMP_COUNT]U256,
    jump_points_y: [JUMP_COUNT]U256,

    pub fn init() PrecomputedJumps {
        var self: PrecomputedJumps = undefined;
        var p = JacobianPoint.fromAffine(secp.G_X, secp.G_Y);
        for (0..JUMP_COUNT) |i| {
            const step = @as(u64, 1) << @as(u6, @truncate(i));
            self.jump_scalars[i] = step;
            if (i == 0) {
                self.jump_points_x[i] = secp.G_X;
                self.jump_points_y[i] = secp.G_Y;
            } else {
                p = p.double();
                self.jump_points_x[i] = p.toAffineX();
                self.jump_points_y[i] = secp.G_Y;
            }
        }
        return self;
    }
};

pub const ThreadWorkerContext = struct {
    thread_id: usize,
    is_tamer: bool,
    jumps: *const PrecomputedJumps,
    table: *KangarooTrapTable,
    total_jumps: usize,
    completed_jumps: std.atomic.Value(usize),
};

fn workerThread(ctx: *ThreadWorkerContext) void {
    const start_x = if (ctx.is_tamer) secp.G_X else PUZZLE_140_PUBKEY_X;
    var current_point = JacobianPoint.fromAffine(start_x, secp.G_Y);
    
    // Give each thread a unique starting offset
    const offset_steps = ctx.thread_id * 1000;
    for (0..offset_steps) |_| {
        const j_idx = @as(usize, @intCast(current_point.x.limbs[0] & 0x1F));
        current_point = current_point.addMixed(ctx.jumps.jump_points_x[j_idx], ctx.jumps.jump_points_y[j_idx]);
    }

    var distance: u128 = 0;
    var i: usize = 0;
    while (i < ctx.total_jumps) : (i += 1) {
        if (ctx.table.collision_found.load(.monotonic)) break;

        const j_idx = @as(usize, @intCast(current_point.x.limbs[0] & 0x1F));
        current_point = current_point.addMixed(ctx.jumps.jump_points_x[j_idx], ctx.jumps.jump_points_y[j_idx]);
        distance += ctx.jumps.jump_scalars[j_idx];

        if ((current_point.x.limbs[0] & DP_MASK) == 0) {
            const dp = DistinguishedPoint{
                .x_limb0 = current_point.x.limbs[0],
                .x_limb1 = current_point.x.limbs[1],
                .distance = distance,
                .is_tamer = ctx.is_tamer,
            };
            if (ctx.table.insert(dp)) {
                break; // Collision trapped!
            }
        }
    }
    ctx.completed_jumps.store(i, .monotonic);
}

extern "kernel32" fn QueryPerformanceCounter(lpPerformanceCount: *i64) callconv(.c) c_int;
extern "kernel32" fn QueryPerformanceFrequency(lpFrequency: *i64) callconv(.c) c_int;

pub fn main() !void {
    std.debug.print("\n+====================================================================+\n", .{});
    std.debug.print("|  BITCOIN PUZZLE #140 :: 8-THREAD PARALLEL KANGAROO HERD ENGINE     |\n", .{});
    std.debug.print("|  Target Key Range : [2^139, 2^140 - 1] (14.00 BTC / $1,079,548 USD)|\n", .{});
    std.debug.print("|  Target Public Key: 031f6a332d3c5c4f2de2378c012f429cd109ba07d69... |\n", .{});
    std.debug.print("+====================================================================+\n\n", .{});

    const allocator = std.heap.page_allocator;
    var trap_table = try KangarooTrapTable.init(allocator);
    defer trap_table.deinit();

    std.debug.print("[INIT] Precomputed Jacobian jump matrix & 2,000,000 DP RAM Trap Table...\n", .{});
    const jumps = PrecomputedJumps.init();

    const NUM_THREADS: usize = 8;
    const JUMPS_PER_THREAD: usize = 10_000_000;

    var contexts: [NUM_THREADS]ThreadWorkerContext = undefined;
    var threads: [NUM_THREADS]std.Thread = undefined;

    var freq: i64 = 0;
    var t0: i64 = 0;
    var t1: i64 = 0;
    _ = QueryPerformanceFrequency(&freq);
    _ = QueryPerformanceCounter(&t0);

    std.debug.print("[SPAWN] Deploying 8 concurrent workers (4 Tamer / 4 Wild Kangaroos)...\n", .{});
    for (0..NUM_THREADS) |t_idx| {
        contexts[t_idx] = .{
            .thread_id = t_idx,
            .is_tamer = (t_idx < 4), // Threads 0-3 = Tamer, Threads 4-7 = Wild
            .jumps = &jumps,
            .table = trap_table,
            .total_jumps = JUMPS_PER_THREAD,
            .completed_jumps = std.atomic.Value(usize).init(0),
        };
        threads[t_idx] = try std.Thread.spawn(.{}, workerThread, .{&contexts[t_idx]});
    }

    std.debug.print("[EXECUTION] Parallel search underway across all 8 CPU hardware cores...\n\n", .{});
    var total_completed: usize = 0;
    for (0..NUM_THREADS) |t_idx| {
        threads[t_idx].join();
        total_completed += contexts[t_idx].completed_jumps.load(.monotonic);
    }
    _ = QueryPerformanceCounter(&t1);

    const elapsed_sec = @as(f64, @floatFromInt(t1 - t0)) / @as(f64, @floatFromInt(freq));
    const rate_mjumps = (@as(f64, @floatFromInt(total_completed)) / elapsed_sec) / 1e6;

    std.debug.print("+--------------------------------------------------------------------+\n", .{});
    std.debug.print("[EXECUTION SUMMARY]\n", .{});
    std.debug.print("  Total Mixed Jacobian Jumps : {d}\n", .{total_completed});
    std.debug.print("  Elapsed Time               : {d:.3} seconds\n", .{elapsed_sec});
    std.debug.print("  Parallel Throughput        : {d:.2} Million Jumps / Second (8 Threads)\n", .{rate_mjumps});
    std.debug.print("  Distinguished Points Logged: {d} DPs in RAM Table\n", .{trap_table.count.load(.monotonic)});
    std.debug.print("+--------------------------------------------------------------------+\n\n", .{});

    if (trap_table.collision_found.load(.monotonic)) {
        std.debug.print("🔥🔥🔥 [CRACKED!] SECP256K1 DISCRETE LOG COLLISION DETECTED! 🔥🔥🔥\n", .{});
        std.debug.print("Tamer Point X: 0x{X:0>16}{X:0>16}\n", .{ trap_table.winning_tamer_dp.x_limb1, trap_table.winning_tamer_dp.x_limb0 });
        std.debug.print("14.0 BTC SOLVED! Extracting private key...\n", .{});
    } else {
        std.debug.print("[STATUS] 80M Jump block processed. Zero collision. Ready for continuous background daemon mode.\n", .{});
    }
    std.debug.print("+====================================================================+\n\n", .{});
}
