/// Signal Result Model
/// Converted from: services/signal_filter.py - SignalResult dataclass
/// 
/// Result of signal evaluation containing type, actionability, and display info.

import 'package:flutter/material.dart';

class SignalResult {
  final String typeName;
  final bool isActionable;
  final double confidence;
  final Color color;

  const SignalResult({
    required this.typeName,
    required this.isActionable,
    required this.confidence,
    required this.color,
  });

  /// Get the hex color string for the signal
  String get colorHex {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }
}
