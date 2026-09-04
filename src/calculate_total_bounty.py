import csv

csv_path = r"C:\Users\srija\Downloads\bitcoin-puzzle-unsolved-20260902.csv"

total_btc = 0.0
puzzle_count = 0
unsolved_puzzles = []

with open(csv_path, mode='r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        bits = int(row['bits'])
        if bits >= 72:
            btc = float(row['btc_value'])
            total_btc += btc
            puzzle_count += 1
            unsolved_puzzles.append((bits, btc, row['public_key']))

print("=" * 80)
print("TOTAL REMAINING REWARDS: PUZZLES #72 TO #160")
print("=" * 80)
print(f"Total Unsolved Puzzles (72-160) : {puzzle_count} Puzzles")
print(f"Total Bitcoin Available         : {total_btc:.2f} BTC")

# Current Bitcoin Price (~$77,100 USD / 1 USD = 94 INR)
btc_price_usd = 77100.0
usd_to_inr = 94.0

total_usd = total_btc * btc_price_usd
total_inr = total_usd * usd_to_inr
total_crores = total_inr / 10_000_000

print(f"Total USD Valuation (@ $77.1k/BTC): ${total_usd:,.2f} USD")
print(f"Total INR Valuation (@ 94 INR/USD) : INR {total_inr:,.2f}")
print(f"Total in Indian Crores            : INR {total_crores:.2f} CRORES")
print("=" * 80)
