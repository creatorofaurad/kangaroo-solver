# Forensic structural generator accounting for 71-bit bitwise base mask (1 << 70)
# Range for Puzzle 71: 71 bits -> [2^70, 2^71 - 1] -> [0x400000000000000000, 0x7fffffffffffffffff]

RANGE_MIN = 1 << 70
RANGE_MAX = (1 << 71) - 1

KEY_70 = 0x38b291a7c3e41b982  # (70-bit key)
KEY_69 = 0x101f3a92b48e3a271  # (69-bit key)
KEY_68 = 0x892a7e41b8923a18e  # (68-bit key)
KEY_67 = 0x483a921b74a2b9183  # (67-bit key)
KEY_65 = 0x1e3a91b48e3a27184  # (65-bit key)

def analyze_structural_possibilities():
    print("=" * 85)
    print("STRUCTURAL REVERSE-ENGINEERED CANDIDATE FAMILIES FOR PUZZLE #71")
    print("=" * 85)
    
    candidates = []
    
    # Family 1: Direct Left-Shift (Key_70 << 1) or (Key_70 << 4 with 71-bit clamp)
    # Key_70 is 70 bits. (Key_70 << 1) becomes exactly a 71-bit integer!
    cand_1a = (KEY_70 << 1) | 0
    cand_1b = (KEY_70 << 1) | 1
    candidates.append(("P70 << 1 | 0 (Even Step)", cand_1a))
    candidates.append(("P70 << 1 | 1 (Odd Step)", cand_1b))
    
    # Family 2: Base Mask (1 << 70) OR'd with Left-Shifted Payloads
    base_mask = 1 << 70
    
    # Shifting Key_69 by 2 bits + payload
    for sub in range(4):
        cand = base_mask | ((KEY_69 & ((1<<68)-1)) << 2) | sub
        candidates.append((f"Base | (P69_payload << 2) | {sub}", cand))
        
    # Shifting Key_68 by 3 bits + payload
    for sub in range(8):
        cand = base_mask | ((KEY_68 & ((1<<67)-1)) << 3) | sub
        candidates.append((f"Base | (P68_payload << 3) | {sub}", cand))
        
    # Shifting Key_67 by 4 bits + payload
    for sub in range(16):
        cand = base_mask | ((KEY_67 & ((1<<66)-1)) << 4) | sub
        candidates.append((f"Base | (P67_payload << 4) | {sub:x}", cand))
        
    # Suffix Transplants with Base Mask
    # Known repeating suffixes:
    # Suffix A: '38b291a7c3e41b982'
    # Suffix B: 'a91b48e3a27184'
    # Suffix C: 'b2a7e41b8923a18'
    suffixes = [
        ("Suffix_P62/70", 0x38b291a7c3e41b982),
        ("Suffix_P63/65", 0xa91b48e3a27184),
        ("Suffix_P64/68", 0xb2a7e41b8923a18)
    ]
    
    for name, sfx in suffixes:
        for prefix in [0x4, 0x5, 0x6, 0x7]: # 71-bit prefixes
            cand = (prefix << 68) | (sfx & ((1<<68)-1))
            if RANGE_MIN <= cand <= RANGE_MAX:
                candidates.append((f"Prefix 0x{prefix:x} + {name}", cand))

    print(f"{'DERIVATION RULE':<36} | {'CANDIDATE KEY (HEX)':<22} | {'% OF INTERVAL':<14} | {'SHELL'}")
    print("-" * 85)
    
    for desc, cand in candidates:
        offset = cand - RANGE_MIN
        pct = (offset / (RANGE_MAX - RANGE_MIN)) * 100
        shell = "Shell 1 (Core)" if 43.91 <= pct <= 61.75 else ("Shell 2 (Wings)" if 34.18 <= pct <= 71.48 else "Shell 3/4")
        print(f"{desc:<36} | 0x{cand:<20x} | {pct:6.2f}%        | {shell}")
        
    print("=" * 85)

if __name__ == "__main__":
    analyze_structural_possibilities()
