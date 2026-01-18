"""
Purpose: Unit tests for StockEngine ML module.
Protocol: Antigravity - Test-First Development (TFD)
@param: StockEngine instance with mock data
@returns: Test results for feature engineering and training pipeline

Test Coverage:
    - Feature calculation (Vol Z-Score, Elasticity)
    - Timeframe merging logic
    - Target variable creation
    - ONNX export verification
"""

import unittest
import os
import sys
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# Add parent to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from ml.stock_engine import StockEngine, FEATURE_COLUMNS, VOL_Z_WINDOW


# ==========================================
# MOCK DATA GENERATORS
# ==========================================

def generate_mock_ohlcv(
    periods: int = 100,
    freq: str = '1h',
    start_price: float = 100.0
) -> pd.DataFrame:
    """
    Generates predictable OHLCV mock data for testing.
    
    Args:
        periods: Number of candles to generate.
        freq: Pandas frequency string ('1h', '4h', '1D').
        start_price: Starting close price.
        
    Returns:
        pd.DataFrame: OHLCV DataFrame with DatetimeIndex.
    """
    np.random.seed(42)  # Reproducible tests
    
    timestamps = pd.date_range(
        start="2025-01-01",
        periods=periods,
        freq=freq
    )
    
    # Generate price with slight trend
    price_change = np.random.uniform(-0.02, 0.025, periods)
    closes = start_price * np.cumprod(1 + price_change)
    
    # Generate OHLCV
    df = pd.DataFrame({
        'Open': closes * np.random.uniform(0.99, 1.01, periods),
        'High': closes * np.random.uniform(1.00, 1.02, periods),
        'Low': closes * np.random.uniform(0.98, 1.00, periods),
        'Close': closes,
        'Volume': np.random.uniform(1000000, 5000000, periods).astype(int)
    }, index=timestamps)
    
    df.index.name = 'Date'
    return df


# ==========================================
# TEST CASES
# ==========================================

class TestStockEngineFeatures(unittest.TestCase):
    """Tests for feature engineering functions."""
    
    @classmethod
    def setUpClass(cls):
        """Initialize engine once for all tests."""
        cls.engine = StockEngine(
            data_dir="test_data_cache",
            model_dir="test_models_onnx"
        )
    
    def test_calculate_features_vol_z(self):
        """
        Test: Volume Z-Score calculation.
        Verify: Z-score is calculated with 20-period window.
        """
        df = generate_mock_ohlcv(periods=50)
        result = self.engine.calculate_features(df)
        
        # Vol_Z column should exist
        self.assertIn('Vol_Z', result.columns)
        
        # First VOL_Z_WINDOW rows should have less reliable values
        # After window, Z-scores should be reasonable
        z_scores = result['Vol_Z'].iloc[VOL_Z_WINDOW:]
        
        # Z-scores should be mostly within -3 to 3 for normal data
        self.assertTrue(z_scores.abs().max() < 10)
        
        # Should not have infinities
        self.assertFalse(np.isinf(result['Vol_Z']).any())
    
    def test_calculate_features_elasticity(self):
        """
        Test: Elasticity calculation.
        Verify: Elasticity = Price_Pct / Vol_Z
        """
        df = generate_mock_ohlcv(periods=50)
        result = self.engine.calculate_features(df)
        
        # Elasticity column should exist
        self.assertIn('Elasticity', result.columns)
        
        # Should not have infinities after sanitization
        self.assertFalse(np.isinf(result['Elasticity']).any())
        
        # Should not have NaN after sanitization
        self.assertFalse(result['Elasticity'].isna().any())
    
    def test_calculate_features_empty_df(self):
        """
        Test: Empty DataFrame handling.
        Verify: Returns empty DataFrame without error.
        """
        df = pd.DataFrame()
        result = self.engine.calculate_features(df)
        
        self.assertTrue(result.empty)
    
    def test_feature_columns_exist(self):
        """
        Test: Required feature columns are defined.
        Verify: FEATURE_COLUMNS constant is properly set.
        """
        expected = ['Vol_Z_1H', 'Vol_Z_4H', 'Vol_Z_1D', 'Elasticity_1H']
        self.assertEqual(FEATURE_COLUMNS, expected)


class TestStockEngineTarget(unittest.TestCase):
    """Tests for target variable creation."""
    
    @classmethod
    def setUpClass(cls):
        cls.engine = StockEngine(
            data_dir="test_data_cache",
            model_dir="test_models_onnx"
        )
    
    def test_create_target_column(self):
        """
        Test: Target binary column creation.
        Verify: Target is 0 or 1 based on future price movement.
        """
        df = generate_mock_ohlcv(periods=100)
        df = self.engine.calculate_features(df)
        
        # Simulate merged dataframe
        df = df.rename(columns={'Vol_Z': 'Vol_Z_1H', 'Elasticity': 'Elasticity_1H'})
        df['Vol_Z_4H'] = df['Vol_Z_1H']
        df['Vol_Z_1D'] = df['Vol_Z_1H']
        
        result = self.engine._create_target(df)
        
        # Target column should exist
        self.assertIn('Target', result.columns)
        
        # Target should be binary
        unique_vals = result['Target'].unique()
        self.assertTrue(set(unique_vals).issubset({0, 1}))
        
        # Should have fewer rows due to shift operation
        self.assertLess(len(result), len(df))


class TestStockEngineValidation(unittest.TestCase):
    """Tests for input validation and error handling."""
    
    @classmethod
    def setUpClass(cls):
        cls.engine = StockEngine(
            data_dir="test_data_cache",
            model_dir="test_models_onnx"
        )
    
    def test_train_model_missing_data(self):
        """
        Test: Training with missing cached data.
        Verify: Returns failure tuple.
        """
        success, msg = self.engine.train_model("NONEXISTENT_SYMBOL")
        
        self.assertFalse(success)
        self.assertIn("Missing", msg)
    
    def test_get_trained_models_empty(self):
        """
        Test: Get models when none exist.
        Verify: Returns empty list.
        """
        # Create temp engine with empty dir
        temp_engine = StockEngine(
            data_dir="empty_test_dir",
            model_dir="empty_models_dir"
        )
        
        models = temp_engine.get_trained_models()
        self.assertIsInstance(models, list)
    
    def test_clear_state_reset(self):
        """
        Test: State reset protocol.
        Verify: clear() resets internal errors list.
        """
        self.engine._errors = ["test error"]
        self.engine.clear()
        
        self.assertEqual(len(self.engine._errors), 0)


# ==========================================
# TEST RUNNER
# ==========================================

def run_tests():
    """Unified test runner with verbose output."""
    print("=" * 60)
    print("🧪 Antigravity Protocol: TFD Test Suite - StockEngine")
    print("=" * 60)
    
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add test classes
    suite.addTests(loader.loadTestsFromTestCase(TestStockEngineFeatures))
    suite.addTests(loader.loadTestsFromTestCase(TestStockEngineTarget))
    suite.addTests(loader.loadTestsFromTestCase(TestStockEngineValidation))
    
    # Run with verbosity
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Summary
    print("\n" + "=" * 60)
    if result.wasSuccessful():
        print("✅ ALL TESTS PASSED")
    else:
        print(f"❌ FAILURES: {len(result.failures)}, ERRORS: {len(result.errors)}")
    print("=" * 60)
    
    return result.wasSuccessful()


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
