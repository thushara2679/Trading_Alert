"""
Purpose: Data & Training Tab Module for Stock Trainer.
Protocol: Antigravity - GUI Module
@param: parent widget, and callbacks for actions
@returns: TrainingTab instance
"""

import tkinter as tk
from tkinter import ttk, messagebox
import pandas as pd
from typing import List, Dict, Any, Optional, Callable

# Import styles for colors
from .styles import BG_BASE, BG_SURFACE, ACCENT_PRIMARY, TEXT_PRIMARY, TEXT_SECONDARY

class TrainingTab(ttk.Frame):
    """
    Dedicated frame for the Data & Training tab.
    Handles stock list management, CSV uploading, and data fetching status.
    """
    
    def __init__(self, parent, on_fetch_all: Callable, on_fetch_failed: Callable, 
                 on_train_all: Callable, on_save_credentials: Callable,
                 on_update_stock_list: Callable,
                 username_var: tk.StringVar, password_var: tk.StringVar):
        super().__init__(parent, style="TFrame")
        
        self.on_fetch_all = on_fetch_all
        self.on_fetch_failed = on_fetch_failed
        self.on_train_all = on_train_all
        self.on_save_credentials = on_save_credentials
        self.on_update_stock_list = on_update_stock_list
        self.username_var = username_var
        self.password_var = password_var
        
        self._build_ui()

    def _build_ui(self):
        """Constructs the tab UI."""
        # Credentials Panel (Card style)
        cred_frame = ttk.LabelFrame(self, text="TradingView Credentials (Optional)", style="TLabelframe", padding=15)
        cred_frame.pack(fill="x", padx=15, pady=(15, 0))
        
        input_inner = ttk.Frame(cred_frame, style="TFrame")
        input_inner.pack(fill="x")

        ttk.Label(input_inner, text="Username:", style="Dim.TLabel").pack(side="left", padx=(0, 5))
        ttk.Entry(input_inner, textvariable=self.username_var, width=15, style="TEntry").pack(side="left", padx=(0, 15))
        
        ttk.Label(input_inner, text="Password:", style="Dim.TLabel").pack(side="left", padx=(0, 5))
        ttk.Entry(input_inner, textvariable=self.password_var, show="*", width=15, style="TEntry").pack(side="left", padx=(0, 15))
        
        ttk.Button(input_inner, text="💾 Save", command=self.on_save_credentials, style="Accent.TButton").pack(side="left")
        
        # Control Panel
        control_frame = ttk.Frame(self, style="TFrame", padding=(15, 15))
        control_frame.pack(fill="x")
        
        # Buttons Group
        btn_group = ttk.Frame(control_frame, style="TFrame")
        btn_group.pack(side="left")

        buttons = [
            ("📂 Upload CSV", self._on_upload_csv),
            ("📡 Fetch Data", self.on_fetch_all),
            ("🔄 Retry Failed", self.on_fetch_failed),
            ("🚀 Train AI", self.on_train_all)
        ]
        
        for text, command in buttons:
            btn_style = "Accent.TButton" if "Train" in text else "TButton"
            btn = ttk.Button(btn_group, text=text, command=command, style=btn_style)
            btn.pack(side="left", padx=(0, 8))
        
        # Progress Bar (Modern thin style)
        self.progress_var = tk.DoubleVar(value=0)
        self.progress_bar = ttk.Progressbar(
            control_frame,
            variable=self.progress_var,
            maximum=100,
            length=180,
            style="Horizontal.TProgressbar"
        )
        self.progress_bar.pack(side="right", padx=10, pady=5)
        
        # Treeview for Stock List
        tree_container = ttk.Frame(self, style="Surface.TFrame", padding=1) # Dark border effect
        tree_container.pack(fill="both", expand=True, padx=15, pady=(0, 15))
        
        columns = ("Exchange", "Symbol", "Data Status", "Train Status")
        self.tree = ttk.Treeview(
            tree_container,
            columns=columns,
            show='headings',
            style="Treeview"
        )
        
        # Configure columns
        col_widths = {"Exchange": 100, "Symbol": 120, "Data Status": 200, "Train Status": 300}
        for col in columns:
            self.tree.heading(col, text=col.upper())
            self.tree.column(col, width=col_widths.get(col, 150), anchor="w")
        
        # Scrollbar (Minimalist)
        scrollbar = ttk.Scrollbar(tree_container, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=scrollbar.set)
        
        scrollbar.pack(side="right", fill="y")
        self.tree.pack(fill="both", expand=True)

    def _on_upload_csv(self):
        """Handles CSV upload and populates the treeview."""
        from tkinter import filedialog
        file_path = filedialog.askopenfilename(
            title="Select Stock List CSV",
            filetypes=[("CSV Files", "*.csv"), ("All Files", "*.*")]
        )
        
        if not file_path:
            return
        
        try:
            df = pd.read_csv(file_path)
            self.clear()
            
            # Clear local references (managed by app via callback if needed, 
            # but for now we update our own tree and return the list)
            new_stocks = []
            
            # 1. Single-column format: Header is the Exchange Name
            if len(df.columns) == 1:
                exchange_name = df.columns[0]
                for _, row in df.iterrows():
                    sym = str(row[exchange_name]).strip()
                    if not sym or sym.lower() == 'nan' or sym.lower() == exchange_name.lower():
                        continue
                        
                    item_id = self.tree.insert("", "end", values=(exchange_name, sym, "Pending", "Pending"))
                    new_stocks.append({"id": item_id, "exchange": exchange_name, "symbol": sym, "data_status": "Pending", "train_status": "Pending"})
            
            # 2. Multi-column format
            else:
                exch_col = self._find_column(df, ["exchange", "exch", "mkt"])
                sym_col = self._find_column(df, ["symbol", "ticker", "stock", "name"])
                
                if not sym_col:
                    messagebox.showerror("Error", "Could not identify Symbol column.")
                    return
                
                for _, row in df.iterrows():
                    exch = str(row[exch_col]) if exch_col else "Unknown"
                    sym = str(row[sym_col]).strip()
                    if not sym or sym.lower() == 'nan':
                        continue
                        
                    item_id = self.tree.insert("", "end", values=(exch, sym, "Pending", "Pending"))
                    new_stocks.append({"id": item_id, "exchange": exch, "symbol": sym, "data_status": "Pending", "train_status": "Pending"})
            
            # Notify parent app to update its stock_list via callback
            if self.on_update_stock_list:
                self.on_update_stock_list(new_stocks)
                
        except Exception as e:
            messagebox.showerror("Error", f"Failed to load CSV: {e}")

    def _find_column(self, df: pd.DataFrame, keywords: List[str]) -> Optional[str]:
        """Finds column matching keywords (case-insensitive)."""
        for col in df.columns:
            col_lower = col.lower()
            for kw in keywords:
                if kw in col_lower:
                    return col
        return None

    def clear(self):
        """Clears the treeview and reset progress."""
        self.tree.delete(*self.tree.get_children())
        self.progress_var.set(0)

    def set_progress(self, val: float):
        """Updates progress bar."""
        self.progress_var.set(val)

    def update_item_status(self, item_id: str, column: str, value: str):
        """Updates a specific cell in the treeview."""
        self.tree.set(item_id, column, value)
        
        # Add color visual feedback if possible via tags (optional flourish)
        if "Success" in value:
            self.tree.tag_configure("success", foreground="#10b981")
            self.tree.item(item_id, tags=("success",))
        elif "Failed" in value or "Error" in value:
            self.tree.tag_configure("error", foreground="#ef4444")
            self.tree.item(item_id, tags=("error",))
