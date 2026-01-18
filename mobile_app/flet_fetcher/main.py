"""
Flet Data Fetcher - TradingView Data Module
Protocol: Antigravity - Mobile Module

Uses tvdatafeed library to fetch real OHLCV data from TradingView.
Saves data to JSON files for consumption by the Flutter app.

Usage:
    python main.py                    # Interactive Flet UI
    python main.py --fetch SYMBOL     # CLI fetch mode
"""

import os
import json
import argparse
from datetime import datetime
from typing import Optional, List, Dict, Any

try:
    from tvDatafeed import TvDatafeed, Interval
except ImportError:
    print("❌ tvdatafeed not installed. Run: pip install git+https://github.com/rongardF/tvdatafeed.git")
    exit(1)

import flet as ft


class DataFetcher:
    """
    Fetches OHLCV data from TradingView using tvdatafeed.
    Calculates features for XGBoost model inference.
    """
    
    def __init__(self, cache_dir: str = "data_cache"):
        self.tv = TvDatafeed()
        self.cache_dir = cache_dir
        os.makedirs(cache_dir, exist_ok=True)
        
    def fetch_symbol(self, symbol: str, exchange: str = "CSELK", 
                     interval: str = "1h", n_bars: int = 100) -> Optional[Dict[str, Any]]:
        """
        Fetches data for a single symbol and calculates features.
        
        Args:
            symbol: Stock ticker (e.g., "CCS")
            exchange: Exchange name (default: CSELK for Colombo)
            interval: Timeframe (1h, 4h, daily)
            n_bars: Number of historical bars
            
        Returns:
            Dict with OHLCV data and calculated features, or None on failure.
        """
        try:
            # Map interval string to tvdatafeed Interval
            interval_map = {
                "1m": Interval.in_1_minute,
                "5m": Interval.in_5_minute,
                "15m": Interval.in_15_minute,
                "1h": Interval.in_1_hour,
                "4h": Interval.in_4_hour,
                "daily": Interval.in_daily,
                "weekly": Interval.in_weekly,
            }
            tv_interval = interval_map.get(interval.lower(), Interval.in_1_hour)
            
            # Clean symbol (remove .N0000 suffix if present)
            clean_symbol = symbol.split('.')[0]
            
            print(f"📡 Fetching {clean_symbol} from {exchange}...")
            
            df = self.tv.get_hist(
                symbol=clean_symbol,
                exchange=exchange,
                interval=tv_interval,
                n_bars=n_bars
            )
            
            if df is None or df.empty:
                print(f"⚠️ No data returned for {clean_symbol}")
                return None
                
            print(f"✅ Received {len(df)} bars for {clean_symbol}")
            
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
            }
            
            # Save to cache
            self._save_to_cache(symbol, result)
            
            return result
            
        except Exception as e:
            print(f"❌ Error fetching {symbol}: {e}")
            return None
    
    def _calculate_features(self, df) -> List[float]:
        """
        Calculates feature vector for XGBoost model.
        Matches the format expected by mobile_app model_inference.
        """
        import numpy as np
        
        # Volume Z-Score (20-period)
        vol = df["volume"].values
        if len(vol) >= 20:
            vol_mean = np.mean(vol[-20:])
            vol_std = np.std(vol[-20:]) + 1e-8
            vol_z_1h = (vol[-1] - vol_mean) / vol_std
        else:
            vol_z_1h = 0.0
            
        # Simplified 4H and 1D vol_z (approximations)
        vol_z_4h = vol_z_1h * 0.8
        vol_z_1d = vol_z_1h * 0.6
        
        # Price elasticity
        close = df["close"].values
        if len(close) >= 2:
            price_change = (close[-1] - close[-2]) / (close[-2] + 1e-8)
            elasticity = price_change / (vol_z_1h + 1e-8) if vol_z_1h != 0 else 0.0
        else:
            elasticity = 0.0
            
        # Temporal features
        now = datetime.now()
        day_of_week = float(now.weekday() + 1)  # 1-7
        hour_of_day = float(now.hour)
        
        return [vol_z_1h, vol_z_4h, vol_z_1d, elasticity, day_of_week, hour_of_day]
    
    def _save_to_cache(self, symbol: str, data: Dict[str, Any]) -> str:
        """Saves fetched data to JSON cache file."""
        filepath = os.path.join(self.cache_dir, f"{symbol}.json")
        with open(filepath, "w") as f:
            json.dump(data, f, indent=2)
        return filepath
    
    def load_from_cache(self, symbol: str) -> Optional[Dict[str, Any]]:
        """Loads cached data for a symbol."""
        filepath = os.path.join(self.cache_dir, f"{symbol}.json")
        if os.path.exists(filepath):
            with open(filepath, "r") as f:
                return json.load(f)
        return None
    
    def fetch_multiple(self, symbols: List[str], exchange: str = "CSELK") -> Dict[str, Any]:
        """Fetches data for multiple symbols."""
        results = {}
        for symbol in symbols:
            result = self.fetch_symbol(symbol, exchange)
            if result:
                results[symbol] = result
        return results


