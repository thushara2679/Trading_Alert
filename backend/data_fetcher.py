
import pandas as pd
import os
import time
from tvDatafeed import TvDatafeed, Interval
from typing import Optional
from utils.validation import validate_dataframe

class TvDataFetcher:
    """
    Service to fetch historical data from TradingView using tvdatafeed.
    Matches strict specification.
    """
    
    def __init__(self, username: Optional[str] = None, password: Optional[str] = None):
        """
        Initializes the TvDatafeed connection.
        """
        if username and password:
            self.tv = TvDatafeed(username=username, password=password)
        else:
            self.tv = TvDatafeed()

    def fetch_data(self, symbol: str, exchange: str, n_bars: int = 5000, interval: str = 'daily') -> pd.DataFrame:
        """
        Fetches historical data for a symbol with retries and backoff.
        
        Args:
            symbol (str): Ticker symbol.
            exchange (str): Exchange.
            n_bars (int): Number of historical bars.
            interval (str): 'daily', 'weekly', 'monthly'.
            
        Returns:
            pd.DataFrame: Formatted DataFrame.
            
        Raises:
            RuntimeError: On timeout or persistent failure.
            ValueError: If no data found or missing columns.
        """
        # Map Interval
        int_lower = interval.lower()
        if int_lower == '1m':
            tv_interval = Interval.in_1_minute
        elif int_lower == '5m':
            tv_interval = Interval.in_5_minute
        elif int_lower == '15m':
            tv_interval = Interval.in_15_minute
        elif int_lower == '1h':
            tv_interval = Interval.in_1_hour
        elif int_lower == '4h':
            tv_interval = Interval.in_4_hour
        elif int_lower == 'weekly':
            tv_interval = Interval.in_weekly
        elif int_lower == 'monthly':
            tv_interval = Interval.in_monthly
        else:
            tv_interval = Interval.in_daily
            
        max_retries = 3
        last_error = None
        df = None
        
        print(f"📡 Querying TradingView for {symbol} on {exchange} ({interval})...")
        for attempt in range(max_retries):
            try:
                if attempt > 0:
                    print(f"  🔄 Attempt {attempt + 1}/{max_retries}...")
                
                df = self.tv.get_hist(
                    symbol=symbol,
                    exchange=exchange,
                    interval=tv_interval,
                    n_bars=n_bars
                )
                if df is not None and not df.empty:
                    print(f"  ✅ Data received: {len(df)} bars from online source.")
                    break
                else:
                    if attempt < max_retries - 1:
                        time.sleep(1 if attempt == 0 else 2) 
                    continue
            except Exception as e:
                last_error = str(e)
                if attempt < max_retries - 1:
                    time.sleep(1 if attempt == 0 else 2) # Exponential-ish backoff: 1s, then 2s
                    continue
                else:
                    if "Connection timed out" in last_error:
                        raise RuntimeError(
                            f"Connection to TradingView timed out after {max_retries} attempts. "
                            "This may be due to network issues or the exchange requiring login credentials."
                        )
                    else:
                        raise RuntimeError(f"Failed to fetch data from TradingView after {max_retries} attempts: {last_error}")
            
        if df is None or df.empty:
            raise ValueError(f"No data found for {symbol} on {exchange}.")
            
        # Standardize Columns
        required_map = {
            'open': 'Open', 'high': 'High', 'low': 'Low', 'close': 'Close', 'volume': 'Volume'
        }
        df = df.rename(columns=required_map)
        
        # Check Columns
        final_cols = ['Open', 'High', 'Low', 'Close', 'Volume']
        available_cols = [c for c in final_cols if c in df.columns]
        
        if len(available_cols) < 5:
            raise ValueError(f"Data missing required columns. Got: {df.columns.tolist()}")
             
        df = df[available_cols]
        df.index.name = 'Date'
        
        # Optional: Validate via utility if needed, but DataLoader does strict checks too.
        # We ensure standard format here.
        
        return df

    def save_to_csv(self, df: pd.DataFrame, ticker: str, directory: str = "Test_Data", merge_with_existing: bool = False) -> str:
        """
        Saves dataframe to a CSV file, optionally merging with existing data.
        
        Args:
            df (pd.DataFrame): New data.
            ticker (str): Ticker symbol.
            directory (str): Target directory.
            merge_with_existing (bool): If True, merges with existing CSV on disks.
        
        Returns:
            str: Path to the saved file.
        """
        if not os.path.exists(directory):
            os.makedirs(directory)
            
        safe_ticker = "".join([c for c in ticker if c.isalnum() or c in ('-', '_', '.')])
        path = os.path.join(directory, f"{safe_ticker}.csv")
        
        if merge_with_existing and os.path.exists(path):
            try:
                old_df = pd.read_csv(path, index_col=0, parse_dates=True)
                # Combine
                combined_df = pd.concat([old_df, df])
                # Deduplicate based on index
                combined_df = combined_df[~combined_df.index.duplicated(keep='last')]
                combined_df = combined_df.sort_index()
                df = combined_df
            except Exception:
                # If reading fails, just use the new data
                pass
                
        df.to_csv(path)
        return path
