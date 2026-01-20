/// Scan Engine - Parallel Stock Processing
/// 
/// High-performance scanning engine that processes multiple stocks
/// concurrently while offloading CPU-heavy tasks to isolates.

import 'dart:async';
import 'dart:isolate';

import '../models/stock_symbol.dart';
import 'data_fetcher.dart';
import 'model_inference.dart';

/// Result from scanning a single stock
class StockScanResult {
  final String symbol;
  final Map<String, double>? probabilities;
  final String? signalType;
  final double lastPrice;
  final String dataStatus;
  final String? timestamp;
  final String? error;

  StockScanResult({
    required this.symbol,
    this.probabilities,
    this.signalType,
    this.lastPrice = 0.0,
    this.dataStatus = 'Not Scanned',
    this.timestamp,
    this.error,
  });
}

/// High-performance scanning engine
class ScanEngine {
  final DataFetcher dataFetcher;
  final ModelInference modelInference;
  
  /// Maximum number of concurrent fetch operations
  static const int maxConcurrency = 5;

  ScanEngine({
    required this.dataFetcher,
    required this.modelInference,
  });

  /// Scan multiple stocks in parallel with batching
  Future<List<StockScanResult>> scanParallel(
    List<StockSymbol> stocks, {
    Function(int completed, int total)? onProgress,
  }) async {
    final results = <StockScanResult>[];
    int completed = 0;

    // Process in batches to avoid overwhelming the server
    for (var i = 0; i < stocks.length; i += maxConcurrency) {
      final batch = stocks.skip(i).take(maxConcurrency).toList();
      
      // Process entire batch concurrently
      final batchResults = await Future.wait(
        batch.map((stock) => _scanSingleStock(stock)),
      );
      
      results.addAll(batchResults);
      completed += batch.length;
      
      // Report progress
      onProgress?.call(completed, stocks.length);
    }

    return results;
  }

  /// Scan a single stock (fetch data + predict)
  Future<StockScanResult> _scanSingleStock(StockSymbol stock) async {
    try {
      // Fetch market data
      final data = await dataFetcher.getData(
        stock.symbol,
        exchange: stock.exchange,
      );

      if (data == null || !data.containsKey('features')) {
        return StockScanResult(
          symbol: stock.symbol,
          dataStatus: 'No Data',
        );
      }

      // Extract features
      final features = Map<String, double>.from(
        (data['features'] as Map).map(
          (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        ),
      );

      // Load models if not already loaded
      await modelInference.loadModels(stock.symbol);

      // Run prediction (CPU-heavy, but we'll keep it on main isolate for now)
      // In a future enhancement, this can be moved to a separate isolate
      final probs = modelInference.predict(stock.symbol, features);

      return StockScanResult(
        symbol: stock.symbol,
        probabilities: probs,
        lastPrice: (data['ohlcv']['close'] as num).toDouble(),
        dataStatus: data['is_live'] == true ? 'Live' : 'Cached',
        timestamp: data['timestamp'] as String?,
      );
    } catch (e) {
      print('❌ [ScanEngine] Error scanning ${stock.symbol}: $e');
      return StockScanResult(
        symbol: stock.symbol,
        dataStatus: 'Error',
        error: e.toString(),
      );
    }
  }

  /// Run prediction in an isolate (for future optimization)
  /// This will be used when we need to process very large lists
  static Future<Map<String, double>> _predictInIsolate(
    Map<String, dynamic> params,
  ) async {
    // TODO: Implement isolate-based prediction
    // This requires making ModelInference serializable
    return {};
  }
}
