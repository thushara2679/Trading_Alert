"""
Purpose: Multi-Horizon Forecast Visualization Widget.
Protocol: Antigravity - UI Module
@param: Forecast data (4H, 2D, 5D percentages)
@returns: Tkinter widget with bar chart visualization

Displays 3 forecast horizons with color-coded bars and percentage labels.
"""

import tkinter as tk
from tkinter import ttk
import matplotlib
matplotlib.use('TkAgg')
from matplotlib.figure import Figure
from matplotlib.backends.backend_tkagg import FigureCanvasTkAgg
import numpy as np
from typing import Dict, Any, Optional
from datetime import datetime


# ==========================================
# CONSTANTS
# ==========================================

# Colors (Midnight Indigo Palette)
BG_COLOR = "#0f172a"      # Deep Midnight
SURFACE_COLOR = "#1e293b" # Slate Indigo
FG_COLOR = "#f8fafc"      # Slate White
ACCENT_COLOR = "#0ea5e9"  # Sky Blue
POSITIVE_COLOR = "#10b981" # Emerald
NEGATIVE_COLOR = "#ef4444" # Rose
NEUTRAL_COLOR = "#f59e0b"  # Amber
DIM_COLOR = "#64748b"      # Slate Gray


# ==========================================
# FORECAST PANEL WIDGET
# ==========================================

