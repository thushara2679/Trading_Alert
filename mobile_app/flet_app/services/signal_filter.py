"""
Signal Filter Service
Protocol: Antigravity - Standalone Mobile Module

Evaluates probability outputs and classifies trading signals.

Signal Logic (configurable via settings):
| Signal | Condition | Color | Action |
|--------|-----------|-------|--------|
| COMBO  | 4H ≥ T1 AND 5D ≥ T2 | Red | BUY NOW |
| SCALP  | 4H ≥ T3 only | Orange | Short-term trade |
| WATCH  | 5D ≥ T4 only | Yellow | Monitor |
| AVOID  | All < T5 | Blue | Skip |
"""

from dataclasses import dataclass
from typing import Dict
from services.config_manager import ConfigManager


@dataclass
class SignalResult:
    """Result of signal evaluation."""
    type_name: str
    is_actionable: bool
    confidence: float
    color: str


class SignalFilter:
    """
    Evaluates model probabilities and returns signal classification.
    Uses multi-timeframe combo logic with configurable thresholds.
    """
    
    # Signal Colors
    COLORS = {
        "COMBO": "#EF4444",   # Red
        "SCALP": "#F97316",   # Orange
        "WATCH": "#EAB308",   # Yellow
        "AVOID": "#3B82F6",   # Blue
        "NEUTRAL": "#6B7280", # Gray
    }
    
    @classmethod
    def evaluate(cls, probs: Dict[str, float]) -> SignalResult:
        """
        Evaluate probabilities and return signal type.
        
        Args:
            probs: {"4H": 75.2, "2D": 62.8, "5D": 88.4} (percentages)
            
        Returns:
            SignalResult with type, actionability, confidence, and color.
        """
        config = ConfigManager()
        thresholds = config.get_thresholds()
        
        p4h = probs.get("4H", 0.0)
        p2d = probs.get("2D", 0.0)
        p5d = probs.get("5D", 0.0)
        
        avg = (p4h + p2d + p5d) / 3.0
        
        # COMBO: 4H ≥ 70% AND 5D ≥ 60%
        if p4h >= thresholds["COMBO_4H"] and p5d >= thresholds["COMBO_5D"]:
            return SignalResult(
                type_name="COMBO",
                is_actionable=True,
                confidence=avg,
                color=cls.COLORS["COMBO"],
            )
        
        # SCALP: 4H ≥ 70% only
        if p4h >= thresholds["SCALP_4H"]:
            return SignalResult(
                type_name="SCALP",
                is_actionable=True,
                confidence=p4h,
                color=cls.COLORS["SCALP"],
            )
        
        # WATCH: 5D ≥ 60% only
        if p5d >= thresholds["WATCH_5D"]:
            return SignalResult(
                type_name="WATCH",
                is_actionable=False,
                confidence=p5d,
                color=cls.COLORS["WATCH"],
            )
        
        # AVOID: All < 40%
        # Check all available horizons against avoid threshold
        avoid_t = thresholds["AVOID"]
        if p4h < avoid_t and p2d < avoid_t and p5d < avoid_t:
            return SignalResult(
                type_name="AVOID",
                is_actionable=False,
                confidence=avg,
                color=cls.COLORS["AVOID"],
            )
        
        # NEUTRAL: No clear signal
        return SignalResult(
            type_name="NEUTRAL",
            is_actionable=False,
            confidence=avg,
            color=cls.COLORS["NEUTRAL"],
        )
    
    @classmethod
    def get_signal_priority(cls, signal_type: str) -> int:
        """Get priority for sorting (higher = more important)."""
        priority_map = {
            "COMBO": 4,
            "SCALP": 3,
            "WATCH": 2,
            "NEUTRAL": 1,
            "AVOID": 0,
        }
        return priority_map.get(signal_type, 0)
