"""
Purpose: Core ML Engine for Stock Training and ONNX Conversion.
Protocol: Antigravity - ML Module
@param: Stock symbol, exchange, and market data
@returns: Trained XGBoost models exported as JSON

Features:
    - Volume Z-Score (20-period rolling)
    - Price Elasticity (Price Change / Volume Z-Score)
    - Multi-timeframe feature merging (1D, 4H, 1H)
"""

import os
import sys
import pandas as pd
import numpy as np
from typing import Tuple, Optional, List, Dict, Any
from datetime import datetime

# Add parent to path for backend imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    import json
    import shutil
    import xgboost as xgb
    HAS_ML_DEPS = True
except ImportError:
    HAS_ML_DEPS = False
    print("⚠️ ML dependencies not installed.")


# ==========================================
# CONSTANTS
# ==========================================

DATA_DIR = "stock_data_cache"
MODEL_DIR = "trained_models_onnx"  # Keep dir name for compatibility or rename? Keep.
VOL_Z_WINDOW = 20

FEATURE_COLUMNS = [
    'Vol_Z_1H', 'Vol_Z_4H', 'Vol_Z_1D', 
    'Elasticity_1H', 'day_of_week', 'hour_of_day'
]

TARGETS = {
    '4H': {'col': 'T_4H', 'thresh': 0.015, 'horizon': 4},
    '2D': {'col': 'T_2D', 'thresh': 0.030, 'horizon': 14},
    '5D': {'col': 'T_5D', 'thresh': 0.050, 'horizon': 35}
}


# ==========================================
# STOCK ENGINE CLASS
# ==========================================

