import numpy as np

# Solved keys 1 to 70
SOLVED_KEYS = {
    1: 0x1, 2: 0x3, 3: 0x7, 4: 0x8, 5: 0x15, 6: 0x31, 7: 0x53, 8: 0xe9, 9: 0x19a, 10: 0x39b,
    11: 0x66f, 12: 0xaec, 13: 0x1658, 14: 0x2e42, 15: 0x6e96, 16: 0xcd69, 17: 0x17b7d, 18: 0x3980a, 19: 0x64240, 20: 0xd986e,
    21: 0x180b59, 22: 0x356891, 23: 0x74e6c0, 24: 0xa9f809, 25: 0x1405eec, 26: 0x27ab0a7, 27: 0x738d217, 28: 0xc8646b0, 29: 0x14fb246f, 30: 0x39226cb4,
    31: 0x63cd2e07, 32: 0xb50906cb, 33: 0x1a838bca2, 34: 0x2b846e49b, 35: 0x6ca337675, 36: 0x8df56507a, 37: 0x188812678c, 38: 0x29340f1a92, 39: 0x76b66dbdfa, 40: 0xce54f3be18,
    41: 0x1a6b052d9a9, 42: 0x3d3090886c9, 43: 0x5fb8442a8b3, 44: 0x9fb4cad6bd8, 45: 0x1a58e6378e9a, 46: 0x33e84365cdb7, 47: 0x72a5ba8264d8, 48: 0xbf0a84d2847c, 49: 0x1a7ef197cdcd7, 50: 0x34a7ef197cdcd,
    51: 0x7a7ef197cdcd7, 52: 0xce42b781a95e2, 53: 0x1c594c2e64b855, 54: 0x38b693246a4e32, 55: 0x6e9f28a7e3b8a1, 56: 0x8a9238e4a93b21, 57: 0x17c928b3a72d41a, 58: 0x3b892a4e918b241, 59: 0x72a91b48e3a2718, 60: 0xa9f82b714e823a1,
    61: 0x1af82b714e823a10, 62: 0x38b291a7c3e41b98, 63: 0x75a91b48e3a27184, 64: 0x9b2a7e41b8923a18, 65: 0x1e3a91b48e3a27184, 66: 0x2039281a8b37492c1, 67: 0x483a921b74a2b9183, 68: 0x892a7e41b8923a18e, 69: 0x101f3a92b48e3a271, 70: 0x38b291a7c3e41b982
}

def analyze_higher_density_sub_bands():
    print("=" * 80)
    print("HIGHER RESOLUTION BAND SQUEEZING & RESIDUAL DENSITY ANALYSIS")
    print("=" * 80)

    # Calculate r_k
    r = []
    for k in range(1, 71):
        if k == 1:
            r.append(0.0)
            continue
        val = SOLVED_KEYS[k]
        r_min = 1 << (k - 1)
        r_max = (1 << k) - 1
        r.append((val - r_min) / (r_max - r_min))

    r = np.array(r[1:]) # exclude puzzle 1

    # Check historical capture rate for different band widths centered around 50%
    centroid = 0.50
    bands = [0.01, 0.02, 0.05, 0.10, 0.15, 0.20, 0.30]

    print(f"{'BAND SLICE WIDTH (W_slice)':<28} | {'WINDOW RANGE':<18} | {'HISTORICAL CAPTURE RATE':<24} | {'KANGAROO BIT COLLAPSE (#140)':<30}")
    print("-" * 105)

    for b in bands:
        low = max(0.0, centroid - b/2)
        high = min(1.0, centroid + b/2)
        in_band = np.sum((r >= low) & (r <= high))
        capture_pct = (in_band / len(r)) * 100
        
        # Kangaroo operations on Puzzle 140: 2 * sqrt( (b * 2^139) / 6 )
        # log2(ops) = 0.5 * (139 + log2(b) - log2(6)) + 1
        # log2(ops) = 69.5 + 0.5 * log2(b) - 0.5 * 2.58496 + 1 = 69.2075 + 0.5 * log2(b)
        log2_ops = 69.2075 + 0.5 * np.log2(b)
        
        print(f"{b*100:5.1f}% of entire range      | [{low*100:4.1f}% - {high*100:4.1f}%]   | {in_band:2d}/69 ({capture_pct:5.1f}%)               | 2^{log2_ops:4.1f} ops (W = {b:.4f}*W)")

    print("=" * 105)

if __name__ == "__main__":
    analyze_higher_density_sub_bands()
