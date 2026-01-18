"""
Purpose: Unified Test Runner for Stock Trainer Application.
Protocol: Antigravity - TFD Integration Gate
@returns: Overall test pass/fail status

Runs all test modules and reports unified results.
Integration into main branch only permitted if test_pass_rate == 100%
"""

import unittest
import sys
import os

# Add parent to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


# ==========================================
# TEST DISCOVERY AND EXECUTION
# ==========================================

def run_all_tests() -> bool:
    """
    Discovers and runs all tests in Test_py directory.
    
    Returns:
        bool: True if all tests pass, False otherwise.
    """
    print("=" * 70)
    print("💎 Antigravity Protocol - Unified Test Runner")
    print("=" * 70)
    print()
    
    # Get test directory
    test_dir = os.path.dirname(os.path.abspath(__file__))
    
    # Discover tests
    loader = unittest.TestLoader()
    suite = loader.discover(
        start_dir=test_dir,
        pattern="test_*.py",
        top_level_dir=os.path.dirname(test_dir)
    )
    
    # Count tests
    test_count = suite.countTestCases()
    print(f"📋 Discovered {test_count} tests\n")
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Calculate pass rate
    total = result.testsRun
    failures = len(result.failures)
    errors = len(result.errors)
    passed = total - failures - errors
    
    if total > 0:
        pass_rate = (passed / total) * 100
    else:
        pass_rate = 0
    
    # Print Summary
    print()
    print("=" * 70)
    print("📊 TEST SUMMARY")
    print("=" * 70)
    print(f"  Total:    {total}")
    print(f"  Passed:   {passed}")
    print(f"  Failed:   {failures}")
    print(f"  Errors:   {errors}")
    print(f"  Pass Rate: {pass_rate:.1f}%")
    print()
    
    # Integration Gate Check
    if pass_rate == 100.0:
        print("✅ INTEGRATION GATE: PASSED")
        print("   All tests passed. Ready for integration.")
    else:
        print("❌ INTEGRATION GATE: BLOCKED")
        print("   Tests must pass at 100% before integration.")
    
    print("=" * 70)
    
    return result.wasSuccessful()


# ==========================================
# ENTRY POINT
# ==========================================

if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
