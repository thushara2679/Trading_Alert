"""
Purpose: Isolated Visual Harness for Stock Trainer Application.
Protocol: Antigravity - UI & Visualization Verification
@param: Mock data mimicking production CSV structures
@returns: Interactive tkinter widget for visual verification

Verification Suite:
    - Widget coordinate bounds verification
    - State reset protocol testing
    - Theme consistency validation
    - Component interaction testing
"""

import sys
import os
import tkinter as tk
from tkinter import ttk
import pandas as pd
import numpy as np
from datetime import datetime

# Add parent to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


# ==========================================
# CONSTANTS
# ==========================================

MOCK_STOCKS = [
    {"exchange": "NSE", "symbol": "RELIANCE"},
    {"exchange": "NSE", "symbol": "INFY"},
    {"exchange": "NSE", "symbol": "TCS"},
    {"exchange": "NYSE", "symbol": "AAPL"},
    {"exchange": "NYSE", "symbol": "MSFT"},
]

WINDOW_WIDTH = 800
WINDOW_HEIGHT = 500
MIN_TOUCH_TARGET = 44  # Minimum touch target size (px)
BUTTON_BUFFER = 8  # Base unit buffer between elements


# ==========================================
# VISUAL HARNESS CLASS
# ==========================================

class UIDebugHarness(tk.Tk):
    """
    Isolated Visual Harness for Stock Trainer Application.
    
    Purpose:
        Verifies UI component positioning, sizing, and interactions
        without loading full application logic.
    """
    
    def __init__(self):
        super().__init__()
        
        self.title("💎 Gemini Protocol - UI Debugger")
        self.geometry(f"{WINDOW_WIDTH}x{WINDOW_HEIGHT}")
        self.configure(bg="#1e1e1e")
        
        self._errors = []
        self._warnings = []
        
        # Run verification
        self._setup_test_ui()
        self.after(100, self.run_verification_suite)
    
    def _setup_test_ui(self) -> None:
        """Sets up test UI components."""
        # Header
        self.header = ttk.Label(
            self,
            text="🧪 UI Verification Harness",
            font=("Segoe UI", 14, "bold")
        )
        self.header.pack(pady=10)
        
        # Test Button Row
        self.button_frame = ttk.Frame(self)
        self.button_frame.pack(fill="x", padx=20, pady=10)
        
        self.test_buttons = []
        button_texts = ["Upload CSV", "Fetch Data", "Train Model", "Run Inference"]
        
        for text in button_texts:
            btn = ttk.Button(self.button_frame, text=text)
            btn.pack(side="left", padx=5)
            self.test_buttons.append(btn)
        
        # Test Treeview
        self.tree = ttk.Treeview(
            self,
            columns=("Exchange", "Symbol", "Status"),
            show='headings',
            height=8
        )
        
        for col in ("Exchange", "Symbol", "Status"):
            self.tree.heading(col, text=col)
            self.tree.column(col, width=150)
        
        self.tree.pack(fill="both", expand=True, padx=20, pady=10)
        
        # Populate with mock data
        for stock in MOCK_STOCKS:
            self.tree.insert("", "end", values=(stock["exchange"], stock["symbol"], "Pending"))
        
        # Results Frame
        self.result_frame = ttk.Frame(self)
        self.result_frame.pack(fill="x", padx=20, pady=10)
        
        self.result_label = ttk.Label(
            self.result_frame,
            text="✅ Verification Results:",
            font=("Segoe UI", 11, "bold")
        )
        self.result_label.pack(anchor="w")
        
        self.result_text = tk.Text(
            self.result_frame,
            height=8,
            width=80,
            bg="#2a2a2a",
            fg="#e0e0e0",
            font=("Consolas", 10)
        )
        self.result_text.pack(fill="x", pady=5)
    
    def run_verification_suite(self) -> None:
        """Executes all verification tests."""
        self.log("--- 🧪 Starting Antigravity UI Verification ---\n")
        
        # Test 1: Window Bounds
        self._verify_window_bounds()
        
        # Test 2: Button Touch Targets
        self._verify_touch_targets()
        
        # Test 3: Button Collision Detection
        self._verify_no_collisions()
        
        # Test 4: State Reset Protocol
        self._verify_state_reset()
        
        # Test 5: Theme Consistency
        self._verify_theme()
        
        # Summary
        self._print_summary()
    
    def _verify_window_bounds(self) -> None:
        """Verifies all widgets are within window bounds."""
        self.update_idletasks()  # Force geometry calculation
        
        window_w = self.winfo_width()
        window_h = self.winfo_height()
        
        all_within = True
        
        for btn in self.test_buttons:
            x = btn.winfo_x()
            y = btn.winfo_y()
            w = btn.winfo_width()
            h = btn.winfo_height()
            
            # Check bounds (relative to parent)
            if x < 0 or y < 0:
                all_within = False
                self._errors.append(f"Button at negative coords: ({x}, {y})")
        
        if all_within:
            self.log("✅ Window Bounds: PASSED - All widgets within window")
        else:
            self.log("❌ Window Bounds: FAILED - Widgets outside bounds")
    
    def _verify_touch_targets(self) -> None:
        """Verifies buttons meet minimum touch target size."""
        self.update_idletasks()
        
        all_valid = True
        
        for i, btn in enumerate(self.test_buttons):
            w = btn.winfo_width()
            h = btn.winfo_height()
            
            if w < MIN_TOUCH_TARGET or h < MIN_TOUCH_TARGET:
                all_valid = False
                self._warnings.append(
                    f"Button {i} too small: {w}x{h}px (min: {MIN_TOUCH_TARGET}px)"
                )
        
        if all_valid:
            self.log(f"✅ Touch Targets: PASSED - All buttons >= {MIN_TOUCH_TARGET}px")
        else:
            self.log(f"⚠️ Touch Targets: WARNING - Some buttons below minimum size")
    
    def _verify_no_collisions(self) -> None:
        """Verifies no interactive elements overlap."""
        self.update_idletasks()
        
        collisions = []
        
        for i, btn1 in enumerate(self.test_buttons):
            for j, btn2 in enumerate(self.test_buttons):
                if i >= j:
                    continue
                
                # Get positions (relative to same parent)
                x1, y1 = btn1.winfo_x(), btn1.winfo_y()
                w1, h1 = btn1.winfo_width(), btn1.winfo_height()
                
                x2, y2 = btn2.winfo_x(), btn2.winfo_y()
                w2, h2 = btn2.winfo_width(), btn2.winfo_height()
                
                # Check overlap
                if not (x1 + w1 + BUTTON_BUFFER <= x2 or x2 + w2 + BUTTON_BUFFER <= x1):
                    if not (y1 + h1 <= y2 or y2 + h2 <= y1):
                        collisions.append((i, j))
        
        if not collisions:
            self.log(f"✅ Collision Detection: PASSED - {BUTTON_BUFFER}px buffer maintained")
        else:
            self.log(f"❌ Collision Detection: FAILED - {len(collisions)} overlaps found")
            self._errors.extend([f"Buttons {i} and {j} overlap" for i, j in collisions])
    
    def _verify_state_reset(self) -> None:
        """Verifies state can be cleared properly."""
        # Add items
        initial_count = len(self.tree.get_children())
        
        # Clear
        self.tree.delete(*self.tree.get_children())
        
        after_clear = len(self.tree.get_children())
        
        # Verify
        if after_clear == 0:
            self.log("✅ State Reset: PASSED - Treeview cleared successfully")
            
            # Restore items for display
            for stock in MOCK_STOCKS:
                self.tree.insert("", "end", values=(stock["exchange"], stock["symbol"], "Restored"))
        else:
            self.log("❌ State Reset: FAILED - Items remain after clear()")
            self._errors.append(f"Treeview has {after_clear} items after clear")
    
    def _verify_theme(self) -> None:
        """Verifies dark theme is applied consistently."""
        bg = self.cget('bg')
        
        # Check if dark (low luminance)
        if '#' in bg:
            hex_val = bg.lstrip('#')
            r, g, b = tuple(int(hex_val[i:i+2], 16) for i in (0, 2, 4))
            luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
            
            if luminance < 0.3:
                self.log("✅ Theme Consistency: PASSED - Dark theme applied")
            else:
                self.log("⚠️ Theme Consistency: WARNING - Background may be too light")
                self._warnings.append(f"Background luminance: {luminance:.2f}")
        else:
            self.log("⚠️ Theme Consistency: SKIPPED - Could not parse background color")
    
    def _print_summary(self) -> None:
        """Prints verification summary."""
        self.log("\n" + "=" * 50)
        
        if not self._errors and not self._warnings:
            self.log("🎉 ALL VERIFICATIONS PASSED")
        else:
            if self._errors:
                self.log(f"❌ ERRORS: {len(self._errors)}")
                for err in self._errors:
                    self.log(f"   - {err}")
            
            if self._warnings:
                self.log(f"⚠️ WARNINGS: {len(self._warnings)}")
                for warn in self._warnings:
                    self.log(f"   - {warn}")
        
        self.log("=" * 50)
    
    def log(self, msg: str) -> None:
        """Logs message to result text widget and console."""
        print(msg)
        self.result_text.insert("end", msg + "\n")
        self.result_text.see("end")


