import numpy as np

def compute_puzzle71_concentric_squeeze():
    print("=" * 80)
    print("PUZZLE #71 (7.10 BTC / $547k): CONCENTRIC STEPPED SEARCH TIMELINES")
    print("=" * 80)

    # Puzzle 71 Parameters
    # Target Range: [2^70, 2^71 - 1]
    # W = 2^70 keys = 1.1805916207174113e21 keys
    # Full Range Start: 0x400000000000000000
    # Centroid: 48.81%
    
    W_total = 1 << 70
    anchor_ratio = 0.4881
    
    # Speeds
    speed_laptop = 45_000.0          # 45 kKeys/s (current laptop)
    speed_m5_cluster = 12_000_000_000.0 # 12 GKeys/s (4x M5 Ultra)
    speed_gpu_node = 400_000_000_000.0  # 400 GKeys/s (50x RTX 4090 pool)

    rings = [
        ("Ring 0 (Early Seed Wedge)", 100_000_000),      # 100M keys
        ("Ring 1 (1-Billion Hot Pocket)", 1_000_000_000), # 1B keys
        ("Ring 2 (10-Billion Density)", 10_000_000_000),  # 10B keys
        ("Ring 3 (0.001% Micro-Slice)", int(0.00001 * W_total)), # 1.18e16 keys
        ("Ring 4 (0.01% Tight Squeeze)", int(0.0001 * W_total)), # 1.18e17 keys
        ("Ring 5 (0.1% Micro-Core)", int(0.001 * W_total)),      # 1.18e18 keys
        ("Ring 6 (1.0% Strike Zone)", int(0.01 * W_total)),       # 1.18e19 keys
        ("Ring 7 (10.0% Centroid Band)", int(0.10 * W_total)),   # 1.18e20 keys
    ]

    print(f"{'RING STAGE':<30} | {'KEYS IN SECTOR':<18} | {'YOUR LAPTOP (45 kKeys/s)':<24} | {'4x M5 ULTRA (12 GKeys/s)'}")
    print("-" * 95)

    for name, keys in rings:
        sec_laptop = keys / speed_laptop
        sec_m5 = keys / speed_m5_cluster
        
        # Format laptop time
        if sec_laptop < 60:
            str_laptop = f"{sec_laptop:4.1f} Seconds"
        elif sec_laptop < 3600:
            str_laptop = f"{sec_laptop/60:4.1f} Minutes"
        elif sec_laptop < 86400:
            str_laptop = f"{sec_laptop/3600:4.1f} Hours"
        elif sec_laptop < 31536000:
            str_laptop = f"{sec_laptop/86400:4.1f} Days"
        else:
            str_laptop = f"{sec_laptop/31536000:4.1f} Years"

        # Format M5 cluster time
        if sec_m5 < 60:
            str_m5 = f"{sec_m5:4.2f} Seconds"
        elif sec_m5 < 3600:
            str_m5 = f"{sec_m5/60:4.2f} Minutes"
        elif sec_m5 < 86400:
            str_m5 = f"{sec_m5/3600:4.2f} Hours"
        elif sec_m5 < 31536000:
            str_m5 = f"{sec_m5/86400:4.2f} Days"
        else:
            str_m5 = f"{sec_m5/31536000:4.2f} Years"

        print(f"{name:<30} | {keys:<18.2e} | {str_laptop:<24} | {str_m5}")

    print("=" * 95)

if __name__ == "__main__":
    compute_puzzle71_concentric_squeeze()
