# Real-Time Benchmark vs Theoretical Baseline Analysis
actual_speed = 51000.0  # ~51 kKeys/s sustained
theoretical_speed = 34000.0 # ~34 kKeys/s before L1 tuning

speedup_factor = actual_speed / theoretical_speed

daily_keys_actual = actual_speed * 86400
daily_keys_old = theoretical_speed * 86400

print("=" * 80)
print("REAL-TIME HARDWARE EFFICIENCY BENCHMARK")
print("=" * 80)
print(f"Old Baseline Speed        : {theoretical_speed/1e3:.2f} kKeys/s ({daily_keys_old/1e9:.2f} Billion keys/day)")
print(f"Current Sustained Speed   : {actual_speed/1e3:.2f} kKeys/s ({daily_keys_actual/1e9:.2f} Billion keys/day)")
print(f"Hardware Speedup Factor   : +{((speedup_factor - 1) * 100):.1f}% FASTER (+{speedup_factor:.2f}x)")
print("=" * 80)

# Time to hit specific key milestones at 51 kKeys/s
milestones = [
    ("1 Billion Keys", 1_000_000_000),
    ("2 Billion Keys", 2_000_000_000),
    ("5 Billion Keys", 5_000_000_000),
    ("10 Billion Keys (Full S1 Hot Pocket)", 10_000_000_000),
    ("25 Billion Keys", 25_000_000_000),
]

print(f"{'KEY MILESTONE':<38} | {'EXACT TIME AT CURRENT 51 kKeys/s'}")
print("-" * 75)

for name, keys in milestones:
    hours = keys / (actual_speed * 3600)
    if hours < 24:
        str_time = f"{hours:.2f} Hours"
    else:
        str_time = f"{hours/24:.2f} Days ({hours:.1f} Hours)"
    print(f"{name:<38} | {str_time}")

print("=" * 80)
