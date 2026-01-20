import 'dart:async';
import 'package:logger/logger.dart';
import 'tv_datafeed.dart';
import 'interval.dart';
import 'models/ohlcv_data.dart';
import 'models/seis.dart';
import 'models/consumer.dart';

/// Maximum number of retries to get valid data from TradingView.
const int retryLimit = 50;

/// TvDatafeedLive - Live data feed manager for TradingView.
///
/// Manages multiple symbol-exchange-interval sets (Seis) for live monitoring.
/// Uses Dart Streams and async/await instead of Python threading.
class TvDatafeedLive extends TvDatafeed {
  final Logger _logger = Logger();

  /// Map of Seis to their update times.
  final Map<Seis, DateTime> _seisUpdateTimes = {};

  /// Map of Seis to their consumers.
  final Map<Seis, List<Consumer>> _consumers = {};

  /// Main loop timer.
  Timer? _mainLoopTimer;

  /// Flag to indicate if the live feed is running.
  bool _isRunning = false;

  /// Lock for thread-safe operations.
  bool _isLocked = false;

  /// Create and add a new Seis to live feed.
  ///
  /// Parameters:
  /// - [symbol]: Ticker string for symbol.
  /// - [exchange]: Exchange where symbol is listed.
  /// - [interval]: Chart interval.
  ///
  /// Returns the created [Seis] or existing one if already present.
  Future<Seis> newSeis({
    required String symbol,
    required String exchange,
    required Interval interval,
  }) async {
    // Check if Seis already exists
    final existingSeis = _findSeis(symbol, exchange, interval);
    if (existingSeis != null) {
      return existingSeis;
    }

    // Validate symbol exists on TradingView
    final searchResults = await searchSymbol(symbol, exchange: exchange);
    final isValid = searchResults.any(
      (item) => item['symbol'] == symbol && item['exchange'] == exchange,
    );

    if (!isValid && searchResults.isEmpty) {
      throw ArgumentError(
        'Symbol $symbol on exchange $exchange not found on TradingView',
      );
    }

    // Create new Seis
    final seis = Seis(symbol: symbol, exchange: exchange, interval: interval);

    // Acquire lock
    await _acquireLock();

    try {
      // Get initial data to establish baseline timestamp
      final initialData = await getHist(
        symbol: symbol,
        exchange: exchange,
        interval: interval,
        nBars: 2,
      );

      if (initialData.isNotEmpty) {
        seis.updateTimestamp(initialData.first.datetime);
      }

      // Add to tracking
      _seisUpdateTimes[seis] = DateTime.now().add(interval.duration);
      _consumers[seis] = [];

      // Start main loop if not running
      if (!_isRunning) {
        _startMainLoop();
      }
    } finally {
      _releaseLock();
    }

    return seis;
  }

  /// Remove Seis from live feed.
  ///
  /// Parameters:
  /// - [seis]: Seis object to remove.
  Future<bool> delSeis(Seis seis) async {
    if (!_seisUpdateTimes.containsKey(seis)) {
      throw ArgumentError('Seis is not listed');
    }

    await _acquireLock();

    try {
      // Stop all consumers for this Seis
      final consumers = _consumers[seis] ?? [];
      for (final consumer in consumers) {
        consumer.stop();
        await consumer.dispose();
      }

      // Remove from tracking
      _seisUpdateTimes.remove(seis);
      _consumers.remove(seis);

      // Stop main loop if no more Seis
      if (_seisUpdateTimes.isEmpty) {
        _stopMainLoop();
      }
    } finally {
      _releaseLock();
    }

    return true;
  }

  /// Create a new Consumer for a Seis with the provided callback.
  ///
  /// Parameters:
  /// - [seis]: Seis object to subscribe to.
  /// - [callback]: Function to call when new data arrives.
  Future<Consumer> newConsumer(
    Seis seis,
    void Function(Seis seis, OHLCVData data) callback,
  ) async {
    if (!_seisUpdateTimes.containsKey(seis)) {
      throw ArgumentError('Seis is not listed');
    }

    await _acquireLock();

    try {
      final consumer = Consumer(seis: seis, callback: callback);
      _consumers[seis]?.add(consumer);
      consumer.start();

      return consumer;
    } finally {
      _releaseLock();
    }
  }

  /// Remove a consumer from its Seis.
  ///
  /// Parameters:
  /// - [consumer]: Consumer to remove.
  Future<bool> delConsumer(Consumer consumer) async {
    await _acquireLock();

    try {
      _consumers[consumer.seis]?.remove(consumer);
      consumer.stop();
      await consumer.dispose();
    } finally {
      _releaseLock();
    }

    return true;
  }

  /// Find existing Seis by parameters.
  Seis? _findSeis(String symbol, String exchange, Interval interval) {
    for (final seis in _seisUpdateTimes.keys) {
      if (seis.symbol == symbol &&
          seis.exchange == exchange &&
          seis.interval == interval) {
        return seis;
      }
    }
    return null;
  }

  /// Start the main monitoring loop.
  void _startMainLoop() {
    if (_isRunning) return;
    _isRunning = true;

    _logger.i('Starting live feed main loop');

    // Check every second for expired intervals
    _mainLoopTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkAndFetchData(),
    );
  }

  /// Stop the main monitoring loop.
  void _stopMainLoop() {
    _mainLoopTimer?.cancel();
    _mainLoopTimer = null;
    _isRunning = false;
    _logger.i('Stopped live feed main loop');
  }

  /// Check for expired intervals and fetch new data.
  Future<void> _checkAndFetchData() async {
    if (_isLocked) return;

    final now = DateTime.now();
    final expiredSeis = <Seis>[];

    // Find expired Seis
    for (final entry in _seisUpdateTimes.entries) {
      if (now.isAfter(entry.value)) {
        expiredSeis.add(entry.key);
      }
    }

    if (expiredSeis.isEmpty) return;

    await _acquireLock();

    try {
      for (final seis in expiredSeis) {
        // Retry logic
        for (var retry = 0; retry < retryLimit; retry++) {
          try {
            final data = await getHist(
              symbol: seis.symbol,
              exchange: seis.exchange,
              interval: seis.interval,
              nBars: 2,
            );

            if (data.isNotEmpty && seis.isNewData(data.first.datetime)) {
              // Push to all consumers
              final consumers = _consumers[seis] ?? [];
              for (final consumer in consumers) {
                consumer.put(data.first);
              }

              // Update next check time
              _seisUpdateTimes[seis] = now.add(seis.interval.duration);
              break;
            }
          } catch (e) {
            _logger.w('Retry $retry for ${seis.symbol}: $e');
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
      }
    } finally {
      _releaseLock();
    }
  }

  /// Acquire lock for thread-safe operations.
  Future<void> _acquireLock() async {
    while (_isLocked) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    _isLocked = true;
  }

  /// Release lock.
  void _releaseLock() {
    _isLocked = false;
  }

  /// Get all active Seis.
  List<Seis> get activeSeis => _seisUpdateTimes.keys.toList();

  /// Check if live feed is running.
  bool get isRunning => _isRunning;

  /// Stop and clean up the live feed.
  @override
  Future<void> dispose() async {
    _stopMainLoop();

    // Dispose all consumers
    for (final consumers in _consumers.values) {
      for (final consumer in consumers) {
        consumer.stop();
        await consumer.dispose();
      }
    }

    _consumers.clear();
    _seisUpdateTimes.clear();

    await super.dispose();
  }
}
