"""
Purpose: XGBoost Stock Trainer & ONNX Converter GUI (Refactored Orchestrator)
Protocol: Antigravity - Main Application
@returns: Main application window using modern Midnight Indigo theme
"""

import tkinter as tk
from tkinter import ttk, messagebox
import os
import sys
import threading
import queue
from typing import List, Dict, Any, Optional

# Add project root to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Import internal modules
from ml.stock_engine import StockEngine
from gui.styles import configure_styles, BG_BASE, ACCENT_PRIMARY, TEXT_SECONDARY
from gui.training_tab import TrainingTab
from gui.simulation_tab import SimulationTab

APP_TITLE = "XGBoost Stock Trainer"
APP_GEOMETRY = "1100x750"

class StockTrainerApp(tk.Tk):
    """Refactored orchestrator for the Stock Trainer application."""
    
    def __init__(self):
        super().__init__()
        self.title("💎 " + APP_TITLE)
        self.geometry(APP_GEOMETRY)
        self.configure(bg=BG_BASE)
        
        # Core State
        self.engine = StockEngine()
        self.stock_list: List[Dict[str, Any]] = []
        self.message_queue: queue.Queue = queue.Queue()
        self.username_var = tk.StringVar()
        self.password_var = tk.StringVar()
        
        # Setup Theme & UI
        configure_styles()
        self._setup_ui()
        
        # Start background processor
        self.after(100, self._process_queue)

    def _setup_ui(self):
        """Constructs the high-level UI structure."""
        main_container = ttk.Frame(self, style="TFrame")
        main_container.pack(fill="both", expand=True, padx=10, pady=10)
        
        # Header
        header = ttk.Frame(main_container, style="TFrame")
        header.pack(fill="x", pady=(0, 10))
        ttk.Label(header, text="XGBOOST STOCK TRAINER", style="Header.TLabel").pack(side="left")
        ttk.Label(header, text="v1.2 | Antigravity Protocol", style="Dim.TLabel").pack(side="right", pady=(10, 0))

        # Tab Control
        self.tab_control = ttk.Notebook(main_container)
        self.tab_control.pack(fill="both", expand=True)

        # Tabs
        self.train_tab = TrainingTab(
            self.tab_control, 
            on_fetch_all=self._on_fetch_all,
            on_fetch_failed=self._on_fetch_failed,
            on_train_all=self._on_train_all,
            on_save_credentials=self._on_save_credentials,
            on_update_stock_list=self.update_stock_list,
            on_bulk_export=self._on_bulk_export_all,
            username_var=self.username_var,
            password_var=self.password_var
        )
        self.sim_tab = SimulationTab(
            self.tab_control,
            on_run_simulation=self._on_run_simulation,
            refresh_models_callback=self._refresh_model_list,
            on_export_mobile=self._on_export_mobile
        )
        
        self.tab_control.add(self.train_tab, text=" 📊 DATA & TRAINING ")
        self.tab_control.add(self.sim_tab, text=" 🎯 SIMULATION ")
        self.tab_control.bind("<<NotebookTabChanged>>", self._on_tab_changed)

        # Status Bar
        self.status_var = tk.StringVar(value="System Ready")
        sb = ttk.Label(main_container, textvariable=self.status_var, style="Dim.TLabel", anchor="w", padding=(10, 5))
        sb.pack(fill="x", pady=(10, 0))

    def update_stock_list(self, new_stocks: List[Dict[str, Any]]):
        """Callback from TrainingTab when a CSV is uploaded."""
        self.stock_list = new_stocks
        self._set_status(f"✅ Loaded {len(self.stock_list)} stocks")

    def _on_save_credentials(self):
        """Saves credentials to engine."""
        u, p = self.username_var.get().strip(), self.password_var.get().strip()
        self.engine.set_credentials(u if u else None, p if p else None)
        messagebox.showinfo("Credentials", "Credentials updated for this session.")

    def _on_fetch_all(self): self._run_thread(self._thread_fetch, False)
    def _on_fetch_failed(self): self._run_thread(self._thread_fetch, True)
    def _on_train_all(self): self._run_thread(self._thread_train)
    def _on_bulk_export_all(self): self._run_thread(self._thread_bulk_export)

    def _run_thread(self, target, *args):
        """Helper to run background tasks."""
        threading.Thread(target=target, args=args, daemon=True).start()

    def _on_tab_changed(self, event):
        if self.tab_control.index(self.tab_control.select()) == 1:
            self._refresh_model_list()

    def _on_run_simulation(self):
        symbol = self.sim_tab.get_selected_model()
        if not symbol: return
        self.sim_tab.reset()
        self.update_idletasks()
        
        success, result = self.engine.run_inference(symbol)
        if success:
            if result.get("model_type") == "multi_prob":
                self.sim_tab.show_multi_result(result)
            elif result.get("model_type") == "legacy_binary":
                self.sim_tab.show_legacy_result(result.get("prob_hike", 0), result.get("predicted_label", 0), symbol)
            else:
                self.sim_tab.forecast_panel.show_error("Unknown model type")
        else:
            self.sim_tab.forecast_panel.show_error(result.get("error", "Error"))

    def _on_export_mobile(self):
        symbol = self.sim_tab.get_selected_model()
        if not symbol: return
        
        try:
            pkg_path = self.engine.export_mobile_package(symbol)
            messagebox.showinfo("Export Success", f"Mobile package exported to:\n{pkg_path}")
            # Open folder
            os.startfile(pkg_path)
        except Exception as e:
            messagebox.showerror("Export Failed", str(e))

    # ------------------------------------------
    # BACKGROUND LOGIC
    # ------------------------------------------

    def _thread_fetch(self, only_failed: bool):
        to_process = [s for s in self.stock_list if not (only_failed and s["data_status"] == "Success")]
        
        if not to_process:
            self._post_msg("status", "⚠️ No stocks to fetch. Load CSV first.")
            return

        import concurrent.futures
        max_workers = 4
        total = len(to_process)
        completed_count = 0
        lock = threading.Lock()

        self._post_msg("status", f"🚀 Starting Parallel Fetch ({max_workers} threads)...")

        def _fetch_worker(item):
            nonlocal completed_count
            
            # Update per-item status to specific thread activity
            self._post_msg("tree", id=item["id"], col="Data Status", val="⏳ Queued...")
            
            # Fetch
            success, msg = self.engine.fetch_data(item["symbol"], item["exchange"])
            
            # Update Item UI
            status_val = "Success" if success else "Failed"
            result_msg = "Success" if success else f"Failed: {msg}"
            item["data_status"] = status_val
            
            self._post_msg("tree", id=item["id"], col="Data Status", val=result_msg)
            
            # Update Progress (Thread-Safe)
            with lock:
                completed_count += 1
                pct = (completed_count / total) * 100
                self._post_msg("progress", val=pct)
                self._post_msg("status", f"📡 Fetching: {completed_count}/{total} completed")

        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = [executor.submit(_fetch_worker, item) for item in to_process]
            concurrent.futures.wait(futures)
        
        self._post_msg("status", "✅ Parallel Fetch Complete")
        self._post_msg("progress", val=0)

    def _thread_train(self):
        to_train = [s for s in self.stock_list if s["data_status"] == "Success"]
        for i, item in enumerate(to_train):
            self._post_msg("status", f"🚀 Training {i+1}/{len(to_train)}: {item['symbol']}")
            self._post_msg("tree", id=item["id"], col="Train Status", val="Training...")
            
            success, msg = self.engine.train_model(item["symbol"])
            item["train_status"] = "Success" if success else "Failed"
            self._post_msg("tree", id=item["id"], col="Train Status", val=msg if success else f"Failed: {msg}")
            self._post_msg("progress", val=((i+1)/len(to_train))*100)
            
            
        self._post_msg("status", "✅ Training Complete")
        self._post_msg("progress", val=0)

    def _thread_bulk_export(self):
        """Background worker for bulk exporting all models."""
        self._post_msg("status", "📦 Preparing Bulk Export...")
        self._post_msg("progress", val=10)
        
        try:
            # Reuses the engine's export_all logic which handles loops
            # Note: For finer progress, we could loop here, but engine method is atomic for now.
            # We'll just show "Busy" status.
            
            export_dir = self.engine.export_all_models()
            
            self._post_msg("status", f"✅ Export Complete: {os.path.basename(export_dir)}")
            self._post_msg("progress", val=100)
            
            # Show location on main thread (via queue if we had a generic msg handler, 
            # but for now we let user know via status bar. 
            # Ideally we'd pop a messagebox but can't from thread safely without queue.)
            # We'll rely on the user checking the folder manually or we can open it.
            os.startfile(export_dir)
            
        except Exception as e:
            self._post_msg("status", f"❌ Export Failed: {str(e)}")
        finally:
            self._post_msg("progress", val=0)

    def _post_msg(self, msg_type, msg=None, id=None, col=None, val=None):
        self.message_queue.put({"type": msg_type, "msg": msg, "id": id, "col": col, "val": val})

    def _process_queue(self):
        try:
            while True:
                m = self.message_queue.get_nowait()
                if m["type"] == "tree": self.train_tab.update_item_status(m["id"], m["col"], m["val"])
                elif m["type"] == "status": self._set_status(m["msg"])
                elif m["type"] == "progress": self.train_tab.set_progress(m["val"])
        except queue.Empty: pass
        finally: self.after(100, self._process_queue)

    def _set_status(self, msg): self.status_var.set(msg)
    def _refresh_model_list(self): self.sim_tab.set_models(self.engine.get_trained_models())

if __name__ == "__main__":
    StockTrainerApp().mainloop()
