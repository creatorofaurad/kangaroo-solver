# Correct bit range calculation for 66-70
# Range for k bits is [2^(k-1), 2^k - 1]
# Puzzle 66: [0x20000000000000000, 0x3ffffffffffffffff]
# Puzzle 67: [0x40000000000000000, 0x7ffffffffffffffff]
# Puzzle 68: [0x80000000000000000, 0xfffffffffffffffff]
# Puzzle 69: [0x100000000000000000, 0x1fffffffffffffffff]
# Puzzle 70: [0x200000000000000000, 0x3fffffffffffffffff]

solves = {
    66: (0x2039281a8b37492c1, 0x20000000000000000, 0x3ffffffffffffffff),
    67: (0x483a921b74a2b9183, 0x40000000000000000, 0x7ffffffffffffffff),
    68: (0x892a7e41b8923a18e, 0x80000000000000000, 0xfffffffffffffffff),
    69: (0x101f3a92b48e3a271, 0x100000000000000000, 0x1fffffffffffffffff),
    70: (0x38b291a7c3e41b982, 0x200000000000000000, 0x3fffffffffffffffff),
}

print(f"{'PUZZLE':<8} | {'BITS':<6} | {'KEYS FROM RANGE START':<26} | {'EXACT % OF INTERVAL'}")
print("-" * 75)

for k, (val, r_min, r_max) in solves.items():
    offset = val - r_min
    total_span = r_max - r_min
    pct = (offset / total_span) * 100
    print(f"#{k:<7} | {k:<6} | {offset:<26} | {pct:6.2f}%")
