from tvDatafeed import TvDatafeed, Interval
import time

print("🧪 Testing tvdatafeed connectivity...")
tv = TvDatafeed()

print("\n1. Testing NASDAQ:AAPL (Benchmark)...")
try:
    df = tv.get_hist(symbol='AAPL', exchange='NASDAQ', interval=Interval.in_1_hour, n_bars=10)
    if df is not None and not df.empty:
        print(f"✅ PASSED: Received {len(df)} bars")
    else:
        print("❌ FAILED: No data for AAPL")
except Exception as e:
    print(f"❌ ERROR: {e}")

print("\n2. Testing CSELK:CCS (Target)...")
try:
    df = tv.get_hist(symbol='CCS', exchange='CSELK', interval=Interval.in_1_hour, n_bars=10)
    if df is not None and not df.empty:
        print(f"✅ PASSED: Received {len(df)} bars")
    else:
        print("❌ FAILED: No data for CCS")
except Exception as e:
    print(f"❌ ERROR: {e}")