def create_flet_app(page: ft.Page):
    """
    Flet UI for data fetching.
    Provides a simple interface to fetch and view TradingView data.
    """
    page.title = "📊 Stock Data Fetcher"
    page.theme_mode = ft.ThemeMode.DARK
    page.padding = 20
    
    fetcher = DataFetcher()
    
    # UI Components
    symbol_input = ft.TextField(
        label="Symbol",
        value="CCS",
        width=200,
    )
    
    exchange_input = ft.TextField(
        label="Exchange",
        value="CSELK",
        width=200,
    )
    
    status_text = ft.Text("Ready to fetch data...", color=ft.Colors.GREY_400)
    
    results_column = ft.Column(scroll=ft.ScrollMode.AUTO, expand=True)
    
    def fetch_clicked(e):
        symbol = symbol_input.value.strip()
        exchange = exchange_input.value.strip()
        
        if not symbol:
            status_text.value = "⚠️ Please enter a symbol"
            status_text.color = ft.Colors.ORANGE
            page.update()
            return
            
        status_text.value = f"📡 Fetching {symbol}..."
        status_text.color = ft.Colors.BLUE
        page.update()
        
        result = fetcher.fetch_symbol(symbol, exchange)
        
        if result:
            status_text.value = f"✅ Fetched {result['bars_count']} bars for {symbol}"
            status_text.color = ft.Colors.GREEN
            
            # Display results
            ohlcv = result["ohlcv"]
            features = result["features"]
            
            results_column.controls.clear()
            results_column.controls.append(
                ft.Card(
                    content=ft.Container(
                        content=ft.Column([
                            ft.Text(f"📈 {symbol} @ {exchange}", size=18, weight=ft.FontWeight.BOLD),
                            ft.Divider(),
                            ft.Text(f"Open: {ohlcv['open']:.2f}"),
                            ft.Text(f"High: {ohlcv['high']:.2f}"),
                            ft.Text(f"Low: {ohlcv['low']:.2f}"),
                            ft.Text(f"Close: {ohlcv['close']:.2f}"),
                            ft.Text(f"Volume: {ohlcv['volume']:,.0f}"),
                            ft.Divider(),
                            ft.Text("Features:", weight=ft.FontWeight.BOLD),
                            ft.Text(f"Vol_Z_1H: {features[0]:.4f}"),
                            ft.Text(f"Vol_Z_4H: {features[1]:.4f}"),
                            ft.Text(f"Vol_Z_1D: {features[2]:.4f}"),
                            ft.Text(f"Elasticity: {features[3]:.4f}"),
                            ft.Text(f"Day: {features[4]:.0f}, Hour: {features[5]:.0f}"),
                        ]),
                        padding=15,
                    )
                )
            )
        else:
            status_text.value = f"❌ Failed to fetch {symbol}"
            status_text.color = ft.Colors.RED
            
        page.update()
    
    fetch_button = ft.ElevatedButton(
        "🔍 Fetch Data",
        on_click=fetch_clicked,
        style=ft.ButtonStyle(
            bgcolor=ft.Colors.BLUE_700,
            color=ft.Colors.WHITE,
        ),
    )
    
    # Layout
    page.add(
        ft.Column([
            ft.Text("Stock Data Fetcher", size=24, weight=ft.FontWeight.BOLD),
            ft.Text("Uses tvdatafeed to fetch real TradingView data", color=ft.Colors.GREY_400),
            ft.Divider(),
            ft.Row([symbol_input, exchange_input, fetch_button]),
            status_text,
            ft.Divider(),
            results_column,
        ], expand=True)
    )


def cli_fetch(symbol: str, exchange: str = "CSELK"):
    """CLI mode for fetching data without UI."""
    fetcher = DataFetcher()
    result = fetcher.fetch_symbol(symbol, exchange)
    
    if result:
        print(json.dumps(result, indent=2))
    else:
        print(f"Failed to fetch data for {symbol}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Flet Data Fetcher for TradingView")
    parser.add_argument("--fetch", type=str, help="Fetch data for a symbol (CLI mode)")
    parser.add_argument("--exchange", type=str, default="CSELK", help="Exchange name")
    
    args = parser.parse_args()
    
    if args.fetch:
        cli_fetch(args.fetch, args.exchange)
    else:
        ft.app(target=create_flet_app)
