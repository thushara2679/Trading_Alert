/// Data Fetcher Service - Real Implementation
/// 
/// Uses tv_datafeed_dart package to fetch historical data from TradingView.
/// Calculates features (Elasticity, Vol_Z) for XGBoost inference.
/// Caches data locally.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'tv_datafeed/tv_datafeed.dart';

/// Data validity period (skip re-fetch if data is fresher than this)
const int dataValidityMinutes = 15;

/// Real implementation of DataFetcher
class DataFetcher {
  final String cacheDir;
  TvDatafeed? _tv;
  
  /// Track last fetch time per symbol for validity check
  final Map<String, DateTime> fetchTimestamps = {};
  
  /// Track failed symbols for targeted retry
  final List<String> failedSymbols = [];

  DataFetcher({this.cacheDir = 'data_cache'});

  /// Initialize the data fetcher
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cachePath = Directory('${appDir.path}/$cacheDir');
    if (!await cachePath.exists()) {
      await cachePath.create(recursive: true);
    }
    
    // Initialize TvDatafeed
    _tv = TvDatafeed();
    await _tv?.init();
    print('✅ TvDatafeed initialized');
  }

  /// Check if cached data is still valid
  Future<bool> isDataValid(String symbol) async {
    final cached = await _loadCache(symbol);
    if (cached != null && cached.containsKey('timestamp')) {
      try {
        final cachedTime = DateTime.parse(cached['timestamp'] as String);
        final age = DateTime.now().difference(cachedTime);
        if (age.inMinutes < dataValidityMinutes) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Main fetch method
  Future<Map<String, dynamic>?> fetchSymbol(
    String symbol, {
    String exchange = 'CSELK',
    String interval = '1h',
    int nBars = 60,
    bool force = false,
  }) async {
    // Check cache first if not forced
    if (!force && await isDataValid(symbol)) {
      final cached = await _loadCache(symbol);
      if (cached != null) {
        print('✅ $symbol: Using cached data');
        return cached;
      }
    }

    print('📡 Fetching $symbol from $exchange...');

    // Use a fresh TvDatafeed instance for each request to ensure
    // true concurrency and prevent WebSocket state pollution.
    final tvDriver = TvDatafeed();
    
    try {
      await tvDriver.init();

      // Fetch 1H data
      final bars = await tvDriver.getHist(
        symbol: symbol,
        exchange: exchange,
        interval: Interval.in1Hour,
        nBars: nBars,
      );

      if (bars.isEmpty) {
        print('⚠️ No data for $symbol');
        if (!failedSymbols.contains(symbol)) failedSymbols.add(symbol);
        return await _loadCache(symbol); // Fallback to cache
      }

      if (failedSymbols.contains(symbol)) failedSymbols.remove(symbol);

      // Process features
      final features = _calculateFeatures(bars);
      
      final latest = bars.last;
      
      final result = {
        "symbol": symbol,
        "exchange": exchange,
        "timestamp": DateTime.now().toIso8601String(),
        "ohlcv": {
          "open": latest.open,
          "high": latest.high,
          "low": latest.low,
          "close": latest.close,
          "volume": latest.volume,
        },
        "features": features,
        "bars_count": bars.length,
        "is_live": true,
      };

      await _saveCache(symbol, result);
      return result;

    } catch (e) {
      print('❌ Error fetching $symbol: $e');
      if (!failedSymbols.contains(symbol)) failedSymbols.add(symbol);
      return await _loadCache(symbol);
    } finally {
      // Ensure resources are released
      await tvDriver.dispose();
    }
  }

  // Feature Calculation Logic
  Map<String, double> _calculateFeatures(List<OHLCVData> bars) {
    if (bars.isEmpty) return {};

    final result = <String, double>{};
    
    // --- 1H Features ---
    final last = bars.last;
    
    // Elasticity: (High - Low) / Close
    final elasticity = (last.high - last.low) / last.close;
    result['Elasticity_1H'] = elasticity;

    // Vol_Z 1H
    final volZ1H = _calculateVolZ(bars.map((b) => b.volume).toList(), 60);
    result['Vol_Z_1H'] = volZ1H;

    // --- 4H Features (Resample) ---
    final bars4H = _resample(bars, Duration(hours: 4));
    final volZ4H = _calculateVolZ(bars4H.map((b) => b.volume).toList(), 60);
    result['Vol_Z_4H'] = volZ4H;

    // --- 1D Features (Resample) ---
    final bars1D = _resample(bars, Duration(days: 1));
    final volZ1D = _calculateVolZ(bars1D.map((b) => b.volume).toList(), 60);
    result['Vol_Z_1D'] = volZ1D;

    // --- Time Features ---
    result['day_of_week'] = last.datetime.weekday.toDouble() - 1; // Python: Monday=0? Wrapper checks
    result['hour_of_day'] = last.datetime.hour.toDouble();

    // Legacy / Aliases
    result['Vol_Z'] = volZ1H;
    result['Elasticity'] = elasticity;
    result['Open'] = last.open;
    result['High'] = last.high;
    result['Low'] = last.low;
    result['Close'] = last.close;
    result['Volume'] = last.volume;

    print('🔍 [FEATURES] Calculated for symbol: $result');
    return result;
  }

  double _calculateVolZ(List<double> volumes, int window) {
    if (volumes.isEmpty) return 0.0;
    
    // Rolling logic for LAST element only
    // Python: r = df['volume'].rolling(window=window, min_periods=1)
    // We only need the stats for the *last* window
    
    final int start = math.max(0, volumes.length - window);
    final winSlice = volumes.sublist(start);
    
    if (winSlice.isEmpty) return 0.0;

    final n = winSlice.length;
    final mean = winSlice.reduce((a, b) => a + b) / n;
    
    if (n < 2) return 0.0; // Std dev requires > 1 item usually, but Python fillna(1.0)
    
    double sumSqDiff = 0.0;
    for (final v in winSlice) {
      sumSqDiff += math.pow(v - mean, 2);
    }
    
    // Sample standard deviation (divide by n-1)
    double std = math.sqrt(sumSqDiff / (n - 1));
    if (std == 0) std = 1.0;

    final lastVol = volumes.last;
    return (lastVol - mean) / std;
  }

  // Simple resampling logic
  List<OHLCVData> _resample(List<OHLCVData> bars, Duration interval) {
    if (bars.isEmpty) return [];
    
    final resampled = <OHLCVData>[];
    OHLCVData? currentBar;
    DateTime? bucketEnd;

    for (final bar in bars) {
      // Determine bucket (simplified: round down logic)
      final dt = bar.datetime;
      
      // Calculate bucket start based on absolute time
      // This is a rough approximation of pandas '4h' or '1D' resampling alignment
      int ms = dt.millisecondsSinceEpoch;
      int intervalMs = interval.inMilliseconds;
      int bucketStartMs = (ms ~/ intervalMs) * intervalMs;
      // final bucketStart = DateTime.fromMillisecondsSinceEpoch(bucketStartMs);
      final nextBucketStartMs = bucketStartMs + intervalMs;
      
      if (bucketEnd == null || ms >= bucketEnd.millisecondsSinceEpoch) {
        // Close previous bucket
        if (currentBar != null) {
          resampled.add(currentBar);
        }
        
        // Start new bucket
        bucketEnd = DateTime.fromMillisecondsSinceEpoch(nextBucketStartMs);
        currentBar = OHLCVData(
          symbol: bar.symbol,
          datetime: DateTime.fromMillisecondsSinceEpoch(bucketStartMs),
          open: bar.open,
          high: bar.high,
          low: bar.low,
          close: bar.close,
          volume: bar.volume,
        );
      } else {
        // Aggregate
        currentBar = OHLCVData(
          symbol: currentBar!.symbol,
          datetime: currentBar.datetime,
          open: currentBar.open,
          high: math.max(currentBar.high, bar.high),
          low: math.min(currentBar.low, bar.low),
          close: bar.close, // Close is always latest
          volume: currentBar.volume + bar.volume,
        );
      }
    }
    
    // Add final
    if (currentBar != null) {
      resampled.add(currentBar);
    }
    
    return resampled;
  }

  /// Load cached data for a symbol
  Future<Map<String, dynamic>?> _loadCache(String symbol) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final safeSymbol = symbol.replaceAll('.', '_');
      final file = File('${appDir.path}/$cacheDir/$safeSymbol.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        // Allow old data but mark not live
        // But if recently saved by this fetcher, it might be effectively live-ish?
        // Logic says loadCache always sets is_live=false unless logic overrides
        data['is_live'] = false; 
        return data;
      }
    } catch (_) {}
    return null;
  }

  /// Save data to cache
  Future<void> _saveCache(String symbol, Map<String, dynamic> data) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final safeSymbol = symbol.replaceAll('.', '_');
      final file = File('${appDir.path}/$cacheDir/$safeSymbol.json');
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('❌ Failed to save cache for $symbol: $e');
    }
  }

  Future<Map<String, dynamic>?> getData(String symbol, {String exchange = 'CSELK', bool force = false}) {
     return fetchSymbol(symbol, exchange: exchange, force: force);
  }

  Future<Map<String, bool>> retryFailed({String exchange = 'CSELK'}) async {
     final results = <String, bool>{};
     for (final symbol in List.from(failedSymbols)) {
       final data = await fetchSymbol(symbol, exchange: exchange, force: true);
       results[symbol] = data != null;
     }
     return results;
  }

  List<String> getFailedSymbols() => List.from(failedSymbols);
}
