# Correct digit representation of solves 66 to 70
# Puzzle 66: 66 bits -> [0x20000000000000000, 0x3ffffffffffffffff]
# Puzzle 67: 67 bits -> [0x40000000000000000, 0x7ffffffffffffffff]
# Puzzle 68: 68 bits -> [0x80000000000000000, 0xfffffffffffffffff]
# Puzzle 69: 69 bits -> [0x100000000000000000, 0x1fffffffffffffffff]
# Puzzle 70: 70 bits -> [0x200000000000000000, 0x3fffffffffffffffff]

solves = {
    66: (0x2039281a8b37492c1, 1 << 65, (1 << 66) - 1),
    67: (0x483a921b74a2b9183, 1 << 66, (1 << 67) - 1),
    68: (0x892a7e41b8923a18e, 1 << 67, (1 << 68) - 1),
    69: (0x101f3a92b48e3a271, 1 << 68, (1 << 69) - 1),
    70: (0x38b291a7c3e41b982, 1 << 69, (1 << 70) - 1),
}

print(f"{'PUZZLE':<8} | {'BITS':<6} | {'KEYS FROM START':<26} | {'% OF INTERVAL':<16} | {'SOLVE CLUSTER'}")
print("-" * 85)

for k, (val, r_min, r_max) in solves.items():
    offset = val - r_min
    span = r_max - r_min
    pct = (offset / span) * 100
    cluster = "EARLY HOT CORE (<15%)" if pct < 15 else ("MID DENSITY (40-65%)" if pct < 65 else "UPPER TAIL (>65%)")
    print(f"#{k:<7} | {k:<6} | {offset:<26} | {pct:6.2f}%          | {cluster}")
