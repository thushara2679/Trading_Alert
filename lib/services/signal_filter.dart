/// Signal Filter Service
/// Converted from: services/signal_filter.py
/// 
/// Evaluates probability outputs and classifies trading signals.
/// Signal Logic (configurable via ConfigManager):
/// | Signal | Condition | Color | Action |
/// |--------|-----------|-------|--------|
/// | COMBO  | 4H ≥ T1 AND 5D ≥ T2 | Red | BUY NOW |
/// | SCALP  | 4H ≥ T3 only | Orange | Short-term trade |
/// | WATCH  | 5D ≥ T4 only | Yellow | Monitor |
/// | AVOID  | All < T5 | Blue | Skip |

import 'package:flutter/material.dart';
import '../models/signal_result.dart';
import 'config_manager.dart';

class SignalFilter {
  // Signal Colors (matching Python exactly)
  static const Map<String, Color> colors = {
    'COMBO': Color(0xFFEF4444),   // Red
    'SCALP': Color(0xFFF97316),   // Orange
    'WATCH': Color(0xFFEAB308),   // Yellow
    'AVOID': Color(0xFF3B82F6),   // Blue
    'NEUTRAL': Color(0xFF6B7280), // Gray
  };

  /// Evaluate probabilities and return signal type.
  /// 
  /// [probs] - Map with keys '4H', '2D', '5D' containing percentages (0-100)
  /// Returns SignalResult with type, actionability, confidence, and color.
  static SignalResult evaluate(Map<String, double> probs) {
    final thresholds = ConfigManager.instance.getThresholds();

    final p4h = probs['4H'] ?? 0.0;
    final p2d = probs['2D'] ?? 0.0;
    final p5d = probs['5D'] ?? 0.0;

    final avg = (p4h + p2d + p5d) / 3.0;

    // COMBO: 4H ≥ 70% AND 5D ≥ 60%
    if (p4h >= thresholds['COMBO_4H']! && p5d >= thresholds['COMBO_5D']!) {
      return SignalResult(
        typeName: 'COMBO',
        isActionable: true,
        confidence: avg,
        color: colors['COMBO']!,
      );
    }

    // SCALP: 4H ≥ 70% only
    if (p4h >= thresholds['SCALP_4H']!) {
      return SignalResult(
        typeName: 'SCALP',
        isActionable: true,
        confidence: p4h,
        color: colors['SCALP']!,
      );
    }

    // WATCH: 5D ≥ 60% only
    if (p5d >= thresholds['WATCH_5D']!) {
      return SignalResult(
        typeName: 'WATCH',
        isActionable: false,
        confidence: p5d,
        color: colors['WATCH']!,
      );
    }

    // AVOID: All < 40%
    final avoidT = thresholds['AVOID']!;
    if (p4h < avoidT && p2d < avoidT && p5d < avoidT) {
      return SignalResult(
        typeName: 'AVOID',
        isActionable: false,
        confidence: avg,
        color: colors['AVOID']!,
      );
    }

    // NEUTRAL: No clear signal
    return SignalResult(
      typeName: 'NEUTRAL',
      isActionable: false,
      confidence: avg,
      color: colors['NEUTRAL']!,
    );
  }

  /// Get priority for sorting (higher = more important)
  static int getSignalPriority(String signalType) {
    const priorityMap = {
      'COMBO': 4,
      'SCALP': 3,
      'WATCH': 2,
      'NEUTRAL': 1,
      'AVOID': 0,
    };
    return priorityMap[signalType] ?? 0;
  }

  /// Get color for a signal type
  static Color getColor(String? signalType) {
    return colors[signalType] ?? colors['NEUTRAL']!;
  }
}
