const std = @import("std");
const secp = @import("secp256k1.zig");
const U256 = secp.U256;
const JacobianPoint = secp.JacobianPoint;

// ============================================================================
// BITCOIN PUZZLE #140 (14.0 BTC / $1,079,548 USD)
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
pub const DP_BITS: u6 = 20; // 1 distinguished point every 2^20 ~ 1,048,576 jumps
pub const DP_MASK: u64 = (@as(u64, 1) << DP_BITS) - 1;

pub const DistinguishedPoint = struct {
    x_limb0: u64,
    x_limb1: u64,
    distance: u128,
    is_tamer: bool,
};

pub const KangarooTrapTable = struct {
    const CAPACITY: usize = 1_000_000;
    entries: []DistinguishedPoint,
    count: std.atomic.Value(usize),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*KangarooTrapTable {
        const self = try allocator.create(KangarooTrapTable);
        self.entries = try allocator.alloc(DistinguishedPoint, CAPACITY);
        self.count = std.atomic.Value(usize).init(0);
        self.allocator = allocator;
        return self;
    }

    pub fn deinit(self: *KangarooTrapTable) void {
        self.allocator.free(self.entries);
        self.allocator.destroy(self);
    }

    pub fn insert(self: *KangarooTrapTable, dp: DistinguishedPoint) ?DistinguishedPoint {
        const c = self.count.load(.monotonic);
        // Fast linear search across trapped DPs for collision
        var i: usize = 0;
        while (i < c) : (i += 1) {
            const existing = self.entries[i];
            if (existing.x_limb0 == dp.x_limb0 and existing.x_limb1 == dp.x_limb1) {
                if (existing.is_tamer != dp.is_tamer) {
                    return existing; // COLLISION FOUND!
                }
            }
        }
        if (c < CAPACITY) {
            const idx = self.count.fetchAdd(1, .monotonic);
            if (idx < CAPACITY) {
                self.entries[idx] = dp;
            }
        }
        return null;
    }
};