class StockEngine:
    """Core engine for stock data processing, ML training, and Export."""
    
    def __init__(self, data_dir: str = DATA_DIR, model_dir: str = MODEL_DIR):
        self.data_dir = data_dir
        self.model_dir = model_dir
        self._errors: List[str] = []
        os.makedirs(self.data_dir, exist_ok=True)
        os.makedirs(self.model_dir, exist_ok=True)
        self.username, self.password = None, None
        self._validate_dependencies()
        self.FEATURES = FEATURE_COLUMNS
    
    def set_credentials(self, username: Optional[str], password: Optional[str]) -> None:
        self.username = username
        self.password = password
    
    def _validate_dependencies(self) -> None:
        if not HAS_ML_DEPS: self._errors.append("Missing ML dependencies")
    
    def fetch_data(self, symbol: str, exchange: str) -> Tuple[bool, str]:
        try:
            from backend.data_fetcher import TvDataFetcher
            fetcher = TvDataFetcher(username=self.username, password=self.password)
            
            configs = [
                ('1D', 'daily', 1000),
                ('4H', '4h', 2000),
                ('1H', '1h', 4000)
            ]
            
            for tf_name, interval, max_bars in configs:
                csv_path = os.path.join(self.data_dir, f"{symbol}_{tf_name}.csv")
                
                # Default: Fetch full history if no cache
                fetch_bars = max_bars
                existing_df = None
                
                if os.path.exists(csv_path):
                    try:
                        existing_df = pd.read_csv(csv_path, index_col=0, parse_dates=True)
                        if not existing_df.empty:
                            last_date = existing_df.index[-1]
                            # Calculate missing bars
                            delta = datetime.now() - last_date
                            hours_missing = delta.total_seconds() / 3600
                            
                            if tf_name == '1D': est_bars = delta.days
                            elif tf_name == '4H': est_bars = hours_missing / 4
                            else: est_bars = hours_missing
                            
                            # Add 20% buffer + 5 bars safety
                            fetch_bars = int(est_bars * 1.2) + 5
                            
                            # Cap at max_bars, ensure at least 1
                            fetch_bars = max(1, min(fetch_bars, max_bars))
                            
                            # Optimization: If very recent, barely fetch anything (but fetch a bit for live candle)
                            if fetch_bars < 2: fetch_bars = 5 
                    except Exception:
                        print(f"⚠️ Corrupt cache for {symbol} {tf_name}, re-fetching full.")
                        existing_df = None

                # Fetch from TV
                new_df = fetcher.fetch_data(symbol, exchange, fetch_bars, interval)
                
                if new_df is not None and not new_df.empty:
                    if existing_df is not None:
                        # Merge and Deduplicate
                        combined = pd.concat([existing_df, new_df])
                        combined = combined[~combined.index.duplicated(keep='last')]
                        combined.sort_index(inplace=True)
                        final_df = combined
                    else:
                        final_df = new_df
                        
                    final_df.to_csv(csv_path)
                    
            return True, "Success"
        except Exception as e:
            return False, f"Error: {str(e)}"
    
    def calculate_features(self, df: pd.DataFrame) -> pd.DataFrame:
        if df.empty: return df
        df = df.copy()
        for col in ['Open', 'High', 'Low', 'Close', 'Volume']:
            if col in df.columns: df[col] = pd.to_numeric(df[col], errors='coerce')
            
        vol_mean = df['Volume'].rolling(window=VOL_Z_WINDOW).mean()
        vol_std = df['Volume'].rolling(window=VOL_Z_WINDOW).std().replace(0, 1)
        df['Vol_Z'] = (df['Volume'] - vol_mean) / vol_std
        
        vol_z_safe = df['Vol_Z'].replace(0, 1)
        df['Elasticity'] = df['Close'].pct_change() / vol_z_safe
        
        df['day_of_week'] = df.index.dayofweek
        df['hour_of_day'] = df.index.hour
        return df.replace([np.inf, -np.inf], 0).fillna(0)
    
    def _merge_timeframes(self, df_1h, df_4h, df_1d) -> pd.DataFrame:
        df = df_1h.copy().rename(columns={'Vol_Z': 'Vol_Z_1H', 'Elasticity': 'Elasticity_1H'})
        for name, d in [('1D', df_1d), ('4H', df_4h)]:
            if not d.empty and 'Vol_Z' in d.columns:
                # Use reindex to align lower timeframe to 1H index with forward fill
                df[f'Vol_Z_{name}'] = d['Vol_Z'].reindex(df.index, method='ffill').fillna(0)
            else:
                df[f'Vol_Z_{name}'] = 0
        return df
    
    def train_model(self, symbol: str) -> Tuple[bool, str]:
        if not HAS_ML_DEPS: return False, "ML dependencies not installed"
        try:
            df_1d, df_4h, df_1h = self._load_cached_data(symbol)
            df_model = self._merge_timeframes(
                self.calculate_features(df_1h),
                self.calculate_features(df_4h),
                self.calculate_features(df_1d)
            ).dropna()
            
            # Debugging Data Sufficiency
            # print(f"DEBUG: {symbol} - 1H:{len(df_1h)} 4H:{len(df_4h)} 1D:{len(df_1d)} -> Merged:{len(df_model)}")
            
            df_model = self._create_targets(df_model)
            if len(df_model) < 50: 
                return False, f"Insufficient data (Rows: {len(df_model)}). Need 50+. 1H:{len(df_1h)}, 4H:{len(df_4h)}, 1D:{len(df_1d)}"
            
            X = df_model[self.FEATURES].values
            
            for key in TARGETS:
                col = TARGETS[key]['col']
                model = xgb.XGBClassifier(
                    n_estimators=100, max_depth=4, learning_rate=0.05,
                    objective='binary:logistic', eval_metric='logloss', n_jobs=-1
                )
                model.fit(X, df_model[col])
                
                # Save as JSON (native XGBoost format)
                # We save the BOOSTER because load_model works on booster usually or classifier logic
                # Actually model.save_model works on XGBClassifier too
                path = os.path.join(self.model_dir, f"{symbol}_{key}.json")
                model.save_model(path)
            
            # Create Dummy Token for compatibility
            with open(os.path.join(self.model_dir, f"{symbol}_multi_prob.onnx"), "w") as f:
                f.write("TOKEN")
                
            return True, "Probability Models Trained"
        except Exception as e:
            return False, f"Training Error: {str(e)}"

    def _create_targets(self, df: pd.DataFrame) -> pd.DataFrame:
        df = df.copy()
        for key, p in TARGETS.items():
            thresh = 1.0 + p['thresh']
            df[p['col']] = (df['Close'].shift(-p['horizon']) > df['Close'] * thresh).astype(int)
        return df.dropna()
    
    def _load_cached_data(self, symbol) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
        paths = {'1D': f"{symbol}_1D.csv", '4H': f"{symbol}_4H.csv", '1H': f"{symbol}_1H.csv"}
        dfs = {}
        for k, v in paths.items():
            p = os.path.join(self.data_dir, v)
            if not os.path.exists(p): 
                # print(f"⚠️ Warning: Missing data for {symbol} {k}") # Optional Log
                dfs[k] = pd.DataFrame() # Return empty DF instead of crashing
            else:
                dfs[k] = pd.read_csv(p, index_col=0, parse_dates=True)
        return dfs.get('1D', pd.DataFrame()), dfs.get('4H', pd.DataFrame()), dfs.get('1H', pd.DataFrame())
    
    def run_inference(self, symbol: str) -> Tuple[bool, Dict[str, Any]]:
        try:
            keys = ['4H', '2D', '5D']
            paths = {k: os.path.join(self.model_dir, f"{symbol}_{k}.json") for k in keys}
            if not all(os.path.exists(p) for p in paths.values()):
                return self._run_legacy_inference(symbol)
            
            if not os.path.exists(os.path.join(self.data_dir, f"{symbol}_1H.csv")):
                 return False, {"error": "No data found"}
            
            df_m = self._merge_timeframes(
                self.calculate_features(self._load_cached_data(symbol)[2]), 
                self.calculate_features(self._load_cached_data(symbol)[1]), 
                self.calculate_features(self._load_cached_data(symbol)[0])
            ).dropna()
            
            if df_m.empty: return False, {"error": "Insufficient data"}
            
            input_data = df_m[self.FEATURES].iloc[[-1]].values.astype('float32')
            
            results = {"symbol": symbol, "model_type": "multi_prob", "timestamp": datetime.now().isoformat()}
            
            for k in keys:
                # Load Booster
                booster = xgb.Booster()
                booster.load_model(paths[k])
                
                # Setup DMatrix
                dmatrix = xgb.DMatrix(input_data)
                
                # Predict
                prob = booster.predict(dmatrix)[0] # Returns float probability for binary:logistic
                results[f'prob_{k.lower()}'] = float(prob)
            
            return True, results
        except Exception as e:
            return False, {"error": str(e)}

    def _run_legacy_inference(self, symbol) -> Tuple[bool, Dict]:
            path = os.path.join(self.model_dir, f"{symbol}_model.onnx")
            if not os.path.exists(path): return False, {"error": "Model not found"}
            return False, {"error": "Legacy model not supported in this version"}

    def get_trained_models(self) -> List[str]:
        found = set()
        if os.path.exists(self.model_dir):
            for f in os.listdir(self.model_dir):
                if f.endswith("_4H.json"):
                    sym = f.replace("_4H.json", "")
                    found.add(sym)
        return list(found)

    def export_all_models(self) -> str:
        """
        Exports all trained models to a master 'mobile_exports' directory.
        Returns the absolute path to the export directory.
        """
        master_export_dir = os.path.join(self.model_dir, "mobile_exports")
        if os.path.exists(master_export_dir):
            shutil.rmtree(master_export_dir)
        os.makedirs(master_export_dir)
        
        trained_symbols = self.get_trained_models()
        valid_count = 0
        
        for symbol in trained_symbols:
            try:
                pkg_path = self.export_mobile_package(symbol)
                dest_path = os.path.join(master_export_dir, f"{symbol}_pkg")
                shutil.copytree(pkg_path, dest_path)
                valid_count += 1
            except Exception as e:
                print(f"⚠️ Failed to export {symbol}: {e}")
                
        if valid_count == 0:
            raise ValueError("No valid models found to export.")
            
        return master_export_dir

    def export_mobile_package(self, symbol: str) -> str:
        pkg_dir = os.path.join(self.model_dir, f"{symbol}_mobile_pkg")
        os.makedirs(pkg_dir, exist_ok=True)
        for k in ['4H', '2D', '5D']:
            src = os.path.join(self.model_dir, f"{symbol}_{k}.json")
            if not os.path.exists(src): raise FileNotFoundError(f"Missing {k} model")
            shutil.copy(src, os.path.join(pkg_dir, f"model_{k}.json"))
        with open(os.path.join(pkg_dir, "features.json"), "w") as f:
            json.dump({
                "symbol": symbol, "version": "1.0", "type": "split_prob_json",
                "inputs": self.FEATURES, "models": ["model_4H.json", "model_2D.json", "model_5D.json"],
                "thresholds": {k: TARGETS[k]['thresh'] for k in TARGETS}
            }, f, indent=2)
        return pkg_dir

    def clear(self): self._errors = []
