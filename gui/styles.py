"""
Purpose: Midnight Indigo Theme and Style Configuration for Stock Trainer.
Protocol: Antigravity - GUI Module
@param: ttk.Style object to configure
@returns: None (configures styles in-place)
"""

import tkinter as tk
from tkinter import ttk

# ==========================================
# COLOR PALETTE (Midnight Indigo)
# ==========================================

BG_BASE = "#0f172a"      # Deep Midnight
BG_SURFACE = "#1e293b"   # Slate Indigo
BG_HOVER = "#334155"     # Lighter Slate for hover

ACCENT_PRIMARY = "#0ea5e9"    # Sky Blue
ACCENT_SECONDARY = "#6366f1"  # Indigo Glow

TEXT_PRIMARY = "#f8fafc"      # Slate White
TEXT_SECONDARY = "#94a3b8"    # Dim Slate

SUCCESS_COLOR = "#10b981"     # Emerald Green
ERROR_COLOR = "#ef4444"       # Rose Red
WARNING_COLOR = "#f59e0b"     # Amber Orange

# ==========================================
# STYLE CONFIGURATION
# ==========================================

def configure_styles():
    """Configures ttk styles for a modern Midnight Indigo theme."""
    style = ttk.Style()
    
    # Try to use clam theme as base for better consistency across platforms
    try:
        style.theme_use('clam')
    except tk.TclError:
        pass
    
    # --- TFrame ---
    style.configure("TFrame", background=BG_BASE)
    style.configure("Surface.TFrame", background=BG_SURFACE)
    
    # --- TLabel ---
    style.configure("TLabel", background=BG_BASE, foreground=TEXT_PRIMARY, font=("Inter", 10))
    style.configure("Surface.TLabel", background=BG_SURFACE, foreground=TEXT_PRIMARY, font=("Inter", 10))
    style.configure("Header.TLabel", background=BG_BASE, foreground=ACCENT_PRIMARY, font=("Inter", 18, "bold"))
    style.configure("Subheader.TLabel", background=BG_BASE, foreground=ACCENT_SECONDARY, font=("Inter", 12, "bold"))
    style.configure("Dim.TLabel", background=BG_BASE, foreground=TEXT_SECONDARY, font=("Inter", 9))
    
    # --- TButton ---
    style.configure(
        "TButton",
        background=BG_SURFACE,
        foreground=TEXT_PRIMARY,
        font=("Inter", 10, "bold"),
        borderwidth=0,
        focuscolor=ACCENT_PRIMARY,
        padding=(15, 8)
    )
    style.map(
        "TButton",
        background=[('active', BG_HOVER), ('pressed', ACCENT_PRIMARY)],
        foreground=[('pressed', BG_BASE)]
    )
    
    style.configure(
        "Accent.TButton",
        background=ACCENT_PRIMARY,
        foreground=BG_BASE
    )
    style.map(
        "Accent.TButton",
        background=[('active', ACCENT_SECONDARY)]
    )
    
    # --- TNotebook ---
    style.configure("TNotebook", background=BG_BASE, borderwidth=0)
    style.configure(
        "TNotebook.Tab",
        background=BG_BASE,
        foreground=TEXT_SECONDARY,
        padding=(20, 10),
        font=("Inter", 10, "bold"),
        borderwidth=0
    )
    style.map(
        "TNotebook.Tab",
        background=[('selected', BG_SURFACE)],
        foreground=[('selected', ACCENT_PRIMARY)],
        expand=[('selected', [0, 0, 0, 0])]
    )
    
    # --- Treeview ---
    style.configure(
        "Treeview",
        background=BG_SURFACE,
        foreground=TEXT_PRIMARY,
        fieldbackground=BG_SURFACE,
        rowheight=32,
        font=("Inter", 10),
        borderwidth=0
    )
    style.configure(
        "Treeview.Heading",
        background=BG_BASE,
        foreground=TEXT_SECONDARY,
        font=("Inter", 10, "bold"),
        borderwidth=0,
        padding=(5, 5)
    )
    style.map(
        "Treeview",
        background=[('selected', ACCENT_PRIMARY)],
        foreground=[('selected', BG_BASE)]
    )

    # --- TProgressbar ---
    style.configure(
        "Horizontal.TProgressbar",
        troughcolor=BG_SURFACE,
        background=ACCENT_PRIMARY,
        thickness=8,
        borderwidth=0
    )

    # --- TEntry ---
    style.configure(
        "TEntry",
        fieldbackground=BG_SURFACE,
        foreground=TEXT_PRIMARY,
        insertcolor=TEXT_PRIMARY,
        borderwidth=0,
        padding=5
    )

    # --- TLabelFrame ---
    style.configure(
        "TLabelframe",
        background=BG_BASE,
        foreground=ACCENT_SECONDARY,
        font=("Inter", 11, "bold"),
        borderwidth=2,
        relief="flat"
    )
    style.configure(
        "TLabelframe.Label",
        background=BG_BASE,
        foreground=ACCENT_SECONDARY,
        font=("Inter", 11, "bold")
    )
