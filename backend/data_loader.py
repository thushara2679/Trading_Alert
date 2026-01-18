
import pandas as pd
import numpy as np
import os
from typing import List, Optional
from utils.validation import validate_dataframe

class DataLoader:
    """
    Handles loading and processing of historical market data.
    """
    
    REQUIRED_COLUMNS = ['Date', 'Open', 'High', 'Low', 'Close', 'Volume']
    
    def __init__(self):
        """
        Initializes the DataLoader.
        """
        pass
        
    def load_data(self, file_path: str) -> pd.DataFrame:
        """
        Loads market data from a CSV or Parquet file.
        
        Purpose:
            Reads data, validates structure, processes dates, and calculates base returns.
            
        Args:
            file_path (str): Absolute path to the data file.
            
        Returns:
            pd.DataFrame: Processed DataFrame with Date index and Log Returns.
            
        Throws:
            FileNotFoundError: If file not found.
            ValueError: If format is unsupported or columns missing.
        """
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"File not found: {file_path}")
            
        _, ext = os.path.splitext(file_path)
        ext = ext.lower()
        
        # Read Data
        if ext == '.csv':
            df = pd.read_csv(file_path)
        elif ext == '.parquet':
            df = pd.read_parquet(file_path)
        else:
            raise ValueError(f"Unsupported file format: {ext}. Use .csv or .parquet")
            
        # Validate
        self._validate_columns(df)
        
        # Process
        df = self._process_data(df)
        
        return df
        
    def _validate_columns(self, df: pd.DataFrame):
        """
        Validates presence of required columns.
        """
        # REQUIRED_COLUMNS are case-sensitive as per spec
        missing = [col for col in self.REQUIRED_COLUMNS if col not in df.columns]
        if missing:
            raise ValueError(f"Missing required columns: {missing}")
            
    def _process_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """
        Ensures proper types and adds derived columns.
        """
        # Ensure Date is datetime
        df['Date'] = pd.to_datetime(df['Date'])
        
        # Set Index
        df.set_index('Date', inplace=True)
        df.sort_index(inplace=True)
        
        # Log Returns: ln(P_t / P_{t-1})
        # Note: Zero or negative close prices will result in -inf/NaN
        with np.errstate(divide='ignore', invalid='ignore'):
            df['log_return'] = np.log(df['Close'] / df['Close'].shift(1))
        
        return df
