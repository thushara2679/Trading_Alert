"""
Model Inference Service - XGBoost JSON Parser
Protocol: Antigravity - Standalone Mobile Module

Loads XGBoost models exported as JSON and runs inference.
Uses native Python tree parsing for on-device prediction.

Model Structure:
    assets/models/{SYMBOL}_pkg/
        ├── features.json       (Feature metadata)
        ├── model_4H.json       (4-hour model)
        ├── model_2D.json       (2-day model)
        └── model_5D.json       (5-day model)
"""

import os
import json
import math
from typing import Dict, List, Optional, Any


class XGBoostTree:
    """Single decision tree from XGBoost model."""
    
    def __init__(
        self,
        left_children: List[int],
        right_children: List[int],
        split_indices: List[int],
        split_conditions: List[float],
        base_weights: List[float],
    ):
        self.left_children = left_children
        self.right_children = right_children
        self.split_indices = split_indices
        self.split_conditions = split_conditions
        self.base_weights = base_weights
        self.is_leaf = [left == -1 for left in left_children]
    
    @staticmethod
    def _safe_float(val: Any) -> float:
        """Robust float parser handling strings and arrays."""
        if isinstance(val, (int, float)):
            return float(val)
        if isinstance(val, str):
            # Clean string brackets/quotes if present
            val = val.strip("[]'\" ")
            try:
                return float(val)
            except ValueError:
                return 0.0
        if isinstance(val, list) and len(val) > 0:
            return XGBoostTree._safe_float(val[0])
        return 0.0

    @classmethod
    def from_json(cls, tree_json: Dict) -> "XGBoostTree":
        """Parse tree from XGBoost JSON format."""
        return cls(
            left_children=tree_json["left_children"],
            right_children=tree_json["right_children"],
            split_indices=tree_json["split_indices"],
            split_conditions=[cls._safe_float(x) for x in tree_json["split_conditions"]],
            base_weights=[cls._safe_float(x) for x in tree_json["base_weights"]],
        )
    
    def predict(self, features: List[float]) -> float:
        """Traverse tree to get prediction."""
        node = 0
        
        while not self.is_leaf[node]:
            feat_idx = self.split_indices[node]
            threshold = self.split_conditions[node]
            
            if feat_idx >= len(features):
                return self.base_weights[node]
            
            if features[feat_idx] < threshold:
                node = self.left_children[node]
            else:
                node = self.right_children[node]
            
            if node < 0 or node >= len(self.is_leaf):
                break
        
        return self.base_weights[node]


class XGBoostModel:
    """XGBoost model loaded from JSON."""
    
    def __init__(self, trees: List[XGBoostTree], base_score: float = 0.5):
        self.trees = trees
        self.base_score = base_score
    
    @classmethod
    def from_json(cls, model_json: Dict) -> "XGBoostModel":
        """Parse model from XGBoost JSON format."""
        learner = model_json.get("learner", model_json)
        model_param = learner.get("learner_model_param", {})
        base_score = XGBoostTree._safe_float(model_param.get("base_score", "0.5"))
        
        tree_data = learner.get("gradient_booster", {}).get("model", {}).get("trees", [])
        trees = [XGBoostTree.from_json(t) for t in tree_data]
        
        return cls(trees=trees, base_score=base_score)
    
    def predict_raw(self, features: List[float]) -> float:
        """Get raw prediction (sum of tree outputs)."""
        total = self.base_score
        for tree in self.trees:
            total += tree.predict(features)
        return total
    
    def predict_proba(self, features: List[float]) -> float:
        """Get probability via sigmoid transformation."""
        raw = self.predict_raw(features)
        return 1.0 / (1.0 + math.exp(-raw))


