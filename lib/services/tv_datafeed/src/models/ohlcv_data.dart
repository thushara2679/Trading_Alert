import 'package:equatable/equatable.dart';

/// OHLCV (Open, High, Low, Close, Volume) data model.
///
/// Represents a single candlestick bar of market data.
/// This is the Dart equivalent of pandas DataFrame rows.
class OHLCVData extends Equatable {
  /// The symbol/ticker for this data.
  final String symbol;

  /// The timestamp of this bar.
  final DateTime datetime;

  /// Opening price.
  final double open;

  /// Highest price during the period.
  final double high;

  /// Lowest price during the period.
  final double low;

  /// Closing price.
  final double close;

  /// Trading volume.
  final double volume;

  const OHLCVData({
    required this.symbol,
    required this.datetime,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  /// Create from a map (JSON parsing).
  factory OHLCVData.fromMap(Map<String, dynamic> map, String symbol) {
    return OHLCVData(
      symbol: symbol,
      datetime: map['datetime'] is DateTime
          ? map['datetime']
          : DateTime.fromMillisecondsSinceEpoch(
              (map['datetime'] as num).toInt() * 1000,
            ),
      open: (map['open'] as num).toDouble(),
      high: (map['high'] as num).toDouble(),
      low: (map['low'] as num).toDouble(),
      close: (map['close'] as num).toDouble(),
      volume: (map['volume'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert to map for serialization.
  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'datetime': datetime.millisecondsSinceEpoch ~/ 1000,
      'open': open,
      'high': high,
      'low': low,
      'close': close,
      'volume': volume,
    };
  }

  @override
  List<Object?> get props => [symbol, datetime, open, high, low, close, volume];

  @override
  String toString() {
    return 'OHLCVData(symbol: $symbol, datetime: $datetime, '
        'O: $open, H: $high, L: $low, C: $close, V: $volume)';
  }
}

/// Extension methods for List<OHLCVData> to mimic DataFrame operations.
extension OHLCVDataListExtension on List<OHLCVData> {
  /// Get the first n rows (like pandas head()).
  List<OHLCVData> head([int n = 5]) => take(n).toList();

  /// Get the last n rows (like pandas tail()).
  List<OHLCVData> tail([int n = 5]) => skip(length - n).toList();

  /// Get summary info.
  String info() {
    if (isEmpty) return 'Empty dataset';
    return '''
OHLCVData Summary:
  Symbol: ${first.symbol}
  Rows: $length
  Date Range: ${first.datetime} to ${last.datetime}
  ''';
  }

  /// Convert to CSV string.
  String toCsv() {
    final buffer = StringBuffer();
    buffer.writeln('datetime,symbol,open,high,low,close,volume');
    for (final row in this) {
      buffer.writeln(
        '${row.datetime.toIso8601String()},${row.symbol},'
        '${row.open},${row.high},${row.low},${row.close},${row.volume}',
      );
    }
    return buffer.toString();
  }
}
