import 'package:equatable/equatable.dart';
import '../interval.dart';

/// Symbol-Exchange-Interval Set (Seis).
///
/// Holds a unique set of symbol, exchange, and interval values
/// for live feed monitoring.
class Seis extends Equatable {
  /// The ticker symbol.
  final String symbol;

  /// The exchange where the symbol is listed.
  final String exchange;

  /// The chart interval.
  final Interval interval;

  /// Timestamp of the last data bar retrieved.
  DateTime? _lastUpdated;

  Seis({
    required this.symbol,
    required this.exchange,
    required this.interval,
  });

  /// Get the last updated timestamp.
  DateTime? get lastUpdated => _lastUpdated;

  /// Update the last updated timestamp.
  void updateTimestamp(DateTime timestamp) {
    _lastUpdated = timestamp;
  }

  /// Check if provided data is newer than the last update.
  ///
  /// Returns true if the data is new, false otherwise.
  bool isNewData(DateTime dataTimestamp) {
    if (_lastUpdated == null || dataTimestamp.isAfter(_lastUpdated!)) {
      _lastUpdated = dataTimestamp;
      return true;
    }
    return false;
  }

  @override
  List<Object?> get props => [symbol, exchange, interval];

  @override
  String toString() {
    return 'Seis(symbol: $symbol, exchange: $exchange, interval: ${interval.name})';
  }
}
