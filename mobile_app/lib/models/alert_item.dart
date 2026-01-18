/// Alert Item Model
/// Protocol: Antigravity - Mobile Module

class AlertItem {
  final String symbol;
  final String signalType;
  final double prob4H;
  final double prob2D;
  final double prob5D;
  final DateTime timestamp;

  AlertItem({
    required this.symbol,
    required this.signalType,
    required this.prob4H,
    required this.prob2D,
    required this.prob5D,
    required this.timestamp,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'signalType': signalType,
      'prob4H': prob4H,
      'prob2D': prob2D,
      'prob5D': prob5D,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Create from JSON
  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      symbol: json['symbol'],
      signalType: json['signalType'],
      prob4H: json['prob4H'].toDouble(),
      prob2D: (json['prob2D'] ?? 0.0).toDouble(), // Handle legacy without 2D
      prob5D: json['prob5D'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}
