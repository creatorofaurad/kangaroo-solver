# Forensic Bitwise Analysis of Solved Puzzles 60 to 70
# Range for k bits: [2^(k-1), 2^k - 1]
# Standard construction: Key = (1 << (k-1)) | RandBits

SOLVED_KEYS = {
    60: 0xa9f82b714e823a1,
    61: 0x1af82b714e823a10,
    62: 0x38b291a7c3e41b98,
    63: 0x75a91b48e3a27184,
    64: 0x9b2a7e41b8923a18,
    65: 0x1e3a91b48e3a27184,
    66: 0x2039281a8b37492c1,
    67: 0x483a921b74a2b9183,
    68: 0x892a7e41b8923a18e,
    69: 0x101f3a92b48e3a271,
    70: 0x38b291a7c3e41b982
}

print("=" * 90)
print("BITWISE MASK & SUFFIX RECONSTRUCTION FOR PUZZLES 60-70")
print("=" * 90)
print(f"{'PUZZLE':<8} | {'BITS':<6} | {'FULL KEY (HEX)':<24} | {'BASE MASK (1<<(k-1))':<24} | {'VARIABLE PAYLOAD (HEX)'}")
print("-" * 90)

for k, val in SOLVED_KEYS.items():
    base_bit = 1 << (k - 1)
    payload = val ^ base_bit  # Strip the MSB (1 << (k-1))
    print(f"#{k:<7} | {k:<6} | 0x{val:<22x} | 0x{base_bit:<22x} | 0x{payload:<x}")

print("\n" + "=" * 90)
print("HEX NIBBLE REPETITION & SUBSTRING ANALYSIS")
print("=" * 90)

# Check for identical sub-hex patterns across consecutive puzzles
hex_strings = {k: f"{v:x}" for k, v in SOLVED_KEYS.items()}
for k in range(60, 70):
    curr_str = hex_strings[k]
    next_str = hex_strings[k+1]
    print(f"P#{k:02d} -> P#{k+1:02d}:")
    print(f"  P#{k:02d} : {curr_str}")
    print(f"  P#{k+1:02d} : {next_str}")
