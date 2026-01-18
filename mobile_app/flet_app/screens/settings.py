"""
Settings Screen - Configuration
Protocol: Antigravity - Standalone Mobile Module

App settings, Model Manager, and signal threshold configuration.
"""

import flet as ft
from flet import colors, icons
from typing import List

from services.model_inference import ModelInference


# Compatibility layer 
if not hasattr(ft, 'Colors'):
    ft.Colors = colors
if not hasattr(ft, 'Icons'):
    ft.Icons = icons


class SettingsScreen:
    """Settings screen with Model Manager and configuration."""
    
    def __init__(self, page: ft.Page):
        self.page = page
        self.model_inference = ModelInference()
        from services.data_fetcher import DataFetcher
        self.data_fetcher = DataFetcher()
        self.model_list = ft.Column(spacing=8)
        
        # Diagnostics
        self.diag_status = ft.Column(spacing=8)
        self.test_output = ft.Text("No test run yet", size=12, font_family="monospace")
        self.test_symbol_input = ft.TextField(label="Symbol", width=100, height=40, text_size=12)
        
        # Config
        from services.config_manager import ConfigManager
        self.config = ConfigManager()

    def build(self) -> ft.Container:
        """Build the settings screen UI."""
        self._refresh_model_list()
        
        return ft.Container(
            content=ft.Column([
                # Header
                ft.Container(
                    content=ft.Text("⚙️ Settings", size=24, weight=ft.FontWeight.BOLD),
                    padding=16,
                ),
                
                # Tabs
                ft.Tabs(
                    selected_index=0,
                    animation_duration=300,
                    tabs=[
                        ft.Tab(
                            text="General",
                            icon=ft.Icons.SETTINGS,
                            content=self._build_general_tab(),
                        ),
                        ft.Tab(
                            text="Diagnostics",
                            icon=ft.Icons.BUG_REPORT,
                            content=self._build_diagnostics_tab(),
                        ),
                    ],
                    expand=True,
                ),
            ], expand=True),
            expand=True,
        )

    def _build_general_tab(self) -> ft.Container:
        """Build General settings tab."""
        return ft.Container(
            content=ft.ListView(
                controls=[
                    # Model Manager
                    self._build_section("📦 Model Manager", [
                        ft.Container(
                            content=ft.Row([
                                ft.ElevatedButton(
                                    "Import Models",
                                    icon=ft.Icons.FOLDER_OPEN,
                                    on_click=self._import_models,
                                ),
                                ft.ElevatedButton(
                                    "Refresh",
                                    icon=ft.Icons.REFRESH,
                                    on_click=lambda _: self._refresh_model_list(),
                                ),
                            ], spacing=8),
                            padding=ft.padding.only(bottom=8),
                        ),
                        self.model_list,
                    ]),
                    
                    # Signal Thresholds
                    self._build_thresholds_section(),
                    
                    # Data Settings
                    self._build_section("📡 Data Settings", [
                        self._build_setting_tile(
                            "Default Exchange",
                            "For new watchlist items",
                            ft.Text("CSELK", color=ft.Colors.GREY_400),
                        ),
                        self._build_setting_tile(
                            "Data Validity",
                            "Skip re-fetch if data is newer than",
                            ft.Text("15 min", color=ft.Colors.GREY_400),
                        ),
                        self._build_setting_tile(
                            "Bars to Fetch",
                            "Historical bars per symbol",
                            ft.Text("50", color=ft.Colors.GREY_400),
                        ),
                    ]),
                    
                    # About
                    self._build_section("ℹ️ About", [
                        self._build_setting_tile(
                            "Version",
                            "Stock Alert Mobile App",
                            ft.Text("1.0.1", color=ft.Colors.GREY_400),
                        ),
                        self._build_setting_tile(
                            "GitHub",
                            "Source code",
                            ft.TextButton("View Repo", height=30),
                        ),
                    ]),
                ],
                padding=16,
            ),
        )

    def _build_diagnostics_tab(self) -> ft.Container:
        """Build Diagnostics tab."""
        # Data Status
        data_status_rows = []
        if not self.data_fetcher.fetch_timestamps:
            data_status_rows.append(ft.Text("No data fetched yet", italic=True, color=ft.Colors.GREY_500))
        else:
            for symbol, ts in list(self.data_fetcher.fetch_timestamps.items())[-5:]:  # Show last 5
                failed = symbol in self.data_fetcher.failed_symbols
                status_icon = "❌" if failed else "✅"
                data_status_rows.append(
                    ft.Row([
                        ft.Text(f"{status_icon} {symbol}", weight="bold"),
                        ft.Text(ts.strftime("%H:%M:%S"), font_family="monospace"),
                    ], alignment="spaceBetween")
                )
        
        return ft.Container(
            content=ft.ListView(
                controls=[
                    # Data Verification
                    self._build_section("📡 Data Status (Last 5)", data_status_rows),
                    
                    # Model Tester
                    self._build_section("🧪 Model Tester", [
                        ft.Row([
                            self.test_symbol_input,
                            ft.ElevatedButton("Test Model", on_click=self._run_model_test),
                        ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                        ft.Container(
                            content=self.test_output,
                            bgcolor="#0F172A",
                            padding=10,
                            border_radius=6,
                            margin=ft.margin.only(top=10),
                        )
                    ]),
                ],
                padding=16,
            ),
        )

    def _build_thresholds_section(self) -> ft.Container:
        """Build collapsible threshold configuration."""
        thresholds = self.config.get_thresholds()
        
        def on_change(key, val):
            self.config.set("thresholds", key, float(val))
            
        return self._build_section("🎯 Signal Thresholds", [
            self._build_slider("COMBO 4H", "Min 4H%", "COMBO_4H", thresholds),
            self._build_slider("COMBO 5D", "Min 5D%", "COMBO_5D", thresholds),
            self._build_slider("SCALP 4H", "Min 4H%", "SCALP_4H", thresholds),
            self._build_slider("WATCH 5D", "Min 5D%", "WATCH_5D", thresholds),
            self._build_slider("AVOID", "Max All%", "AVOID", thresholds),
        ])

    def _build_slider(self, label, sub, key, current):
        val = current.get(key, 0.0)
        return ft.Container(
            content=ft.Column([
                ft.Row([
                    ft.Text(f"{label}", weight="bold", size=13),
                    ft.Text(f"{val:.0f}%", color=ft.Colors.BLUE_400, weight="bold"),
                ], alignment="spaceBetween"),
                ft.Slider(
                    min=0, max=100, divisions=100, 
                    value=val, 
                    label="{value}%",
                    on_change_end=lambda e: self.config.set("thresholds", key, e.control.value)
                ),
            ], spacing=0),
            padding=ft.padding.symmetric(horizontal=16, vertical=4)
        )

    def _run_model_test(self, e):
        """Run diagnostics test."""
        symbol = self.test_symbol_input.value
        if not symbol:
            return
            
        self.test_output.value = "Running inference..."
        self.test_output.update()
        
        res = self.model_inference.test_inference(symbol)
        
        import json
        self.test_output.value = json.dumps(res, indent=2, default=str)
        self.test_output.update()
    
    def _refresh_model_list(self):
        """Refresh the model list display."""
        self.model_list.controls.clear()
        
        symbols = self.model_inference.list_available_symbols()
        
        if not symbols:
            self.model_list.controls.append(
                ft.Container(
                    content=ft.Column([
                        ft.Icon(ft.Icons.FOLDER_OFF, size=32, color=ft.Colors.GREY_600),
                        ft.Text("No models found", color=ft.Colors.GREY_500),
                        ft.Text("Import models from PC app", size=12, color=ft.Colors.GREY_600),
                    ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=4),
                    padding=16,
                    alignment=ft.alignment.center,
                )
            )
        else:
            for symbol in symbols:
                status = self.model_inference.get_model_status(symbol)
                self.model_list.controls.append(self._build_model_tile(symbol, status))
        
        if self.page:
            try:
                self.model_list.update()
            except:
                pass
    
    def _build_model_tile(self, symbol: str, status: dict) -> ft.Container:
        """Build a model status tile."""
        loaded_count = sum(1 for s in status.values() if s == "loaded")
        available_count = sum(1 for s in status.values() if s in ["loaded", "available"])
        
        if loaded_count == 3:
            icon = ft.Icon(ft.Icons.CHECK_CIRCLE, color=ft.Colors.GREEN)
            status_text = "3 models loaded"
        elif available_count > 0:
            icon = ft.Icon(ft.Icons.WARNING, color=ft.Colors.ORANGE)
            status_text = f"{loaded_count}/3 loaded"
        else:
            icon = ft.Icon(ft.Icons.ERROR, color=ft.Colors.RED)
            status_text = "No models"
        
        return ft.Container(
            content=ft.Row([
                icon,
                ft.Column([
                    ft.Text(symbol, weight=ft.FontWeight.BOLD),
                    ft.Text(status_text, size=11, color=ft.Colors.GREY_500),
                ], spacing=2, expand=True),
                ft.IconButton(
                    icon=ft.Icons.DELETE_OUTLINE,
                    icon_color=ft.Colors.RED_400,
                    tooltip="Delete models",
                    on_click=lambda e, s=symbol: self._delete_model(s),
                ),
            ]),
            bgcolor="#1E293B",
            padding=12,
            border_radius=8,
        )
    
    async def _import_models(self, e):
        """Import models from folder picker."""
        def on_result(result):
            if result.path:
                import shutil
                import os
                
                src = result.path
                dest = self.model_inference.models_dir
                
                count = 0
                errors = 0
                
                try:
                    for name in os.listdir(src):
                        if name.endswith("_pkg"):
                            src_path = os.path.join(src, name)
                            
                            # Standardize naming: CCS.N0000_pkg -> CCS_N0000_pkg
                            safe_name = name.replace(".", "_")
                            dest_path = os.path.join(dest, safe_name)
                            
                            if os.path.isdir(src_path):
                                if os.path.exists(dest_path):
                                    shutil.rmtree(dest_path)
                                shutil.copytree(src_path, dest_path)
                                count += 1
                except Exception as ex:
                    print(f"Import error: {ex}")
                    errors += 1
                
                self._refresh_model_list()
                
                msg = f"✅ Imported {count} packages"
                if errors > 0:
                    msg += " (some errors occurred)"
                    
                self.page.snack_bar = ft.SnackBar(
                    content=ft.Text(msg),
                    bgcolor="#15803d" if errors == 0 else "#b91c1c"
                )
                self.page.snack_bar.open = True
                self.page.update()
        
        picker = ft.FilePicker(on_result=on_result)
        self.page.overlay.append(picker)
        self.page.update()
        picker.get_directory_path()
    
    def _delete_model(self, symbol: str):
        """Delete model package for a symbol."""
        success = self.model_inference.delete_model_package(symbol)
        self._refresh_model_list()
        
        if success:
            self.page.snack_bar = ft.SnackBar(
                content=ft.Text(f"🗑️ Deleted models for {symbol}"),
            )
        else:
            self.page.snack_bar = ft.SnackBar(
                content=ft.Text(f"❌ Failed to delete {symbol}"),
                bgcolor="#b91c1c"
            )
        self.page.snack_bar.open = True
        self.page.update()
    
    def _build_section(self, title: str, tiles: list) -> ft.Container:
        """Build a settings section."""
        return ft.Container(
            content=ft.Column([
                ft.Text(title, weight=ft.FontWeight.BOLD, color=ft.Colors.GREY_400),
                ft.Container(
                    content=ft.Column(tiles, spacing=0),
                    bgcolor="#1E293B",
                    border_radius=10,
                ),
            ], spacing=8),
            margin=ft.margin.only(bottom=16),
        )
    
    def _build_setting_tile(
        self,
        title: str,
        subtitle: str,
        trailing: ft.Control,
    ) -> ft.Container:
        """Build a single setting tile."""
        return ft.Container(
            content=ft.Row([
                ft.Column([
                    ft.Text(title),
                    ft.Text(subtitle, size=12, color=ft.Colors.GREY_500),
                ], spacing=2, expand=True),
                trailing,
            ]),
            padding=16,
        )
        self.model_list.controls.clear()
        
        symbols = self.model_inference.list_available_symbols()
        
        if not symbols:
            self.model_list.controls.append(
                ft.Container(
                    content=ft.Column([
                        ft.Icon(ft.Icons.FOLDER_OFF, size=32, color=ft.Colors.GREY_600),
                        ft.Text("No models found", color=ft.Colors.GREY_500),
                        ft.Text("Import models from PC app", size=12, color=ft.Colors.GREY_600),
                    ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=4),
                    padding=16,
                    alignment=ft.alignment.center,
                )
            )
        else:
            for symbol in symbols:
                status = self.model_inference.get_model_status(symbol)
                self.model_list.controls.append(self._build_model_tile(symbol, status))
        
        if self.page:
            try:
                self.model_list.update()
            except:
                pass
    
    def _build_model_tile(self, symbol: str, status: dict) -> ft.Container:
        """Build a model status tile."""
        loaded_count = sum(1 for s in status.values() if s == "loaded")
        available_count = sum(1 for s in status.values() if s in ["loaded", "available"])
        
        if loaded_count == 3:
            icon = ft.Icon(ft.Icons.CHECK_CIRCLE, color=ft.Colors.GREEN)
            status_text = "3 models loaded"
        elif available_count > 0:
            icon = ft.Icon(ft.Icons.WARNING, color=ft.Colors.ORANGE)
            status_text = f"{loaded_count}/3 loaded"
        else:
            icon = ft.Icon(ft.Icons.ERROR, color=ft.Colors.RED)
            status_text = "No models"
        
        return ft.Container(
            content=ft.Row([
                icon,
                ft.Column([
                    ft.Text(symbol, weight=ft.FontWeight.BOLD),
                    ft.Text(status_text, size=11, color=ft.Colors.GREY_500),
                ], spacing=2, expand=True),
                ft.IconButton(
                    icon=ft.Icons.DELETE_OUTLINE,
                    icon_color=ft.Colors.RED_400,
                    tooltip="Delete models",
                    on_click=lambda e, s=symbol: self._delete_model(s),
                ),
            ]),
            bgcolor="#1E293B",
            padding=12,
            border_radius=8,
        )
    
    async def _import_models(self, e):
        """Import models from folder picker."""
        def on_result(result):
            if result.path:
                import shutil
                import os
                
                src = result.path
                dest = self.model_inference.models_dir
                
                count = 0
                errors = 0
                
                try:
                    for name in os.listdir(src):
                        if name.endswith("_pkg"):
                            src_path = os.path.join(src, name)
                            
                            # Standardize naming: CCS.N0000_pkg -> CCS_N0000_pkg
                            safe_name = name.replace(".", "_")
                            dest_path = os.path.join(dest, safe_name)
                            
                            if os.path.isdir(src_path):
                                if os.path.exists(dest_path):
                                    shutil.rmtree(dest_path)
                                shutil.copytree(src_path, dest_path)
                                count += 1
                except Exception as ex:
                    print(f"Import error: {ex}")
                    errors += 1
                
                self._refresh_model_list()
                
                msg = f"✅ Imported {count} packages"
                if errors > 0:
                    msg += " (some errors occurred)"
                    
                self.page.snack_bar = ft.SnackBar(
                    content=ft.Text(msg),
                    bgcolor="#15803d" if errors == 0 else "#b91c1c"
                )
                self.page.snack_bar.open = True
                self.page.update()
        
        picker = ft.FilePicker(on_result=on_result)
        self.page.overlay.append(picker)
        self.page.update()
        picker.get_directory_path()
    
    def _delete_model(self, symbol: str):
        """Delete model package for a symbol."""
        success = self.model_inference.delete_model_package(symbol)
        self._refresh_model_list()
        
        if success:
            self.page.snack_bar = ft.SnackBar(
                content=ft.Text(f"🗑️ Deleted models for {symbol}"),
            )
        else:
            self.page.snack_bar = ft.SnackBar(
                content=ft.Text(f"❌ Failed to delete {symbol}"),
                bgcolor="#b91c1c"
            )
        self.page.snack_bar.open = True
        self.page.update()
    
    def _build_section(self, title: str, tiles: list) -> ft.Container:
        """Build a settings section."""
        return ft.Container(
            content=ft.Column([
                ft.Text(title, weight=ft.FontWeight.BOLD, color=ft.Colors.GREY_400),
                ft.Container(
                    content=ft.Column(tiles, spacing=0),
                    bgcolor="#1E293B",
                    border_radius=10,
                ),
            ], spacing=8),
            margin=ft.margin.only(bottom=16),
        )
    
    def _build_setting_tile(
        self,
        title: str,
        subtitle: str,
        trailing: ft.Control,
    ) -> ft.Container:
        """Build a single setting tile."""
        return ft.Container(
            content=ft.Row([
                ft.Column([
                    ft.Text(title),
                    ft.Text(subtitle, size=12, color=ft.Colors.GREY_500),
                ], spacing=2, expand=True),
                trailing,
            ]),
            padding=16,
        )
