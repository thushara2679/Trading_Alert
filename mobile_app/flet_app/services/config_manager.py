"""
Configuration Manager
Protocol: Antigravity - Standalone Mobile Module

Handles persistent app configuration including signal thresholds.
"""

import json
import os
from typing import Dict, Any


class ConfigManager:
    """Manages persistent application settings."""
    
    CONFIG_FILE = "config.json"
    
    # Default Configuration
    DEFAULTS = {
        "thresholds": {
            "COMBO_4H": 70.0,
            "COMBO_5D": 60.0,
            "SCALP_4H": 70.0,
            "WATCH_5D": 60.0,
            "AVOID": 40.0,
        },
        "data": {
            "n_bars": 50,
            "validity_minutes": 15,
        }
    }
    
    _instance = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(ConfigManager, cls).__new__(cls)
            cls._instance._load_config()
        return cls._instance
    
    def _load_config(self):
        """Load config from disk or use defaults."""
        self.config = self.DEFAULTS.copy()
        
        if os.path.exists(self.CONFIG_FILE):
            try:
                with open(self.CONFIG_FILE, "r") as f:
                    saved = json.load(f)
                    # Deep update for dictionaries
                    for key, val in saved.items():
                        if isinstance(val, dict) and key in self.config:
                            self.config[key].update(val)
                        else:
                            self.config[key] = val
            except Exception as e:
                print(f"⚠️ Failed to load config: {e}")
    
    def save_config(self):
        """Save current config to disk."""
        try:
            with open(self.CONFIG_FILE, "w") as f:
                json.dump(self.config, f, indent=4)
        except Exception as e:
            print(f"❌ Failed to save config: {e}")
            
    def get(self, section: str, key: str) -> Any:
        """Get a specific config value."""
        return self.config.get(section, {}).get(key, self.DEFAULTS.get(section, {}).get(key))
    
    def set(self, section: str, key: str, value: Any):
        """Set a config value and save."""
        if section not in self.config:
            self.config[section] = {}
        self.config[section][key] = value
        self.save_config()
        
    def get_thresholds(self) -> Dict[str, float]:
        """Get all signal thresholds."""
        return self.config.get("thresholds", self.DEFAULTS["thresholds"])
        
    def update_thresholds(self, new_thresholds: Dict[str, float]):
        """Update multiple thresholds at once."""
        self.config["thresholds"].update(new_thresholds)
        self.save_config()
