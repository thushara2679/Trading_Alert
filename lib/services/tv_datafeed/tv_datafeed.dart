/// TV Datafeed Dart - TradingView data downloader for Dart/Flutter
///
/// A Dart port of the tvdatafeed Python library.
///
/// Example usage:
/// ```dart
/// import 'package:tv_datafeed_dart/tv_datafeed_dart.dart';
///
/// void main() async {
///   final tv = TvDatafeed();
///   await tv.init();
///
///   final data = await tv.getHist(
///     symbol: 'AAPL',
///     exchange: 'NASDAQ',
///     interval: Interval.inDaily,
///     nBars: 100,
///   );
///
///   print(data);
/// }
/// ```
library tv_datafeed_dart;

export 'src/interval.dart';
export 'src/models/ohlcv_data.dart';
export 'src/models/seis.dart';
export 'src/models/consumer.dart';
export 'src/tv_datafeed.dart';
export 'src/tv_datafeed_live.dart';
