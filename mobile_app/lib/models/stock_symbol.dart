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

  /// Create from CSV row (Exchange header format)
  factory StockSymbol.fromCsvRow(String symbol, String exchange) {
    return StockSymbol(
      symbol: symbol.trim(),
      exchange: exchange.trim(),
    );
  }

  /// Convert to CSV row for export
  String toCsvRow() {
    return '$exchange,$symbol,${signalType ?? ""},${prob4H?.toStringAsFixed(2) ?? ""},${prob5D?.toStringAsFixed(2) ?? ""},${lastUpdated?.toIso8601String() ?? ""}';
  }

  /// Check if this stock has a valid signal
  bool get hasSignal => signalType != null && signalType != 'NONE' && signalType != 'AVOID';

  @override
  String toString() => '$exchange:$symbol ($signalType)';
}
