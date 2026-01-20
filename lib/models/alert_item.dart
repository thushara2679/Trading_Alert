/// Alert Item Model
/// Converted from: screens/alerts.py - AlertItem class
/// 
/// Data model representing a trading signal alert.

class AlertItem {
  final String symbol;
  final String signalType;
  final double prob4h;
  final double prob2d;
  final double prob5d;
  final String timestamp;
  final double lastPrice;

  AlertItem({
    required this.symbol,
    required this.signalType,
    required this.prob4h,
    required this.prob2d,
    required this.prob5d,
    required this.timestamp,
    this.lastPrice = 0.0,
  });

  /// Convert to JSON Map for persistence
  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'signal_type': signalType,
      'prob_4h': prob4h,
      'prob_2d': prob2d,
      'prob_5d': prob5d,
      'timestamp': timestamp,
      'last_price': lastPrice,
    };
  }

  /// Factory constructor from JSON Map
  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      symbol: json['symbol'] as String,
      signalType: json['signal_type'] as String,
      prob4h: (json['prob_4h'] as num).toDouble(),
      prob2d: (json['prob_2d'] as num).toDouble(),
      prob5d: (json['prob_5d'] as num).toDouble(),
      timestamp: json['timestamp'] as String,
      lastPrice: (json['last_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
