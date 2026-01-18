/// Stock Symbol Model for the Alert App
/// Protocol: Antigravity - Mobile Module

class StockSymbol {
  final String symbol;
  final String exchange;
  String dataStatus;
  double? prob4H;
  double? prob2D;
  double? prob5D;
  String? signalType;
  DateTime? lastUpdated;

  StockSymbol({
    required this.symbol,
    required this.exchange,
    this.dataStatus = 'Pending',
    this.prob4H,
    this.prob2D,
    this.prob5D,
    this.signalType,
    this.lastUpdated,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'exchange': exchange,
      'dataStatus': dataStatus,
      'prob4H': prob4H,
      'prob2D': prob2D,
      'prob5D': prob5D,
      'signalType': signalType,
      'lastUpdated': lastUpdated?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory StockSymbol.fromJson(Map<String, dynamic> json) {
    return StockSymbol(
      symbol: json['symbol'],
      exchange: json['exchange'],
      dataStatus: json['dataStatus'] ?? 'Pending',
      prob4H: json['prob4H'],
      prob2D: json['prob2D'],
      prob5D: json['prob5D'],
      signalType: json['signalType'],
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated']) 
          : null,
    );
  }

  /// Create from CSV row (Exchange header format)
  factory StockSymbol.fromCsvRow(String symbol, String exchange) {
    return StockSymbol(
      symbol: symbol.trim(),
      exchange: exchange.trim(),
    );
  }

  /// Convert to CSV row for export
  String toCsvRow() {
    return '$exchange,$symbol,${signalType ?? ""},${prob4H?.toStringAsFixed(2) ?? ""},${prob2D?.toStringAsFixed(2) ?? ""},${prob5D?.toStringAsFixed(2) ?? ""},${lastUpdated?.toIso8601String() ?? ""}';
  }

  /// Check if this stock has a valid signal
  bool get hasSignal => signalType != null && signalType != 'NONE' && signalType != 'AVOID';

  @override
  String toString() => '$exchange:$symbol ($signalType)';
}
