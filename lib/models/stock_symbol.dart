/// Stock Symbol Model
/// Converted from: screens/watchlist.py - StockSymbol class
/// 
/// Data model representing a stock in the watchlist with prediction data.

class StockSymbol {
  final String symbol;
  final String exchange;
  double? prob4h;
  double? prob2d;
  double? prob5d;
  String? signalType;
  String dataStatus;
  String? lastUpdated;
  double lastPrice;

  StockSymbol({
    required this.symbol,
    this.exchange = 'CSELK',
    this.prob4h,
    this.prob2d,
    this.prob5d,
    this.signalType,
    this.dataStatus = 'Not Scanned',
    this.lastUpdated,
    this.lastPrice = 0.0,
  });

  /// Convert to JSON Map for persistence
  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'exchange': exchange,
      'prob_4h': prob4h,
      'prob_2d': prob2d,
      'prob_5d': prob5d,
      'signal_type': signalType,
      'data_status': dataStatus,
      'last_updated': lastUpdated,
      'last_price': lastPrice,
    };
  }

  /// Factory constructor from JSON Map
  factory StockSymbol.fromJson(Map<String, dynamic> json) {
    return StockSymbol(
      symbol: json['symbol'] as String,
      exchange: json['exchange'] as String? ?? 'CSELK',
      prob4h: (json['prob_4h'] as num?)?.toDouble(),
      prob2d: (json['prob_2d'] as num?)?.toDouble(),
      prob5d: (json['prob_5d'] as num?)?.toDouble(),
      signalType: json['signal_type'] as String?,
      dataStatus: json['data_status'] as String? ?? 'Not Scanned',
      lastUpdated: json['last_updated'] as String?,
      lastPrice: (json['last_price'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Copy with modified fields
  StockSymbol copyWith({
    String? symbol,
    String? exchange,
    double? prob4h,
    double? prob2d,
    double? prob5d,
    String? signalType,
    String? dataStatus,
    String? lastUpdated,
    double? lastPrice,
  }) {
    return StockSymbol(
      symbol: symbol ?? this.symbol,
      exchange: exchange ?? this.exchange,
      prob4h: prob4h ?? this.prob4h,
      prob2d: prob2d ?? this.prob2d,
      prob5d: prob5d ?? this.prob5d,
      signalType: signalType ?? this.signalType,
      dataStatus: dataStatus ?? this.dataStatus,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      lastPrice: lastPrice ?? this.lastPrice,
    );
  }
}
