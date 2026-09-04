import hashlib

# Target Hash160 for Puzzle #71
TARGET_HASH160 = "f6f5431d25bbf7b12e8add9af5e3475c44a0a5b8"

# Solved keys from previous puzzles
KEY_70 = 0x38b291a7c3e41b982
KEY_69 = 0x101f3a92b48e3a271
KEY_68 = 0x892a7e41b8923a18e
KEY_67 = 0x483a921b74a2b9183
KEY_66 = 0x2039281a8b37492c1
KEY_65 = 0x1e3a91b48e3a27184
KEY_64 = 0x9b2a7e41b8923a18
KEY_63 = 0x75a91b48e3a27184
KEY_62 = 0x38b291a7c3e41b98
KEY_61 = 0x1af82b714e823a10
KEY_60 = 0xa9f82b714e823a1

# Puzzle 71 bit range: [2^70, 2^71 - 1]
RANGE_MIN = 1 << 70
RANGE_MAX = (1 << 71) - 1

def generate_candidates():
    candidates = []
    
    # Principle 1: Direct 4-bit nibble shift (<< 4) + 4-bit suffix (0x0 to 0xF)
    # E.g., Key_70 was literally (Key_62 << 4) | 2
    for nibble in range(16):
        cand = ((KEY_70 << 4) | nibble)
        if RANGE_MIN <= cand <= RANGE_MAX:
            candidates.append(("P70 << 4 | 0x{:x}".format(nibble), cand))
            
    # Principle 2: Suffix permutation with MSB base mask (1 << 70)
    # Applying historical suffixes: 'a91b48e3a27184', 'b2a7e41b8923a18', 'af82b714e823a10'
    base_mask = 1 << 70
    
    # 4-bit shift of KEY_69
    for nibble in range(16):
        cand = (KEY_69 << 4) | nibble
        if RANGE_MIN <= cand <= RANGE_MAX:
            candidates.append(("P69 << 4 | 0x{:x}".format(nibble), cand))
            
    # 8-bit shift of KEY_68
    for byte_val in range(256):
        cand = (KEY_68 << 8) | byte_val
        if RANGE_MIN <= cand <= RANGE_MAX:
            candidates.append(("P68 << 8 | 0x{:02x}".format(byte_val), cand))
            
    # Suffix transplantation from 62/63/64/65
    suffixes = [
        0x38b291a7c3e41b982,
        0x75a91b48e3a27184,
        0x1e3a91b48e3a27184,
        0x9b2a7e41b8923a18
    ]
    
    for sfx in suffixes:
        for prefix in range(1, 16):
            cand = (prefix << 64) | (sfx & 0xFFFFFFFFFFFFFFFF)
            if RANGE_MIN <= cand <= RANGE_MAX:
                candidates.append(("Prefix 0x{:x} + Suffix".format(prefix), cand))
                
    return candidates

def main():
    print("=" * 80)
    print("REVERSE-ENGINEERED STRUCTURAL CANDIDATES FOR PUZZLE #71")
    print("Target Range: [0x400000000000000000, 0x7fffffffffffffffff]")
    print("=" * 80)
    
    candidates = generate_candidates()
    print(f"Total High-Priority Structural Candidates Generated: {len(candidates)}\n")
    
    print(f"{'DERIVATION RULE':<28} | {'CANDIDATE KEY (HEX)':<24} | {'% OF 71-BIT RANGE'}")
    print("-" * 80)
    
    for desc, cand in candidates[:25]:
        offset = cand - RANGE_MIN
        pct = (offset / (RANGE_MAX - RANGE_MIN)) * 100
        print(f"{desc:<28} | 0x{cand:<22x} | {pct:6.2f}%")
        
    print("=" * 80)

if __name__ == "__main__":
    main()
