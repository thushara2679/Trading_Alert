"""
Data Fetcher Service - tvdatafeed Integration
Protocol: Antigravity - Standalone Mobile Module

Uses tvdatafeed library for direct TradingView data fetching.
NO API calls, NO server dependency - completely standalone.
"""

import os
import json
import time
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any

try:
    from tvDatafeed import TvDatafeed, Interval
    TVDATAFEED_AVAILABLE = True
except ImportError:
    TVDATAFEED_AVAILABLE = False
    print("⚠️ tvdatafeed not available. Install with:")
    print("pip install git+https://github.com/rongardF/tvdatafeed.git")

    print("pip install git+https://github.com/rongardF/tvdatafeed.git")

import numpy as np
import pandas as pd


# Data validity period (skip re-fetch if data is fresher than this)
DATA_VALIDITY_MINUTES = 15


class DataFetcher:
    """
    Fetches OHLCV data from TradingView using tvdatafeed.
    Calculates features for XGBoost model inference.
    Caches data locally for offline access.
    """
    
    def __init__(self, cache_dir: str = "data_cache"):
        """Initialize data fetcher with cache directory."""
        self.cache_dir = cache_dir
        os.makedirs(cache_dir, exist_ok=True)
        
        # Track last fetch time per symbol for validity check
        self.fetch_timestamps: Dict[str, datetime] = {}
        
        # Track failed symbols for targeted retry
        self.failed_symbols: List[str] = []
        
        if TVDATAFEED_AVAILABLE:
            self.tv = TvDatafeed()
        else:
            self.tv = None
    
    def is_data_valid(self, symbol: str) -> bool:
        """Check if cached data is still valid (within 15 minutes)."""
        cached = self._load_cache(symbol)
        if cached and "timestamp" in cached:
            try:
                cached_time = datetime.fromisoformat(cached["timestamp"])
                age = datetime.now() - cached_time
                if age < timedelta(minutes=DATA_VALIDITY_MINUTES):
                    return True
            except:
                pass
        return False
    
    def fetch_symbol(
        self, 
        symbol: str, 
        exchange: str = "CSELK",
        interval: str = "1h",
        n_bars: int = 50,
        force: bool = False
    ) -> Optional[Dict[str, Any]]:
        """
        Fetches live data for a symbol with retries and backoff.
        
        Args:
            symbol: Stock ticker (e.g., "CCS.N0000")
            exchange: Exchange name (default: CSELK)
            interval: Timeframe (1h, 4h, daily)
            n_bars: Number of historical bars (default: 50)
            force: Force fetch even if data is valid
            
        Returns:
            Dict with OHLCV data and features, or None on failure.
        """
        # Check data validity - skip if fresh and not forced
        if not force and self.is_data_valid(symbol):
            cached = self._load_cache(symbol)
            if cached:
                print(f"✅ {symbol}: Using cached data (updated < {DATA_VALIDITY_MINUTES} min ago)")
                return cached
        
        if not TVDATAFEED_AVAILABLE or self.tv is None:
            print("❌ tvdatafeed not available")
            return self._load_cache(symbol)
        
        # Map Interval
        int_lower = interval.lower()
        interval_map = {
            '1m': Interval.in_1_minute,
            '5m': Interval.in_5_minute,
            '15m': Interval.in_15_minute,
            '1h': Interval.in_1_hour,
            '4h': Interval.in_4_hour,
            'daily': Interval.in_daily,
            'weekly': Interval.in_weekly,
            'monthly': Interval.in_monthly,
        }
        tv_interval = interval_map.get(int_lower, Interval.in_1_hour)
            
        print(f"📡 Fetching {symbol} from {exchange} ({interval}, {n_bars} bars)...")
        
        max_retries = 3
        df = None
        
        # Retry Loop
        for attempt in range(max_retries):
            try:
                if attempt > 0:
                    print(f"  🔄 Retry {attempt + 1}/{max_retries}...")
                
                df = self.tv.get_hist(
                    symbol=symbol,
                    exchange=exchange,
                    interval=tv_interval,
                    n_bars=n_bars
                )
                
                if df is not None and not df.empty:
                    print(f"  ✅ Received {len(df)} bars")
                    # Remove from failed list if successful
                    if symbol in self.failed_symbols:
                        self.failed_symbols.remove(symbol)
                    break
                else:
                    if attempt < max_retries - 1:
                        time.sleep(1 if attempt == 0 else 2) 
                    continue
                    
            except Exception as e:
                print(f"  ❌ Error attempt {attempt+1}: {e}")
                if attempt < max_retries - 1:
                    time.sleep(1 if attempt == 0 else 2)
                    continue

        if df is None or df.empty:
            print(f"⚠️ No data for {symbol}")
            # Track failed symbol for targeted retry
            if symbol not in self.failed_symbols:
                self.failed_symbols.append(symbol)
            return self._load_cache(symbol)
            
        try:
            # Standardize columns to lowercase
            df.columns = [c.lower() for c in df.columns]
            
            # Ensure required columns exist
            required = ['open', 'high', 'low', 'close', 'volume']
            for col in required:
                if col not in df.columns:
                    df[col] = 0.0
            
            # Calculate features
            features = self._calculate_features(df)
            
            # Get latest bar
            latest = df.iloc[-1]
            
            result = {
                "symbol": symbol,
                "exchange": exchange,
                "timestamp": datetime.now().isoformat(),
                "ohlcv": {
                    "open": float(latest["open"]),
                    "high": float(latest["high"]),
                    "low": float(latest["low"]),
                    "close": float(latest["close"]),
                    "volume": float(latest["volume"]),
                },
                "features": features,
                "bars_count": len(df),
                "is_live": True,
            }
            
            # Update fetch timestamp
            self.fetch_timestamps[symbol] = datetime.now()
            
            # Save to cache
            self._save_cache(symbol, result)
            
            return result
            
        except Exception as e:
            print(f"❌ Error processing {symbol}: {e}")
            if symbol not in self.failed_symbols:
                self.failed_symbols.append(symbol)
            return self._load_cache(symbol)
    
    def _calculate_features(self, df) -> Dict[str, float]:
        """
        Calculates feature dictionary for mobile models.
        Includes multi-timeframe Z-scores (1H, 4H, 1D).
        """
        features = {}
        window = 60
        
        try:
            # Ensure DateTime Index
            if not isinstance(df.index, pd.DatetimeIndex):
                # Attempt to convert if index is strings or reset index
                df.index = pd.to_datetime(df.index)

            # --- 1H Features (Assumes input interval is 1H) ---
            # Elasticity
            df['elasticity'] = (df['high'] - df['low']) / df['close']
            features['Elasticity_1H'] = float(df['elasticity'].iloc[-1]) if not df.empty else 0.0
            
            # Vol_Z 1H
            r = df['volume'].rolling(window=window, min_periods=1)
            std = r.std().fillna(1.0)
            std = std.replace(0, 1.0) # Avoid div by zero
            df['vol_z'] = (df['volume'] - r.mean()) / std
            features['Vol_Z_1H'] = float(df['vol_z'].iloc[-1]) if not df.empty else 0.0
            
            # --- 4H Resample ---
            try:
                df_4h = df.resample('4H').agg({
                    'open': 'first', 'high': 'max', 'low': 'min', 'close': 'last', 'volume': 'sum'
                }).dropna()
                
                if not df_4h.empty:
                    r4 = df_4h['volume'].rolling(window=window, min_periods=1)
                    std4 = r4.std().fillna(1.0).replace(0, 1.0)
                    df_4h['vol_z'] = (df_4h['volume'] - r4.mean()) / std4
                    features['Vol_Z_4H'] = float(df_4h['vol_z'].iloc[-1])
                else:
                    features['Vol_Z_4H'] = 0.0
            except Exception as e:
                features['Vol_Z_4H'] = 0.0
                
            # --- 1D Resample ---
            try:
                df_1d = df.resample('1D').agg({
                    'open': 'first', 'high': 'max', 'low': 'min', 'close': 'last', 'volume': 'sum'
                }).dropna()
                
                if not df_1d.empty:
                    rd = df_1d['volume'].rolling(window=window, min_periods=1)
                    stdd = rd.std().fillna(1.0).replace(0, 1.0)
                    df_1d['vol_z'] = (df_1d['volume'] - rd.mean()) / stdd
                    features['Vol_Z_1D'] = float(df_1d['vol_z'].iloc[-1])
                else:
                    features['Vol_Z_1D'] = 0.0
            except Exception as e:
                features['Vol_Z_1D'] = 0.0
                
            # --- Time Features ---
            last_idx = df.index[-1]
            features['day_of_week'] = int(last_idx.weekday())
            features['hour_of_day'] = int(last_idx.hour)
            
            # Legacy/Fallback
            features["Vol_Z"] = features["Vol_Z_1H"]
            features["Elasticity"] = features["Elasticity_1H"]
            features["Open"] = float(df["open"].iloc[-1])
            features["High"] = float(df["high"].iloc[-1])
            features["Low"] = float(df["low"].iloc[-1])
            features["Close"] = float(df["close"].iloc[-1])
            features["Volume"] = float(df["volume"].iloc[-1])
            
            return features
            
        except Exception as e:
            print(f"Feature calc error: {e}")
            # Return safe default
            return {
                "Vol_Z_1H": 0.0, "Vol_Z_4H": 0.0, "Vol_Z_1D": 0.0,
                "Elasticity_1H": 0.0, "day_of_week": 0, "hour_of_day": 0,
                "Vol_Z": 0.0, "Elasticity": 0.0,
                "Open": 0.0, "High": 0.0, "Low": 0.0, "Close": 0.0, "Volume": 0.0
            }
    
    def _save_cache(self, symbol: str, data: Dict[str, Any]) -> None:
        """Saves fetched data to JSON cache."""
        safe_symbol = symbol.replace(".", "_")
        filepath = os.path.join(self.cache_dir, f"{safe_symbol}.json")
        with open(filepath, "w") as f:
            json.dump(data, f, indent=2)
    
    def _load_cache(self, symbol: str) -> Optional[Dict[str, Any]]:
        """Loads cached data for a symbol."""
        safe_symbol = symbol.replace(".", "_")
        filepath = os.path.join(self.cache_dir, f"{safe_symbol}.json")
        if os.path.exists(filepath):
            try:
                with open(filepath, "r") as f:
                    data = json.load(f)
                    data["is_live"] = False
                    return data
            except:
                return None
        return None
    
    def get_data(self, symbol: str, exchange: str = "CSELK", force: bool = False) -> Optional[Dict[str, Any]]:
        """
        Main entry point: Fetches data with validity check.
        
        Args:
            symbol: Stock ticker
            exchange: Exchange name
            force: Force re-fetch even if data is valid
        """
        return self.fetch_symbol(symbol, exchange, force=force)
    
    def retry_failed(self, exchange: str = "CSELK") -> Dict[str, bool]:
        """
        Retry fetching data for previously failed symbols.
        
        Returns:
            Dict mapping symbol to success status
        """
        results = {}
        for symbol in self.failed_symbols.copy():
            data = self.fetch_symbol(symbol, exchange, force=True)
            results[symbol] = data is not None
        return results
    
    def get_failed_symbols(self) -> List[str]:
        """Returns list of symbols that failed to fetch."""
        return self.failed_symbols.copy()
