const std = @import("std");
const math = std.math;

// ============================================================================
// SECP256K1 BARE-SILICON ARITHMETIC ENGINE
// Field: p = 2^256 - 2^32 - 977 (0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F)
// Curve: y^2 = x^3 + 7
// ============================================================================

pub const U256 = struct {
    limbs: [4]u64,

    pub const ZERO = U256{ .limbs = [_]u64{ 0, 0, 0, 0 } };
    pub const ONE = U256{ .limbs = [_]u64{ 1, 0, 0, 0 } };
    pub const P = U256{ .limbs = [_]u64{ 0xFFFFFFFEFFFFFC2F, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF, 0xFFFFFFFFFFFFFFFF } };

    pub fn fromU64(val: u64) U256 {
        return .{ .limbs = [_]u64{ val, 0, 0, 0 } };
    }

    pub fn isZero(self: U256) bool {
        return (self.limbs[0] | self.limbs[1] | self.limbs[2] | self.limbs[3]) == 0;
    }

    pub fn eq(a: U256, b: U256) bool {
        return (a.limbs[0] == b.limbs[0]) and (a.limbs[1] == b.limbs[1]) and (a.limbs[2] == b.limbs[2]) and (a.limbs[3] == b.limbs[3]);
    }

    pub fn addModP(a: U256, b: U256) U256 {
        var res: [4]u64 = undefined;
        var carry: u64 = 0;

        inline for (0..4) |i| {
            const sum1 = @addWithOverflow(a.limbs[i], b.limbs[i]);
            const sum2 = @addWithOverflow(sum1[0], carry);
            res[i] = sum2[0];
            carry = sum1[1] | sum2[1];
        }

        // Fast reduction modulo secp256k1 P
        const out = U256{ .limbs = res };
        if (carry > 0 or out.gte(P)) {
            return out.subNoMod(P);
        }
        return out;
    }

    pub fn subModP(a: U256, b: U256) U256 {
        if (a.gte(b)) {
            return a.subNoMod(b);
        } else {
            const temp = a.addNoMod(P);
            return temp.subNoMod(b);
        }
    }

    pub fn mulModP(a: U256, b: U256) U256 {
        // High-speed 256x256 -> 512 bit multiplication
        var r: [8]u64 = [_]u64{0} ** 8;

        inline for (0..4) |i| {
            var carry: u64 = 0;
            inline for (0..4) |j| {
                const prod = @as(u128, a.limbs[i]) * @as(u128, b.limbs[j]);
                const cur = @as(u128, r[i + j]) + prod + @as(u128, carry);
                r[i + j] = @as(u64, @truncate(cur));
                carry = @as(u64, @truncate(cur >> 64));
            }
            r[i + 4] = carry;
        }

        // Pseudo-Mersenne Secp256k1 reduction: 2^256 = 2^32 + 977 (0x1000003D1)
        const C: u64 = 0x1000003D1;
        var low = U256{ .limbs = [_]u64{ r[0], r[1], r[2], r[3] } };

        inline for (4..8) |i| {
            const high_limb = r[i];
            if (high_limb > 0) {
                const shift_pos = (i - 4);
                // high_limb * C
                const prod = @as(u128, high_limb) * @as(u128, C);
                var add_val = U256.ZERO;
                if (shift_pos < 4) {
                    add_val.limbs[shift_pos] = @as(u64, @truncate(prod));
                    if (shift_pos + 1 < 4) {
                        add_val.limbs[shift_pos + 1] = @as(u64, @truncate(prod >> 64));
                    }
                }
                low = low.addModP(add_val);
            }
        }

        while (low.gte(P)) {
            low = low.subNoMod(P);
        }
        return low;
    }

    pub fn sqrModP(a: U256) U256 {
        return a.mulModP(a);
    }

    pub fn gte(a: U256, b: U256) bool {
        var i: isize = 3;
        while (i >= 0) : (i -= 1) {
            const idx = @as(usize, @intCast(i));
            if (a.limbs[idx] > b.limbs[idx]) return true;
            if (a.limbs[idx] < b.limbs[idx]) return false;
        }
        return true;
    }

    fn subNoMod(a: U256, b: U256) U256 {
        var res: [4]u64 = undefined;
        var borrow: u64 = 0;
        inline for (0..4) |i| {
            const diff1 = @subWithOverflow(a.limbs[i], b.limbs[i]);
            const diff2 = @subWithOverflow(diff1[0], borrow);
            res[i] = diff2[0];
            borrow = diff1[1] | diff2[1];
        }
        return .{ .limbs = res };
    }

    fn addNoMod(a: U256, b: U256) U256 {
        var res: [4]u64 = undefined;
        var carry: u64 = 0;
        inline for (0..4) |i| {
            const s1 = @addWithOverflow(a.limbs[i], b.limbs[i]);
            const s2 = @addWithOverflow(s1[0], carry);
            res[i] = s2[0];
            carry = s1[1] | s2[1];
        }
        return .{ .limbs = res };
    }
};

