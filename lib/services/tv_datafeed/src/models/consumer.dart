import 'dart:async';
import 'ohlcv_data.dart';
import 'seis.dart';

/// Consumer for processing Seis data with callbacks.
///
/// This class uses Dart Streams instead of Python threading.
/// Data reception and callback execution is handled asynchronously.
class Consumer {
  /// The Seis this consumer is subscribed to.
  final Seis seis;

  /// The callback function to execute when new data arrives.
  final void Function(Seis seis, OHLCVData data) callback;

  /// Internal stream controller for data buffering.
  final StreamController<OHLCVData> _controller;

  /// Stream subscription for the callback.
  StreamSubscription<OHLCVData>? _subscription;

  /// Whether the consumer is actively listening.
  bool _isRunning = false;

  Consumer({
    required this.seis,
    required this.callback,
  }) : _controller = StreamController<OHLCVData>.broadcast();

  /// Start the data processing.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _subscription = _controller.stream.listen(
      (data) {
        try {
          callback(seis, data);
        } catch (e) {
          // Log error and continue
          print('Consumer callback error: $e');
        }
      },
      onError: (error) {
        print('Consumer stream error: $error');
      },
    );
  }

  /// Stop the data processing.
  void stop() {
    _isRunning = false;
    _subscription?.cancel();
    _subscription = null;
  }

  /// Put new data into the buffer to be processed.
  ///
  /// Parameters:
  /// - [data]: The OHLCV data to process.
  void put(OHLCVData data) {
    if (!_controller.isClosed) {
      _controller.sink.add(data);
    }
  }

  /// Check if the consumer is running.
  bool get isRunning => _isRunning;

  /// Get the data stream for direct subscription.
  Stream<OHLCVData> get stream => _controller.stream;

  /// Dispose of resources.
  Future<void> dispose() async {
    stop();
    await _controller.close();
  }

  @override
  String toString() {
    return 'Consumer(seis: $seis, running: $_isRunning)';
  }
}
