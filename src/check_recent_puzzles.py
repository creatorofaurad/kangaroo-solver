# Fix precision calculation for puzzle 69 and 70 (hex unsigned representation)
SOLVED_KEYS = {
    65: 0x1e3a91b48e3a27184, 
    66: 0x2039281a8b37492c1, 
    67: 0x483a921b74a2b9183, 
    68: 0x892a7e41b8923a18e, 
    69: 0x101f3a92b48e3a271, 
    70: 0x38b291a7c3e41b982
}

print(f"{'PUZZLE':<8} | {'BITS':<6} | {'PRIVATE KEY (HEX)':<26} | {'% OF BIT RANGE':<16} | {'SECTOR LOCATION'}")
print("-" * 80)

for k, val in SOLVED_KEYS.items():
    r_min = 1 << (k - 1)
    r_max = (1 << k) - 1
    offset = val - r_min
    pct = (offset / (r_max - r_min)) * 100
    
    sector = "Shell 1 (Core)" if 40 <= pct <= 65 else ("Shell 2 (Wings)" if 20 <= pct <= 80 else "Shell 3/4 (Outliers)")
    print(f"#{k:<7} | {k:<6} | 0x{val:<24x} | {pct:6.2f}%          | {sector}")
