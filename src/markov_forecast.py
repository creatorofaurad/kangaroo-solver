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

def build_markov_trajectory_model():
    print("=" * 80)
    print("AUTOREGRESSIVE MARKOV TRAJECTORY MODEL (PUZZLES 1-70 -> FORWARD FORECAST)")
    print("=" * 80)

    # 1. Compute relative positions r_k
    r = []
    for k in range(1, 71):
        if k == 1:
            r.append(0.0)
            continue
        val = SOLVED_KEYS[k]
        r_min = 1 << (k - 1)
        r_max = (1 << k) - 1
        r.append((val - r_min) / (r_max - r_min))

    r = np.array(r)

    # 2. Fit AR(1) Model: r_{k} = c + phi * r_{k-1} + eps
    y = r[2:]  # from puzzle 3 onwards
    X = np.vstack([np.ones(len(y)), r[1:-1]]).T
    beta = np.linalg.lstsq(X, y, rcond=None)[0]
    c, phi = beta[0], beta[1]
    
    # Residual standard deviation
    residuals = y - (c + phi * r[1:-1])
    sigma_eps = np.std(residuals)

    print(f"\n[AR(1) RECURRENCE EQUATION]")
    print(f"  Formula      : r_{{k}} = {c:.4f} + {phi:.4f} * r_{{k-1}}  (± {sigma_eps:.4f})")
    print(f"  Stationary Mean : {c / (1 - phi):.4f} ({c / (1 - phi)*100:.2f}%)")

    # 3. Forecast Forward Trajectory for Unsolved Puzzles 71 to 80, and the 5 Kangaroo Puzzles (140, 145, 150, 155, 160)
    forecast_targets = [71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 140, 145, 150, 155, 160]

    # Recursive forecast
    current_k = 70
    current_r = r[70 - 1]

    forecasts = {}
    for step_k in range(71, 161):
        next_r = c + phi * current_r
        current_r = next_r
        if step_k in forecast_targets:
            forecasts[step_k] = next_r

    print("\n" + "=" * 80)
    print("PREDICTED STATISTICAL STRIKE ZONES & SEARCH TARGETS")
    print("=" * 80)
    print(f"{'PUZZLE':<8} | {'BOUNTY':<10} | {'PREDICTED RATIO':<16} | {'STRIKE WINDOW (±10%)':<22} | {'EST. START KEY (HEX)':<20}")
    print("-" * 80)

    for target_k in forecast_targets:
        pred_r = forecasts[target_k]
        low_r = max(0.0, pred_r - 0.10)
        high_r = min(1.0, pred_r + 0.10)

        # Calculate exact Hex Key Bounds
        r_min = 1 << (target_k - 1)
        r_span = (1 << target_k) - (1 << (target_k - 1))
        target_start = r_min + int(low_r * r_span)
        
        bounty = f"{target_k * 0.1:.1f} BTC"
        print(f"#{target_k:<7} | {bounty:<10} | {pred_r*100:6.2f}%          | [{low_r*100:4.1f}% - {high_r*100:4.1f}%]         | 0x{target_start:x}")

    print("=" * 80)

if __name__ == "__main__":
    build_markov_trajectory_model()
