"""
Test Harness for Data Fetcher
Protocol: Antigravity - Test-First Development

Isolated Visual Harness for testing tvdatafeed integration.
"""

import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.data_fetcher import DataFetcher, TVDATAFEED_AVAILABLE


def test_tvdatafeed_available():
    """Test that tvdatafeed is properly installed."""
    print("🧪 Test: tvdatafeed availability")
    if TVDATAFEED_AVAILABLE:
        print("   ✅ PASSED: tvdatafeed is available")
        return True
    else:
        print("   ❌ FAILED: tvdatafeed not installed")
        print("   Run: pip install git+https://github.com/rongardF/tvdatafeed.git")
        return False


def test_data_fetcher_init():
    """Test DataFetcher initialization."""
    print("🧪 Test: DataFetcher initialization")
    try:
        fetcher = DataFetcher()
        if os.path.exists(fetcher.cache_dir):
            print("   ✅ PASSED: DataFetcher initialized, cache dir created")
            return True
        else:
            print("   ❌ FAILED: Cache directory not created")
            return False
    except Exception as e:
        print(f"   ❌ FAILED: {e}")
        return False


def test_feature_calculation():
    """Test feature calculation with mock data."""
    print("🧪 Test: Feature calculation")
    try:
        import numpy as np
        import pandas as pd
        
        # Create mock OHLCV data
        mock_data = pd.DataFrame({
            "open": np.random.uniform(100, 110, 30),
            "high": np.random.uniform(110, 120, 30),
            "low": np.random.uniform(90, 100, 30),
            "close": np.random.uniform(100, 110, 30),
            "volume": np.random.uniform(10000, 50000, 30),
        })
        
        fetcher = DataFetcher()
        features = fetcher._calculate_features(mock_data)
        
        if len(features) == 6:
            print("   ✅ PASSED: 6 features calculated")
            print(f"   Features: {[f'{f:.4f}' for f in features]}")
            return True
        else:
            print(f"   ❌ FAILED: Expected 6 features, got {len(features)}")
            return False
    except Exception as e:
        print(f"   ❌ FAILED: {e}")
        return False


def test_live_fetch():
    """Test live data fetching (requires network)."""
    print("🧪 Test: Live data fetch (AAPL from NASDAQ)")
    
    if not TVDATAFEED_AVAILABLE:
        print("   ⚠️ SKIPPED: tvdatafeed not available")
        return None
    
    try:
        fetcher = DataFetcher()
        result = fetcher.fetch_symbol("AAPL", "NASDAQ", "1h", 10)
        
        if result and result.get("features"):
            print("   ✅ PASSED: Live data fetched")
            print(f"   Symbol: {result['symbol']}")
            print(f"   Close: {result['ohlcv']['close']}")
            print(f"   Bars: {result['bars_count']}")
            return True
        else:
            print("   ❌ FAILED: No data returned")
            return False
    except Exception as e:
        print(f"   ❌ FAILED: {e}")
        return False


def run_all_tests():
    """Run all tests."""
    print("\n" + "=" * 50)
    print("📊 Data Fetcher Test Suite")
    print("=" * 50 + "\n")
    
    results = []
    results.append(("tvdatafeed available", test_tvdatafeed_available()))
    results.append(("DataFetcher init", test_data_fetcher_init()))
    results.append(("Feature calculation", test_feature_calculation()))
    results.append(("Live fetch", test_live_fetch()))
    
    print("\n" + "=" * 50)
    print("📋 Test Summary")
    print("=" * 50)
    
    passed = sum(1 for _, r in results if r is True)
    failed = sum(1 for _, r in results if r is False)
    skipped = sum(1 for _, r in results if r is None)
    
    for name, result in results:
        icon = "✅" if result is True else ("❌" if result is False else "⚠️")
        print(f"   {icon} {name}")
    
    print(f"\n   Passed: {passed}, Failed: {failed}, Skipped: {skipped}")
    print("=" * 50 + "\n")
    
    return failed == 0


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
