"""
Stock Alert Mobile App - Main Entry Point
Protocol: Antigravity - Standalone Mobile Module

This is the main entry point for the Flet mobile application.
Uses tvdatafeed for direct TradingView data fetching.
"""

import flet as ft
from screens.watchlist import WatchlistScreen
from screens.alerts import AlertsScreen
from screens.settings import SettingsScreen


def main(page: ft.Page):
    """Main application entry point."""
    
    # Page Configuration
    page.title = "Stock Alert"
    page.theme_mode = ft.ThemeMode.DARK
    page.padding = 0
    page.bgcolor = "#0F172A"  # Midnight Indigo
    
    # Theme Configuration
    page.theme = ft.Theme(
        color_scheme=ft.ColorScheme(
            primary="#0EA5E9",      # Sky Blue
            secondary="#6366F1",    # Indigo
            surface="#1E293B",
            # background="#0F172A",
            error="#EF4444",
        ),
    )
    
    # Initialize screens
    watchlist_screen = WatchlistScreen(page)
    alerts_screen = AlertsScreen(page)
    settings_screen = SettingsScreen(page)
    
    # Content container for screen switching
    content = ft.Container(
        content=watchlist_screen.build(),
        expand=True,
    )
    
    def on_nav_change(e):
        """Handle navigation bar changes."""
        index = e.control.selected_index
        if index == 0:
            content.content = watchlist_screen.build()
        elif index == 1:
            content.content = alerts_screen.build()
        elif index == 2:
            content.content = settings_screen.build()
        page.update()
    
    # Navigation Bar
    nav_bar = ft.NavigationBar(
        bgcolor="#1E293B",
        selected_index=0,
        on_change=on_nav_change,
        destinations=[
            ft.NavigationDestination(
                icon=ft.Icons.LIST_ALT,
                selected_icon=ft.Icons.LIST_ALT,
                label="Watchlist",
            ),
            ft.NavigationDestination(
                icon=ft.Icons.NOTIFICATIONS_OUTLINED,
                selected_icon=ft.Icons.NOTIFICATIONS,
                label="Alerts",
            ),
            ft.NavigationDestination(
                icon=ft.Icons.SETTINGS_OUTLINED,
                selected_icon=ft.Icons.SETTINGS,
                label="Settings",
            ),
        ],
    )
    
    # Page Layout
    page.add(
        ft.Column(
            controls=[content, nav_bar],
            expand=True,
            spacing=0,
        )
    )


if __name__ == "__main__":
    ft.app(target=main)
