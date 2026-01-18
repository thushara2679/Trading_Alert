"""
Watchlist Screen - Stock List with Scan Functionality
Protocol: Antigravity - Standalone Mobile Module

Main screen showing the watchlist with scan and data fetching.
"""


import flet as ft
from flet import colors, icons
from typing import List, Optional
import json
import os

from services.data_fetcher import DataFetcher
from services.model_inference import ModelInference
from services.signal_filter import SignalFilter


# Compatibility layer for different Flet versions
if not hasattr(ft, 'Colors'):
    ft.Colors = colors
if not hasattr(ft, 'Icons'):
    ft.Icons = icons


class StockSymbol:
    """Stock symbol data model."""
    
    def __init__(
        self,
        symbol: str,
        exchange: str = "CSELK",
        prob_4h: Optional[float] = None,
        prob_2d: Optional[float] = None,
        prob_5d: Optional[float] = None,
        signal_type: Optional[str] = None,
        data_status: str = "Not Scanned",
        last_updated: Optional[str] = None,
    ):
        self.symbol = symbol
        self.exchange = exchange
        self.prob_4h = prob_4h
        self.prob_2d = prob_2d
        self.prob_5d = prob_5d
        self.signal_type = signal_type
        self.data_status = data_status
        self.last_updated = last_updated
    
    def to_dict(self) -> dict:
        return {
            "symbol": self.symbol,
            "exchange": self.exchange,
            "prob_4h": self.prob_4h,
            "prob_2d": self.prob_2d,
            "prob_5d": self.prob_5d,
            "signal_type": self.signal_type,
            "data_status": self.data_status,
            "last_updated": self.last_updated,
        }
    
    @classmethod
    def from_dict(cls, data: dict) -> "StockSymbol":
        return cls(**data)