class ForecastPanel(ttk.Frame):
    """
    Multi-Horizon Forecast Visualization Panel.
    
    Purpose:
        Displays 4H, 2D, and 5D price change forecasts with bar chart.
    """
    
    def __init__(self, parent, **kwargs):
        super().__init__(parent, **kwargs)
        
        self._setup_ui()
    
    def _setup_ui(self) -> None:
        """Sets up the forecast panel UI."""
        # Title
        self.title_label = ttk.Label(
            self,
            text="📈 Multi-Horizon Forecast",
            font=("Inter", 14, "bold"),
            foreground=ACCENT_COLOR
        )
        self.title_label.pack(pady=(0, 10))
        
        # Forecast Cards Container
        self.cards_frame = ttk.Frame(self)
        self.cards_frame.pack(fill="x", pady=10)
        
        # Create 3 forecast cards
        self.cards = {}
        horizons = [
            ("4H", "4 Hours"),
            ("2D", "2 Days"),
            ("5D", "5 Days")
        ]
        
        for i, (key, label) in enumerate(horizons):
            card = self._create_forecast_card(self.cards_frame, key, label)
            card.grid(row=0, column=i, padx=10, sticky="ew")
            self.cards[key] = card
        
        # Configure grid weights
        for i in range(3):
            self.cards_frame.columnconfigure(i, weight=1)
        
        # Bar Chart
        self.chart_frame = ttk.Frame(self)
        self.chart_frame.pack(fill="both", expand=True, pady=10)
        
        self._create_chart()
        
        # Temporal Context
        self.context_label = ttk.Label(
            self,
            text="",
            font=("Inter", 9),
            foreground=DIM_COLOR
        )
        self.context_label.pack(pady=5)
    
    def _create_forecast_card(
        self, 
        parent: ttk.Frame, 
        key: str, 
        label: str
    ) -> ttk.Frame:
        """Creates a single forecast card."""
        card = ttk.Frame(parent, style="TFrame")
        
        # Horizon Label
        ttk.Label(
            card,
            text=label.upper(),
            font=("Inter", 10, "bold"),
            foreground=DIM_COLOR
        ).pack()
        
        # Percentage Label
        pct_label = ttk.Label(
            card,
            text="---%",
            font=("Inter", 24, "bold"),
            foreground=FG_COLOR
        )
        pct_label.pack(pady=5)
        
        # Store reference
        card.pct_label = pct_label
        
        return card
    
    def _create_chart(self) -> None:
        """Creates matplotlib bar chart."""
        # Create figure with dark background
        self.fig = Figure(figsize=(6, 3), facecolor=BG_COLOR)
        self.ax = self.fig.add_subplot(111)
        self.ax.set_facecolor(BG_COLOR)
        
        # Initial empty chart
        self.bars = self.ax.bar(
            ["4H", "2D", "5D"],
            [0, 0, 0],
            color=NEUTRAL_COLOR,
            alpha=0.7
        )
        
        # Styling
        self.ax.set_ylabel("Price Change (%)", color=FG_COLOR, fontsize=10)
        self.ax.set_title("Forecast Comparison", color=FG_COLOR, fontsize=11, pad=10)
        self.ax.tick_params(colors=FG_COLOR, labelsize=9)
        self.ax.spines['bottom'].set_color(DIM_COLOR)
        self.ax.spines['left'].set_color(DIM_COLOR)
        self.ax.spines['top'].set_visible(False)
        self.ax.spines['right'].set_visible(False)
        self.ax.grid(True, alpha=0.1, color=FG_COLOR)
        self.ax.axhline(y=0, color=DIM_COLOR, linestyle='-', linewidth=1.0, alpha=0.4)
        
        # Embed in tkinter
        self.canvas = FigureCanvasTkAgg(self.fig, master=self.chart_frame)
        self.canvas.draw()
        self.canvas.get_tk_widget().pack(fill="both", expand=True)
    
    def update_forecasts(self, forecasts: Dict[str, float]) -> None:
        """
        Updates the display with Probability/Confidence values.
        
        Args:
            forecasts (Dict): Dictionary with keys 'prob_4h', 'prob_2d', 'prob_5d'
        """
        # Extract values (0.0 - 1.0) -> Percentage (0 - 100)
        p_4h = forecasts.get("prob_4h", 0.0) * 100
        p_2d = forecasts.get("prob_2d", 0.0) * 100
        p_5d = forecasts.get("prob_5d", 0.0) * 100
        
        values = [p_4h, p_2d, p_5d]
        
        # Update cards
        # Logic: > 70% is Strong Signal (Green), else Neutral (Blue)
        for i, (key, val) in enumerate(zip(["4H", "2D", "5D"], values)):
            card = self.cards[key]
            
            if val >= 70.0:
                color = POSITIVE_COLOR
                text = f"BUY {val:.1f}%"
            else:
                color = ACCENT_COLOR # Blue
                text = f"{val:.1f}%"
            
            # Update label
            card.pct_label.configure(
                text=text,
                foreground=color
            )
        
        # Update bar chart
        colors = [
            POSITIVE_COLOR if v >= 70.0 else ACCENT_COLOR
            for v in values
        ]
        
        for bar, height, color in zip(self.bars, values, colors):
            bar.set_height(height)
            bar.set_color(color)
        
        # Update y-axis limits (0 to 100 fixed usually appropriate for probability)
        self.ax.set_ylim(0, 100)
        
        self.canvas.draw()
        
        # Update temporal context
        self._update_temporal_context()
    
    def _update_temporal_context(self) -> None:
        """Updates the temporal context display."""
        now = datetime.now()
        day_names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        day_name = day_names[now.weekday()]
        hour = now.hour
        
        # Market status (simplified - assumes NYSE hours)
        if now.weekday() < 5 and 9 <= hour < 16:
            market_status = "🟢 Market Open"
        else:
            market_status = "🔴 Market Closed"
        
        context_text = f"{day_name}, {now.strftime('%H:%M')} | {market_status}"
        self.context_label.configure(text=context_text)
    
    def show_error(self, message: str) -> None:
        """Displays error message."""
        for key in ["4H", "2D", "5D"]:
            self.cards[key].pct_label.configure(
                text="ERROR",
                foreground=NEGATIVE_COLOR
            )
        
        self.context_label.configure(text=f"⚠️ {message}")
    
    def reset(self) -> None:
        """Resets the display to initial state."""
        for key in ["4H", "2D", "5D"]:
            self.cards[key].pct_label.configure(
                text="---%",
                foreground="#888888"
            )
        
        # Reset chart
        for bar in self.bars:
            bar.set_height(0)
            bar.set_color(NEUTRAL_COLOR)
        
        self.ax.set_ylim(-1, 1)
        self.canvas.draw()
        
        self.context_label.configure(text="")