// Jacobian Point (X : Y : Z) where x = X/Z^2, y = Y/Z^3
pub const JacobianPoint = struct {
    x: U256,
    y: U256,
    z: U256,

    pub const INFINITY = JacobianPoint{
        .x = U256.ZERO,
        .y = U256.ONE,
        .z = U256.ZERO,
    };

    pub fn fromAffine(x: U256, y: U256) JacobianPoint {
        return .{
            .x = x,
            .y = y,
            .z = U256.ONE,
        };
    }

    // Fast Point Addition: Jacobian + Affine -> Jacobian (7 Muls + 4 Sqrs)
    pub fn addMixed(self: JacobianPoint, aff_x: U256, aff_y: U256) JacobianPoint {
        if (self.z.isZero()) {
            return JacobianPoint.fromAffine(aff_x, aff_y);
        }

        const z1z1 = self.z.sqrModP();
        const u_2 = aff_x.mulModP(z1z1);
        const s2 = aff_y.mulModP(self.z).mulModP(z1z1);

        if (self.x.eq(u_2)) {
            if (self.y.eq(s2)) {
                return self.double();
            }
            return JacobianPoint.INFINITY;
        }

        const h = u_2.subModP(self.x);
        const hh = h.sqrModP();
        const i = hh.addModP(hh).addModP(hh).addModP(hh); // 4 * HH
        const j = h.mulModP(i);
        const r = s2.subModP(self.y).addModP(s2.subModP(self.y)); // 2 * (S2 - Y1)
        const v = self.x.mulModP(i);

        const r_sq = r.sqrModP();
        const j_sub = r_sq.subModP(j);
        const v2 = v.addModP(v);
        const x3 = j_sub.subModP(v2);

        const v_sub_x3 = v.subModP(x3);
        const y1_2 = self.y.addModP(self.y);
        const y1_2_j = y1_2.mulModP(j);
        const y3 = r.mulModP(v_sub_x3).subModP(y1_2_j);

        const z1_add_h = self.z.addModP(h);
        const z3_sq = z1_add_h.sqrModP().subModP(z1z1).subModP(hh);

        return .{
            .x = x3,
            .y = y3,
            .z = z3_sq,
        };
    }

    // Fast Point Doubling (4 Muls + 4 Sqrs)
    pub fn double(self: JacobianPoint) JacobianPoint {
        if (self.z.isZero() or self.y.isZero()) {
            return JacobianPoint.INFINITY;
        }

        const a = self.x.sqrModP();
        const b = self.y.sqrModP();
        const c = b.sqrModP();

        const x1_add_b = self.x.addModP(b);
        const d_temp = x1_add_b.sqrModP().subModP(a).subModP(c);
        const d = d_temp.addModP(d_temp); // 2 * D_temp

        const e = a.addModP(a).addModP(a); // 3 * A
        const e_sq = e.sqrModP();

        const x3 = e_sq.subModP(d.addModP(d));

        const eight_c = c.addModP(c).addModP(c.addModP(c));
        const sixteen_c = eight_c.addModP(eight_c);
        const y3 = e.mulModP(d.subModP(x3)).subModP(sixteen_c);

        const z3 = self.y.mulModP(self.z).addModP(self.y.mulModP(self.z)); // 2 * Y1 * Z1

        return .{
            .x = x3,
            .y = y3,
            .z = z3,
        };
    }

    pub fn toAffineX(self: JacobianPoint) U256 {
        if (self.z.isZero()) return U256.ZERO;
        // Invert Z
        var z_inv = self.z;
        // Fermat's Little Theorem: Z^(P-2) mod P
        var exp = U256.P.subNoMod(U256.fromU64(2));
        var base = self.z;
        var res = U256.ONE;

        while (!exp.isZero()) {
            if ((exp.limbs[0] & 1) == 1) {
                res = res.mulModP(base);
            }
            base = base.sqrModP();
            // exp >>= 1
            var carry: u64 = 0;
            var i: isize = 3;
            while (i >= 0) : (i -= 1) {
                const idx = @as(usize, @intCast(i));
                const next_carry = exp.limbs[idx] & 1;
                exp.limbs[idx] = (exp.limbs[idx] >> 1) | (carry << 63);
                carry = next_carry;
            }
        }
        z_inv = res;
        const z_inv2 = z_inv.sqrModP();
        return self.x.mulModP(z_inv2);
    }
};

// secp256k1 Generator Point G
pub const G_X = U256{ .limbs = [_]u64{ 0x59F2815B16F81798, 0x029BFCDB2DCE28D9, 0x55A06295CE870B07, 0x79BE667EF9DCBBAC } };
pub const G_Y = U256{ .limbs = [_]u64{ 0x9C47D08FFB10D4B8, 0xFD17B448A6855419, 0x5DA4FBFC0E1108A8, 0x483ADA7726A3C465 } };