class ModelInference:
    """
    Manages XGBoost model loading and inference.
    
    Model Location: assets/models/{SYMBOL}_pkg/
        - model_4H.json (4-hour model)
        - model_2D.json (2-day model)
        - model_5D.json (5-day model)
        - features.json (optional metadata)
    """
    
    HORIZONS = ["4H", "2D", "5D"]
    
    def __init__(self, models_dir: str = "assets/models"):
        self.models_dir = models_dir
        self._models: Dict[str, XGBoostModel] = {}
        self._feature_names: Dict[str, List[str]] = {}
        os.makedirs(models_dir, exist_ok=True)
    
    def _get_model_pkg_path(self, symbol: str) -> str:
        """Get the package directory path for a symbol."""
        safe_symbol = symbol.replace(".", "_")
        # Check standard and mobile variants
        base = os.path.join(self.models_dir, f"{safe_symbol}_pkg")
        mobile = os.path.join(self.models_dir, f"{safe_symbol}_mobile_pkg")
        
        if os.path.exists(mobile):
            return mobile
        return base
    
    def load_models(self, symbol: str) -> Dict[str, bool]:
        """
        Load all horizon models (4H, 2D, 5D) for a symbol.
        
        Returns:
            Dict mapping horizon to load success status.
        """
        pkg_path = self._get_model_pkg_path(symbol)
        results = {}
        
        for horizon in self.HORIZONS:
            key = f"{symbol}_{horizon}"
            model_file = os.path.join(pkg_path, f"model_{horizon}.json")
            
            if os.path.exists(model_file):
                try:
                    with open(model_file, "r") as f:
                        model_json = json.load(f)
                    self._models[key] = XGBoostModel.from_json(model_json)
                    print(f"✅ Loaded: {symbol} {horizon}")
                    results[horizon] = True
                except Exception as e:
                    print(f"⚠️ Failed to load {symbol} {horizon}: {e}")
                    results[horizon] = False
            else:
                results[horizon] = False
        
        # Load feature names if available
        features_file = os.path.join(pkg_path, "features.json")
        if os.path.exists(features_file):
            try:
                with open(features_file, "r") as f:
                    data = json.load(f)
                    # Support both "inputs" (mobile spec) and "names" (legacy)
                    self._feature_names[symbol] = data.get("inputs", data.get("names", []))
            except:
                pass
        
        return results
    
    def predict(self, symbol: str, features: Dict[str, float]) -> Dict[str, float]:
        """
        Run inference for a symbol.
        
        Args:
            symbol: Stock ticker
            features: Feature dictionary from DataFetcher
            
        Returns:
            Dict with confidence percentages: {"4H": 75.2, "2D": 62.8, "5D": 88.4}
        """
        # Determine feature order from metadata or fallback
        if symbol in self._feature_names:
            feature_order = self._feature_names[symbol]
        else:
            feature_order = ["Vol_Z", "Elasticity", "day_of_week", "hour_of_day"] # Legacy
            
        # Create feature vector
        feature_list = [features.get(f, 0.0) for f in feature_order]
        
        results = {}
        for horizon in self.HORIZONS:
            key = f"{symbol}_{horizon}"
            model = self._models.get(key)
            
            if model is None:
                results[horizon] = 0.0
            else:
                prob = model.predict_proba(feature_list)
                # Convert to percentage (0-100%)
                results[horizon] = round(prob * 100, 1)
        
        return results
    
    def has_models(self, symbol: str) -> bool:
        """Check if any models are loaded for a symbol."""
        for horizon in self.HORIZONS:
            if f"{symbol}_{horizon}" in self._models:
                return True
        return False
    
    def get_model_status(self, symbol: str) -> Dict[str, str]:
        """
        Get detailed status of models for a symbol.
        
        Returns:
            Dict with status per horizon: {"4H": "loaded", "2D": "loaded", "5D": "missing"}
        """
        pkg_path = self._get_model_pkg_path(symbol)
        status = {}
        
        for horizon in self.HORIZONS:
            key = f"{symbol}_{horizon}"
            if key in self._models:
                status[horizon] = "loaded"
            elif os.path.exists(os.path.join(pkg_path, f"model_{horizon}.json")):
                status[horizon] = "available"
            else:
                status[horizon] = "missing"
        
        return status
    
    def list_available_symbols(self) -> List[str]:
        """List all symbols that have model packages available."""
        symbols = []
        if os.path.exists(self.models_dir):
            for name in os.listdir(self.models_dir):
                if name.endswith("_pkg") and os.path.isdir(os.path.join(self.models_dir, name)):
                    # Convert back to symbol format (safe approximation)
                    # If we enforced "_pkg", name[:-4] is "CCS_N0000".
                    # replace("_", ".") -> "CCS.N0000".
                    # Legacy "CCS.N0000_pkg" -> "CCS.N0000" (no underscores found/replaced).
                    symbol = name[:-4].replace("_", ".")
                    symbols.append(symbol)
        return symbols
    
    def delete_model_package(self, symbol: str) -> bool:
        """Delete all models for a symbol."""
        import shutil
        import time
        
        # Clear from memory first
        for horizon in self.HORIZONS:
            key = f"{symbol}_{horizon}"
            if key in self._models:
                del self._models[key]
        
        if not os.path.exists(self.models_dir):
            return False

        deletion_success = False
        
        # Scan directory to find ANY folder that maps to this symbol
        # This guarantees that if list_available_symbols() shows it, we can delete it.
        for name in os.listdir(self.models_dir):
            if name.endswith("_pkg") and os.path.isdir(os.path.join(self.models_dir, name)):
                # Same derivation logic as list_available_symbols
                derived_symbol = name[:-4].replace("_", ".")
                
                if derived_symbol == symbol:
                    folder_path = os.path.join(self.models_dir, name)
                    try:
                        shutil.rmtree(folder_path)
                        print(f"🗑️ Deleted model package: {folder_path}")
                        deletion_success = True
                    except Exception as e:
                        print(f"❌ Failed to delete {folder_path}: {e}")
                        # Retry once after short delay (Windows file locking)
                        try:
                            time.sleep(0.1)
                            shutil.rmtree(folder_path)
                            print(f"🗑️ Deleted on retry: {folder_path}")
                            deletion_success = True
                        except:
                            pass
        
        return deletion_success
    
    def test_inference(self, symbol: str) -> Dict[str, Any]:
        """
        Run test inference with dummy data for diagnostics.
        Returns detailed result dictionary.
        """
        if not self.load_models(symbol):
            return {"status": "failed", "error": "Could not load models"}
            
        # Dummy features (approximate average values)
        dummy_features = {
            "Vol_Z": 0.5,
            "Elasticity": 0.02,
            "day_of_week": 2.0,
            "hour_of_day": 10.0
        }
        
        try:
            results = self.predict(symbol, dummy_features)
            return {
                "status": "success", 
                "results": results,
                "models": self.get_model_status(symbol)
            }
        except Exception as e:
            return {"status": "error", "error": str(e)}

    def clear_models(self) -> None:
        """Clear all cached models from memory."""
        self._models.clear()
        self._feature_names.clear()