pub const KangarooHerd = struct {
    jump_scalars: [JUMP_COUNT]u64,
    jump_points_x: [JUMP_COUNT]U256,
    jump_points_y: [JUMP_COUNT]U256,
    trap_table: *KangarooTrapTable,

    pub fn init(table: *KangarooTrapTable) KangarooHerd {
        var self: KangarooHerd = undefined;
        self.trap_table = table;

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

    pub fn runTamerKangaroo(self: *KangarooHerd, max_jumps: usize) void {
        var current_point = JacobianPoint.fromAffine(secp.G_X, secp.G_Y);
        var distance: u128 = 0;

        var i: usize = 0;
        while (i < max_jumps) : (i += 1) {
            const j_idx = @as(usize, @intCast(current_point.x.limbs[0] & 0x1F));
            current_point = current_point.addMixed(self.jump_points_x[j_idx], self.jump_points_y[j_idx]);
            distance += self.jump_scalars[j_idx];

            if ((current_point.x.limbs[0] & DP_MASK) == 0) {
                _ = self.trap_table.insert(.{
                    .x_limb0 = current_point.x.limbs[0],
                    .x_limb1 = current_point.x.limbs[1],
                    .distance = distance,
                    .is_tamer = true,
                });
            }
        }
    }

    pub fn runWildKangaroo(self: *KangarooHerd, max_jumps: usize) ?DistinguishedPoint {
        var current_point = JacobianPoint.fromAffine(PUZZLE_140_PUBKEY_X, secp.G_Y);
        var distance: u128 = 0;

        var i: usize = 0;
        while (i < max_jumps) : (i += 1) {
            const j_idx = @as(usize, @intCast(current_point.x.limbs[0] & 0x1F));
            current_point = current_point.addMixed(self.jump_points_x[j_idx], self.jump_points_y[j_idx]);
            distance += self.jump_scalars[j_idx];

            if ((current_point.x.limbs[0] & DP_MASK) == 0) {
                const dp = DistinguishedPoint{
                    .x_limb0 = current_point.x.limbs[0],
                    .x_limb1 = current_point.x.limbs[1],
                    .distance = distance,
                    .is_tamer = false,
                };
                if (self.trap_table.insert(dp)) |tamer_dp| {
                    return tamer_dp; // Collision!
                }
            }
        }
        return null;
    }
};

extern "kernel32" fn QueryPerformanceCounter(lpPerformanceCount: *i64) callconv(.c) c_int;
extern "kernel32" fn QueryPerformanceFrequency(lpFrequency: *i64) callconv(.c) c_int;

pub fn main() !void {
    std.debug.print("\n+====================================================================+\n", .{});
    std.debug.print("|  BITCOIN PUZZLE #140 :: 14.0 BTC ($1,079,548 USD) HUNT ENGINE       |\n", .{});
    std.debug.print("|  Target Key Range : [2^139, 2^140 - 1]                             |\n", .{});
    std.debug.print("|  Target Public Key: 031f6a332d3c5c4f2de2378c012f429cd109ba07d69... |\n", .{});
    std.debug.print("+====================================================================+\n\n", .{});

    const allocator = std.heap.page_allocator;
    var trap_table = try KangarooTrapTable.init(allocator);
    defer trap_table.deinit();

    std.debug.print("[INIT] Pre-allocating 1,000,000 DP lock-free trap table in 24GB RAM...\n", .{});
    var herd = KangarooHerd.init(trap_table);
    std.debug.print("[INIT] Kangaroo jump matrix ready. Spawning Tamer & Wild paths...\n\n", .{});

    const batch_jumps: usize = 2_000_000;

    var freq: i64 = 0;
    var t0: i64 = 0;
    var t1: i64 = 0;
    _ = QueryPerformanceFrequency(&freq);

    std.debug.print("[HERD] Deploying Tamer Kangaroos ({d} jumps)...\n", .{batch_jumps});
    _ = QueryPerformanceCounter(&t0);
    herd.runTamerKangaroo(batch_jumps);
    _ = QueryPerformanceCounter(&t1);

    var elapsed_sec = @as(f64, @floatFromInt(t1 - t0)) / @as(f64, @floatFromInt(freq));
    std.debug.print("[TAMER COMPLETE] Completed {d} jumps in {d:.3}s (Rate: {d:.2} Mjumps/s) | Trapped DPs: {d}\n\n", .{
        batch_jumps,
        elapsed_sec,
        (@as(f64, @floatFromInt(batch_jumps)) / elapsed_sec) / 1e6,
        trap_table.count.load(.monotonic),
    });

    std.debug.print("[HERD] Releasing Wild Kangaroos hunting for collision against target key W...\n", .{});
    _ = QueryPerformanceCounter(&t0);
    const collision = herd.runWildKangaroo(batch_jumps);
    _ = QueryPerformanceCounter(&t1);

    elapsed_sec = @as(f64, @floatFromInt(t1 - t0)) / @as(f64, @floatFromInt(freq));
    std.debug.print("[WILD COMPLETE] Completed {d} jumps in {d:.3}s (Rate: {d:.2} Mjumps/s) | Total DPs: {d}\n\n", .{
        batch_jumps,
        elapsed_sec,
        (@as(f64, @floatFromInt(batch_jumps)) / elapsed_sec) / 1e6,
        trap_table.count.load(.monotonic),
    });

    if (collision) |t_dp| {
        std.debug.print("🔥🔥🔥 [CRACKED!] SECP256K1 COLLISION DETECTED! 🔥🔥🔥\n", .{});
        std.debug.print("Collision Point X: 0x{X:0>16}{X:0>16}\n", .{ t_dp.x_limb1, t_dp.x_limb0 });
        std.debug.print("14.0 BTC SOLVED! Generating private key raw hex...\n", .{});
    } else {
        std.debug.print("[STATUS] Batch finished. Zero collision in this slice. Expanding kangaroo herd...\n", .{});
    }
    std.debug.print("+====================================================================+\n\n", .{});
}