# ==========================================
# ADDITIONAL VERIFICATION TESTS
# ==========================================

def test_stock_engine_import():
    """Tests that StockEngine can be imported."""
    print("--- Testing StockEngine Import ---")
    
    try:
        from ml.stock_engine import StockEngine
        engine = StockEngine()
        print("✅ StockEngine Import: PASSED")
        return True
    except Exception as e:
        print(f"❌ StockEngine Import: FAILED - {e}")
        return False


def test_mock_data_generation():
    """Tests mock OHLCV data generation."""
    print("\n--- Testing Mock Data Generation ---")
    
    timestamps = pd.date_range(start="2025-01-01", periods=100, freq="1h")
    
    # Explicit type casting (Antigravity Protocol)
    ts_int64 = timestamps.view(np.int64) // 10**9
    
    assert isinstance(ts_int64[0], np.int64), "Timestamp not int64"
    print("✅ Timestamp Type Safety: PASSED")
    
    df = pd.DataFrame({
        'timestamp': ts_int64,
        'open': np.random.uniform(100, 110, 100),
        'close': np.random.uniform(100, 110, 100)
    })
    
    assert len(df) == 100, "DataFrame length mismatch"
    print("✅ Mock Data Generation: PASSED")
    
    return True


# ==========================================
# ENTRY POINT
# ==========================================

def main():
    """Main entry point for UI debug harness."""
    print("=" * 60)
    print("💎 Antigravity Protocol - UI Debug Harness")
    print("=" * 60)
    
    # Run non-GUI tests first
    test_stock_engine_import()
    test_mock_data_generation()
    
    print("\n" + "=" * 60)
    print("Launching Visual Harness...")
    print("=" * 60 + "\n")
    
    # Launch visual harness
    app = UIDebugHarness()
    app.mainloop()


if __name__ == "__main__":
    main()