class WatchlistScreen:
    """Watchlist screen with stock list and scan functionality."""
    
    def __init__(self, page: ft.Page):
        self.page = page
        self.stocks: List[StockSymbol] = []
        self.is_scanning = False
        self.status_text = ft.Text("Ready", color=ft.Colors.GREY_400)
        self.stock_list = ft.ListView(expand=True, spacing=8, padding=16)
        
        # Services
        self.data_fetcher = DataFetcher()
        self.model_inference = ModelInference()
        
        # Load persisted stocks
        self._load_stocks()
    
    def build(self) -> ft.Container:
        """Build the watchlist screen UI."""
        self._refresh_list()
        
        return ft.Container(
            content=ft.Column([
                # Header
                ft.Container(
                    content=ft.Row([
                        ft.Text("📊 Watchlist", size=24, weight=ft.FontWeight.BOLD),
                        ft.Row([
                            ft.IconButton(
                                icon=ft.Icons.FILE_UPLOAD,
                                tooltip="Import CSV",
                                on_click=self._import_csv,
                            ),
                        ]),
                    ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                    padding=ft.padding.all(16),
                ),
                
                # Scan Button
                ft.Container(
                    content=ft.Row([
                        ft.ElevatedButton(
                            "🔍 Scan All",
                            icon=ft.Icons.RADAR,
                            on_click=self._scan_all,
                            style=ft.ButtonStyle(
                                bgcolor="#0EA5E9",
                                color=ft.Colors.WHITE,
                            ),
                            expand=True,
                        ),
                        ft.Text(
                            f"{len(self.stocks)} stocks",
                            color=ft.Colors.GREY_400,
                        ),
                    ], spacing=12),
                    padding=ft.padding.symmetric(horizontal=16),
                ),
                
                # Status
                ft.Container(
                    content=self.status_text,
                    padding=ft.padding.symmetric(horizontal=16, vertical=8),
                ),
                
                # Stock List
                self.stock_list,
            ], expand=True),
            expand=True,
        )
    
    def _refresh_list(self):
        """Refresh the stock list UI."""
        self.stock_list.controls.clear()
        
        if not self.stocks:
            self.stock_list.controls.append(
                ft.Container(
                    content=ft.Column([
                        ft.Icon(ft.Icons.LIST_ALT, size=64, color=ft.Colors.GREY_600),
                        ft.Text("No stocks in watchlist", color=ft.Colors.GREY_400),
                        ft.TextButton("Import CSV", on_click=self._import_csv),
                    ], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                    alignment=ft.Alignment(0, 0),
                    expand=True,
                )
            )
        else:
            for stock in self.stocks:
                self.stock_list.controls.append(self._build_stock_tile(stock))
    
    def _build_stock_tile(self, stock: StockSymbol) -> ft.Card:
        """Build a single stock tile with signal info."""
        signal_color = SignalFilter.COLORS.get(stock.signal_type, "#6B7280")
        
        # Calculate time ago
        time_text = ""
        if stock.last_updated:
            try:
                from datetime import datetime
                scan_time = datetime.fromisoformat(stock.last_updated)
                delta = datetime.now() - scan_time
                minutes = int(delta.total_seconds() / 60)
                if minutes < 60:
                    time_text = f"{minutes}m ago"
                else:
                    time_text = f"{minutes//60}h ago"
            except:
                pass

        # Build status row (Live/Cached + Time)
        status_color = ft.Colors.GREEN if stock.data_status == "Live" else ft.Colors.ORANGE
        if stock.data_status == "No Data":
            status_color = ft.Colors.RED
            
        status_row = ft.Row([
             ft.Icon(ft.Icons.CIRCLE, size=8, color=status_color),
             ft.Text(stock.data_status, size=10, color=status_color),
             ft.Text(f"• {time_text}" if time_text else "", size=10, color=ft.Colors.GREY_500),
        ], spacing=4, alignment=ft.MainAxisAlignment.END)

        # Build trailing info based on scan status
        if stock.signal_type:
            prob_text = ""
            if stock.prob_4h is not None:
                prob_text = f"4H:{stock.prob_4h:.0f}% 2D:{stock.prob_2d:.0f}% 5D:{stock.prob_5d:.0f}%"
            
            trailing = ft.Column([
                ft.Container(
                    content=ft.Text(
                        stock.signal_type,
                        color="white",
                        weight=ft.FontWeight.BOLD,
                        size=11,
                    ),
                    bgcolor=signal_color,
                    border_radius=12,
                    padding=ft.padding.symmetric(horizontal=8, vertical=4),
                ),
                ft.Text(prob_text, size=9, color=ft.Colors.GREY_400),
                status_row,
            ], horizontal_alignment=ft.CrossAxisAlignment.END, spacing=2)
        else:
            trailing = ft.Column([
                ft.Text(stock.data_status, color=status_color, size=12),
                status_row if stock.data_status != "Not Scanned" else ft.Container(),
            ], horizontal_alignment=ft.CrossAxisAlignment.END)
        
        return ft.Card(
            content=ft.Container(
                content=ft.Row([
                    ft.CircleAvatar(
                        content=ft.Text(stock.symbol[:2].upper(), size=12),
                        bgcolor=signal_color or ft.Colors.GREY_700,
                    ),
                    ft.Column([
                        ft.Text(stock.symbol, weight=ft.FontWeight.BOLD),
                        ft.Text(stock.exchange, size=12, color=ft.Colors.GREY_400),
                    ], spacing=2, expand=True),
                    trailing,
                ], alignment=ft.MainAxisAlignment.START),
                padding=12,
                bgcolor="#1E293B" if stock.signal_type else None,
            ),
        )
    
    def _get_signal_color(self, signal_type: Optional[str]) -> Optional[str]:
        """Get color for signal type."""
        return SignalFilter.COLORS.get(signal_type, "#6B7280")
    
    async def _scan_all(self, e):
        """Scan all stocks for signals."""
        if self.is_scanning or not self.stocks:
            return
        
        self.is_scanning = True
        total = len(self.stocks)
        
        for i, stock in enumerate(self.stocks):
            self.status_text.value = f"Fetching {stock.symbol} ({i+1}/{total})..."
            self.page.update()
            
            # Fetch data (uses 15-min validity check internally)
            data = self.data_fetcher.get_data(stock.symbol, stock.exchange)
            
            if data and data.get("features"):
                self.status_text.value = f"Analyzing {stock.symbol}..."
                self.page.update()
                
                # Load models and predict
                self.model_inference.load_models(stock.symbol)
                features = data["features"]  # Now a Dict
                probs = self.model_inference.predict(stock.symbol, features)  # Returns Dict
                
                # Evaluate signal with percentages
                result = SignalFilter.evaluate(probs)
                
                stock.prob_4h = probs.get("4H", 0.0)
                stock.prob_2d = probs.get("2D", 0.0)
                stock.prob_5d = probs.get("5D", 0.0)
                stock.signal_type = result.type_name
                stock.data_status = "Live" if data.get("is_live") else "Cached"
                stock.last_updated = data.get("timestamp")
            else:
                stock.data_status = "No Data"
                stock.signal_type = None
        
        # Sort by signal priority
        self.stocks.sort(
            key=lambda s: SignalFilter.get_signal_priority(s.signal_type or "NEUTRAL"),
            reverse=True
        )
        
        self.is_scanning = False
        self.status_text.value = f"Scan complete ({len(self.data_fetcher.get_failed_symbols())} failed)"
        self._refresh_list()
        self._save_stocks()
        self.page.update()
    
    async def _import_csv(self, e):
        """Import stocks from CSV file."""
        file_picker = ft.FilePicker(on_result=self._on_csv_picked)
        self.page.overlay.append(file_picker)
        self.page.update()
        file_picker.pick_files(allowed_extensions=["csv"])
    
    async def _on_csv_picked(self, e):
        """Handle CSV file selection."""
        if not e.files:
            return
        
        try:
            filepath = e.files[0].path
            with open(filepath, "r") as f:
                content = f.read()
            
            lines = [l.strip() for l in content.split("\n") if l.strip()]
            if not lines:
                return
            
            self.stocks.clear()
            
            # Logic: Row 1 = Exchange, Row 2+ = Symbols
            exchange = lines[0].split(",")[0].strip()
            
            added_count = 0
            for line in lines[1:]:
                if not line: continue
                
                # Handle potential CSV columns
                parts = line.split(",")
                raw_symbol = parts[0].strip()
                
                # Skip header row if it exists
                if raw_symbol.lower() == "symbol":
                    continue
                    
                # Use symbol exactly as is
                final_symbol = raw_symbol
                
                self.stocks.append(StockSymbol(final_symbol, exchange))
                added_count += 1
            
            self._refresh_list()
            self._save_stocks()
            self.page.update()
            
            self.page.snack_bar = ft.SnackBar(
                content=ft.Text(f"✅ Imported {added_count} stocks from {exchange}"),
                bgcolor="#15803d" # Green 700
            )
            self.page.snack_bar.open = True
            self.page.update()
            
        except Exception as ex:
            self.page.snack_bar = ft.SnackBar(
                content=ft.Text(f"❌ Import failed: {ex}"),
                bgcolor="#b91c1c" # Red 700
            )
            self.page.snack_bar.open = True
            self.page.update()
    
    def _save_stocks(self):
        """Save stocks to local storage."""
        data = [s.to_dict() for s in self.stocks]
        with open("stocks.json", "w") as f:
            json.dump(data, f)
    
    def _load_stocks(self):
        """Load stocks from local storage."""
        if os.path.exists("stocks.json"):
            try:
                with open("stocks.json", "r") as f:
                    data = json.load(f)
                self.stocks = [StockSymbol.from_dict(d) for d in data]
            except:
                pass
