import flet as ft
print(f"Flet version: {ft.version}")
try:
    print(f"Icons available: {ft.Icons.ADD}")
except:
    print("Icons not available as ft.Icons")

try:
    print(f"Colors available: {ft.Colors.BLUE}")
except:
    print("Colors not available as ft.Colors")
    
try:
    from flet import NavigationDestination
    print("NavigationDestination available")
except:
    print("NavigationDestination NOT available")
