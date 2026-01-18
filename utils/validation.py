"""
Purpose: DataFrame validation utilities for Trading Alerts application.
Protocol: Antigravity - Utils Module
@param: DataFrame to validate
@returns: Validation result or raises ValueError
"""

import pandas as pd
import numpy as np
from typing import List, Optional, Tuple


# ==========================================
# CONSTANTS
# ==========================================

OHLCV_COLUMNS = ['Open', 'High', 'Low', 'Close', 'Volume']
REQUIRED_OHLCV = ['Open', 'High', 'Low', 'Close']


# ==========================================
# VALIDATION FUNCTIONS
# ==========================================

def validate_dataframe(
    df: pd.DataFrame,
    required_columns: Optional[List[str]] = None,
    check_empty: bool = True,
    check_nulls: bool = False
) -> Tuple[bool, str]:
    """
    Validates a DataFrame for required structure and data integrity.
    
    Purpose:
        Ensures DataFrames meet minimum quality standards before processing.
        
    Args:
        df (pd.DataFrame): The DataFrame to validate.
        required_columns (List[str]): Columns that must be present. 
            Defaults to OHLCV columns.
        check_empty (bool): If True, fails on empty DataFrames.
        check_nulls (bool): If True, fails if critical columns have nulls.
        
    Returns:
        Tuple[bool, str]: (is_valid, message)
        
    Raises:
        TypeError: If input is not a DataFrame.
    """
    # Type Check
    if not isinstance(df, pd.DataFrame):
        raise TypeError(f"Expected pd.DataFrame, got {type(df).__name__}")
    
    # Empty Check
    if check_empty and df.empty:
        return False, "DataFrame is empty"
    
    # Column Check
    if required_columns is None:
        required_columns = REQUIRED_OHLCV
        
    missing_cols = [col for col in required_columns if col not in df.columns]
    if missing_cols:
        return False, f"Missing required columns: {missing_cols}"
    
    # Null Check on Critical Columns
    if check_nulls:
        for col in required_columns:
            if df[col].isnull().any():
                null_count = df[col].isnull().sum()
                return False, f"Column '{col}' has {null_count} null values"
    
    return True, "Validation passed"


def validate_ohlcv_integrity(df: pd.DataFrame) -> Tuple[bool, str]:
    """
    Validates OHLCV data integrity constraints.
    
    Purpose:
        Ensures High >= Low, and Open/Close are within High/Low bounds.
        
    Args:
        df (pd.DataFrame): OHLCV DataFrame.
        
    Returns:
        Tuple[bool, str]: (is_valid, message)
    """
    # Validate basic structure first
    is_valid, msg = validate_dataframe(df, REQUIRED_OHLCV)
    if not is_valid:
        return is_valid, msg
    
    # High >= Low
    violations = df[df['High'] < df['Low']]
    if not violations.empty:
        return False, f"High < Low violation at {len(violations)} rows"
    
    # Close within range
    close_violations = df[(df['Close'] > df['High']) | (df['Close'] < df['Low'])]
    if not close_violations.empty:
        return False, f"Close outside High/Low range at {len(close_violations)} rows"
    
    # Open within range
    open_violations = df[(df['Open'] > df['High']) | (df['Open'] < df['Low'])]
    if not open_violations.empty:
        return False, f"Open outside High/Low range at {len(open_violations)} rows"
    
    return True, "OHLCV integrity validated"


def sanitize_dataframe(df: pd.DataFrame, fill_method: str = 'ffill') -> pd.DataFrame:
    """
    Sanitizes DataFrame by handling infinities and nulls.
    
    Purpose:
        Prepares data for ML processing by removing problematic values.
        
    Args:
        df (pd.DataFrame): Input DataFrame.
        fill_method (str): Method to fill nulls ('ffill', 'bfill', 'zero').
        
    Returns:
        pd.DataFrame: Sanitized DataFrame.
    """
    df = df.copy()
    
    # Replace infinities with NaN
    df = df.replace([np.inf, -np.inf], np.nan)
    
    # Fill NaN values
    if fill_method == 'ffill':
        df = df.ffill()
    elif fill_method == 'bfill':
        df = df.bfill()
    elif fill_method == 'zero':
        df = df.fillna(0)
    
    # Final cleanup - any remaining NaN to 0
    df = df.fillna(0)
    
    return df
