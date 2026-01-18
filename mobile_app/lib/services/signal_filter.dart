/// Signal Filter with Multi-Timeframe Combo Logic
/// Protocol: Antigravity - Mobile Module
///
/// Implements the "Confluence Gate" for high-probability signals:
/// - COMBO: 4H >= 70% AND 5D >= 60% (Strong alignment)
/// - SCALP: 4H >= 70% only (Quick trade)
/// - WATCH: 5D >= 60% only (Monitor)
/// - AVOID: All < 40% (No trade)
/// - NONE: Otherwise (Silent)

class SignalFilter {
  // Configurable thresholds
  static const double MIN_MOMENTUM = 0.70; // 4H threshold
  static const double MIN_TREND = 0.60; // 5D threshold
  static const double AVOID_THRESHOLD = 0.40; // Below this = AVOID

  /// Evaluate probabilities and return signal type
  /// Input: [prob4H, prob2D, prob5D]
  static SignalResult evaluate(List<double> probabilities) {
    if (probabilities.length < 3) {
      return SignalResult(
        type: SignalType.none,
        message: 'Invalid probabilities',
      );
    }

    final p4H = probabilities[0];
    final p5D = probabilities[2];

    // Check for AVOID condition first
    if (p4H < AVOID_THRESHOLD && p5D < AVOID_THRESHOLD) {
      return SignalResult(
        type: SignalType.avoid,
        message: '❄️ AVOID: Volume suggests fake-out or stagnation',
        confidence: (p4H + p5D) / 2,
      );
    }

    // Check for COMBO (highest priority signal)
    if (p4H >= MIN_MOMENTUM && p5D >= MIN_TREND) {
      return SignalResult(
        type: SignalType.combo,
        message: '🔥 COMBO: High confidence entry!',
        confidence: (p4H + p5D) / 2,
      );
    }

    // Check for SCALP (short-term momentum only)
    if (p4H >= MIN_MOMENTUM) {
      return SignalResult(
        type: SignalType.scalp,
        message: '⚡ SCALP: Quick trade, take profits fast',
        confidence: p4H,
      );
    }

    // Check for WATCH (long-term trend only)
    if (p5D >= MIN_TREND) {
      return SignalResult(
        type: SignalType.watch,
        message: '📈 WATCH: Monitor, wait for momentum',
        confidence: p5D,
      );
    }

    // No significant signal
    return SignalResult(
      type: SignalType.none,
      message: 'No actionable signal',
      confidence: (p4H + p5D) / 2,
    );
  }

  /// Check if signal should trigger notification
  static bool shouldNotify(SignalType type) {
    return type == SignalType.combo || type == SignalType.scalp;
  }
}

enum SignalType {
  combo, // 🔥 High confidence entry
  scalp, // ⚡ Quick trade
  watch, // 📈 Monitor
  avoid, // ❄️ No trade
  none, // Silent
}

class SignalResult {
  final SignalType type;
  final String message;
  final double confidence;

  SignalResult({
    required this.type,
    required this.message,
    this.confidence = 0.0,
  });

  String get emoji {
    switch (type) {
      case SignalType.combo:
        return '🔥';
      case SignalType.scalp:
        return '⚡';
      case SignalType.watch:
        return '📈';
      case SignalType.avoid:
        return '❄️';
      case SignalType.none:
        return '';
    }
  }

  String get typeName {
    switch (type) {
      case SignalType.combo:
        return 'COMBO';
      case SignalType.scalp:
        return 'SCALP';
      case SignalType.watch:
        return 'WATCH';
      case SignalType.avoid:
        return 'AVOID';
      case SignalType.none:
        return 'NONE';
    }
  }
}
