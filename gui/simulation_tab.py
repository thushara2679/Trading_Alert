"""
Purpose: Simulation Tab Module for Stock Trainer.
Protocol: Antigravity - GUI Module
@param: parent widget, engine reference, and callbacks
@returns: SimulationTab instance
"""

import tkinter as tk
from tkinter import ttk, messagebox
from typing import List, Dict, Any, Optional, Callable

# Import components
from utils.forecast_panel import ForecastPanel
from .styles import BG_BASE, BG_SURFACE, ACCENT_PRIMARY, TEXT_PRIMARY, SUCCESS_COLOR, ERROR_COLOR, WARNING_COLOR

class SimulationTab(ttk.Frame):
    """
    Dedicated frame for the Simulation & Inference tab.
    Handles ONNX model selection and multi-horizon forecast display.
    """
    
    def __init__(self, parent, on_run_simulation: Callable, refresh_models_callback: Callable, on_export_mobile: Callable):
        super().__init__(parent, style="TFrame")
        
        self.on_run_simulation = on_run_simulation
        self.refresh_models_callback = refresh_models_callback
        self.on_export_mobile = on_export_mobile
        
        self._build_ui()

    def _build_ui(self):
        """Constructs the simulation tab UI."""
        sim_frame = ttk.Frame(self, style="TFrame", padding=25)
        sim_frame.pack(fill="both", expand=True)
        
        # Header Area
        header_group = ttk.Frame(sim_frame, style="TFrame")
        header_group.pack(fill="x", pady=(0, 20))

        ttk.Label(
            header_group,
            text="🎯 Model Simulation",
            style="Header.TLabel"
        ).pack(side="left")

        # Control Group (Selection + Run)
        control_group = ttk.Frame(sim_frame, style="Surface.TFrame", padding=15)
        control_group.pack(fill="x", pady=(0, 25))

        ttk.Label(control_group, text="Select Stock Model:", style="Surface.TLabel").pack(side="left", padx=(0, 10))
        
        self.sim_combo = ttk.Combobox(control_group, state="readonly", width=30)
        self.sim_combo.pack(side="left", padx=(0, 15))
        
        ttk.Button(
            control_group, 
            text="🔍 Run Inference", 
            command=self.on_run_simulation, 
            style="Accent.TButton"
        ).pack(side="left", padx=(0, 15))

        ttk.Button(
            control_group, 
            text="📱 Export for Mobile", 
            command=self.on_export_mobile, 
            style="TButton"
        ).pack(side="left")

        # --- RESULTS AREA ---
        self.results_container = ttk.Frame(sim_frame, style="TFrame")
        self.results_container.pack(fill="both", expand=True)

        # 1. Multi-Horizon Panel (Main)
        self.forecast_panel = ForecastPanel(self.results_container)
        self.forecast_panel.pack(fill="both", expand=True)

        # 2. Legacy Display Frame (Hidden by default)
        self.legacy_frame = ttk.Frame(self.results_container, style="Surface.TFrame", padding=20)
        
        self.result_label = ttk.Label(
            self.legacy_frame,
            text="No Prediction",
            font=("Inter", 20, "bold"),
            style="Surface.TLabel"
        )
        self.result_label.pack(pady=10)
        
        self.result_detail = ttk.Label(
            self.legacy_frame,
            text="",
            style="Surface.TLabel"
        )
        self.result_detail.pack(pady=5)
        
        self.result_explanation = ttk.Label(
            self.legacy_frame,
            text="",
            style="Dim.TLabel",
            wraplength=600,
            justify="center"
        )
        self.result_explanation.pack(pady=15)

    def set_models(self, models: List[str]):
        """Updates the combobox list."""
        self.sim_combo['values'] = models
        if models and not self.sim_combo.get():
            self.sim_combo.current(0)

    def get_selected_model(self) -> str:
        """Returns currently selected symbol."""
        return self.sim_combo.get()

    def show_legacy_result(self, prob: float, label: int, symbol: str):
        """Displays results for legacy binary models."""
        self.forecast_panel.pack_forget()
        self.legacy_frame.pack(fill="both", expand=True)
        
        # Determine color and sentiment
        if prob >= 0.7:
            color = SUCCESS_COLOR
            sentiment = "BULLISH 📈"
        elif prob >= 0.5:
            color = WARNING_COLOR
            sentiment = "NEUTRAL ➡️"
        else:
            color = ERROR_COLOR
            sentiment = "BEARISH 📉"
            
        self.result_label.configure(text=f"{prob:.1%} Confidence", foreground=color)
        self.result_detail.configure(text=f"Symbol: {symbol} | Signal: {sentiment} | Pattern: {'HIKE' if label == 1 else 'NO HIKE'}")
        self.result_explanation.configure(
            text="⚠️ This is an older legacy model.\nRetrain for multi-horizon percentage forecasts (4H, 2D, 5D)."
        )

    def show_multi_result(self, result: Dict[str, Any]):
        """Displays results for new multi-horizon models."""
        self.legacy_frame.pack_forget()
        self.forecast_panel.pack(fill="both", expand=True)
        self.forecast_panel.update_forecasts(result)

    def reset(self):
        """Resets displays."""
        self.forecast_panel.reset()
        self.legacy_frame.pack_forget()
        self.forecast_panel.pack(fill="both", expand=True)
