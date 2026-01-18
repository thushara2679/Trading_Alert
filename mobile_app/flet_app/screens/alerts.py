"""
Alerts Screen - Signal History
Protocol: Antigravity - Standalone Mobile Module

Shows history of generated alerts/signals with detailed card layout.

Card Layout (from User Guide):
┌─────────────────────────────────────┐
│ 🔥 JKH.N0000            [COMBO]     │
│ 4H: 75%  2D: 62%  5D: 88%          │
│ Last Price: 142.50                  │
│ Updated: 2 mins ago                 │
└─────────────────────────────────────┘
"""

import flet as ft
from flet import colors, icons
import json
import os
from datetime import datetime, timedelta
from typing import List

from services.signal_filter import SignalFilter


# Compatibility layer
if not hasattr(ft, 'Colors'):
    ft.Colors = colors
if not hasattr(ft, 'Icons'):
    ft.Icons = icons


class AlertItem:
    """Alert data model."""
    
    def __init__(
        self,
        symbol: str,
        signal_type: str,
        prob_4h: float,
        prob_2d: float,
        prob_5d: float,
        timestamp: str,
        last_price: float = 0.0,
    ):
        self.symbol = symbol
        self.signal_type = signal_type
        self.prob_4h = prob_4h
        self.prob_2d = prob_2d
        self.prob_5d = prob_5d
        self.timestamp = timestamp
        self.last_price = last_price
    
    def to_dict(self) -> dict:
        return {
            "symbol": self.symbol,
            "signal_type": self.signal_type,
            "prob_4h": self.prob_4h,
            "prob_2d": self.prob_2d,
            "prob_5d": self.prob_5d,
            "timestamp": self.timestamp,
            "last_price": self.last_price,
        }
    
    @classmethod
    def from_dict(cls, data: dict) -> "AlertItem":
        return cls(**data)


class AlertsScreen:
    """Alerts screen with detailed signal cards."""
    
    def __init__(self, page: ft.Page):
        self.page = page
        self.alerts: List[AlertItem] = []
        self.alert_list = ft.ListView(expand=True, spacing=8, padding=16)
        self._load_alerts()
    
    def build(self) -> ft.Container:
        """Build the alerts screen UI."""
        self._refresh_list()
        
        return ft.Container(
            content=ft.Column([
                # Header
                ft.Container(
                    content=ft.Row([
                        ft.Text("🔔 Alerts", size=24, weight=ft.FontWeight.BOLD),
                        ft.Row([
                            ft.Text(f"{len(self.alerts)} alerts", color=ft.Colors.GREY_500),
                            ft.IconButton(
                                icon=ft.Icons.DELETE_OUTLINE,
                                tooltip="Clear All",
                                on_click=self._clear_alerts,
                            ),
                        ]),
                    ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                    padding=ft.padding.all(16),
                ),
                
                # Alert List
                self.alert_list,
            ], expand=True),
            expand=True,
        )
    
    def _refresh_list(self):
        """Refresh the alerts list."""
        self.alert_list.controls.clear()
        
        if not self.alerts:
            self.alert_list.controls.append(
                ft.Container(
                    content=ft.Column([
                        ft.Icon(ft.Icons.NOTIFICATIONS_OFF, size=64, color=ft.Colors.GREY_600),
                        ft.Text("No alerts yet", color=ft.Colors.GREY_400),
                        ft.Text("Run a scan to generate alerts", color=ft.Colors.GREY_500, size=12),
                    ], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                    alignment=ft.Alignment(0, 0),
                    expand=True,
                )
            )
        else:
            # Sort by signal priority
            sorted_alerts = sorted(
                self.alerts,
                key=lambda a: SignalFilter.get_signal_priority(a.signal_type),
                reverse=True
            )
            for alert in sorted_alerts:
                self.alert_list.controls.append(self._build_alert_card(alert))
    
    def _build_alert_card(self, alert: AlertItem) -> ft.Container:
        """Build an alert card per User Guide spec."""
        signal_color = SignalFilter.COLORS.get(alert.signal_type, "#6B7280")
        
        # Get signal emoji
        emoji_map = {
            "COMBO": "🔥",
            "SCALP": "⚡",
            "WATCH": "📈",
            "AVOID": "❄️",
            "NEUTRAL": "➖",
        }
        emoji = emoji_map.get(alert.signal_type, "➖")
        
        # Calculate time ago
        try:
            dt = datetime.fromisoformat(alert.timestamp)
            diff = datetime.now() - dt
            if diff < timedelta(minutes=1):
                time_str = "Just now"
            elif diff < timedelta(hours=1):
                time_str = f"{int(diff.total_seconds() / 60)} min ago"
            elif diff < timedelta(days=1):
                time_str = f"{int(diff.total_seconds() / 3600)} hrs ago"
            else:
                time_str = dt.strftime("%b %d")
        except:
            time_str = alert.timestamp[:10]
        
        return ft.Container(
            content=ft.Column([
                # Header Row: Emoji + Symbol + Signal Badge
                ft.Row([
                    ft.Text(f"{emoji} {alert.symbol}", weight=ft.FontWeight.BOLD, size=16),
                    ft.Container(
                        content=ft.Text(
                            alert.signal_type,
                            color="white",
                            weight=ft.FontWeight.BOLD,
                            size=11,
                        ),
                        bgcolor=signal_color,
                        border_radius=12,
                        padding=ft.padding.symmetric(horizontal=10, vertical=4),
                    ),
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                
                # Probabilities Row
                ft.Row([
                    ft.Text(f"4H: {alert.prob_4h:.0f}%", size=13, color=ft.Colors.GREY_300),
                    ft.Text(f"2D: {alert.prob_2d:.0f}%", size=13, color=ft.Colors.GREY_300),
                    ft.Text(f"5D: {alert.prob_5d:.0f}%", size=13, color=ft.Colors.GREY_300),
                ], spacing=16),
                
                # Footer Row: Price + Time
                ft.Row([
                    ft.Text(
                        f"Price: {alert.last_price:.2f}" if alert.last_price else "",
                        size=12,
                        color=ft.Colors.GREY_500,
                    ),
                    ft.Text(f"Updated: {time_str}", size=12, color=ft.Colors.GREY_500),
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
            ], spacing=8),
            bgcolor="#1E293B",
            padding=16,
            border_radius=12,
            border=ft.border.all(1, signal_color) if alert.signal_type == "COMBO" else None,
        )
    
    def add_alert(self, alert: AlertItem):
        """Add a new alert."""
        self.alerts.insert(0, alert)
        self._save_alerts()
        self._refresh_list()
    
    async def _clear_alerts(self, e):
        """Clear all alerts."""
        self.alerts.clear()
        self._save_alerts()
        self._refresh_list()
        self.page.update()
    
    def _save_alerts(self):
        """Save alerts to local storage."""
        data = [a.to_dict() for a in self.alerts]
        with open("alerts.json", "w") as f:
            json.dump(data, f)
    
    def _load_alerts(self):
        """Load alerts from local storage."""
        if os.path.exists("alerts.json"):
            try:
                with open("alerts.json", "r") as f:
                    data = json.load(f)
                self.alerts = [AlertItem.from_dict(d) for d in data]
            except:
                pass
