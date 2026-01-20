import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'interval.dart';
import 'models/ohlcv_data.dart';

/// TvDatafeed - TradingView historical data downloader.
///
/// Fetches historical OHLCV data from TradingView using WebSocket protocol.
class TvDatafeed {
  static const String _signInUrl =
      'https://www.tradingview.com/accounts/signin/';
  static const String _searchUrl =
      'https://symbol-search.tradingview.com/symbol_search/?text={text}&hl=1&exchange={exchange}&lang=en&type=&domain=production';
  static const String _wsUrl = 'wss://data.tradingview.com/socket.io/websocket';
  static const Map<String, String> _wsHeaders = {
    'Origin': 'https://data.tradingview.com',
  };
  static const Duration _wsTimeout = Duration(seconds: 5);

  final Logger _logger = Logger();
  final Dio _dio = Dio();

  String? _token;
  WebSocketChannel? _ws;
  String? _session;
  String? _chartSession;
  bool _isInitialized = false;

  /// Whether to enable debug logging for WebSocket messages.
  bool wsDebug = false;

  /// Initialize the TvDatafeed client.
  ///
  /// Parameters:
  /// - [username]: TradingView username (optional).
  /// - [password]: TradingView password (optional).
  Future<void> init({String? username, String? password}) async {
    _token = await _auth(username, password);

    if (_token == null) {
      _token = 'unauthorized_user_token';
      _logger.w('Using nologin method, data access may be limited');
    }

    _session = _generateSession();
    _chartSession = _generateChartSession();
    _isInitialized = true;
  }

  /// Authenticate with TradingView.
  Future<String?> _auth(String? username, String? password) async {
    if (username == null || password == null) {
      return null;
    }

    try {
      final response = await _dio.post(
        _signInUrl,
        data: {
          'username': username,
          'password': password,
          'remember': 'on',
        },
        options: Options(
          headers: {'Referer': 'https://www.tradingview.com'},
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      if (response.data is Map && response.data['user'] != null) {
        return response.data['user']['auth_token'] as String?;
      }
    } catch (e) {
      _logger.e('Error during signin: $e');
    }

    return null;
  }

  /// Create WebSocket connection.
  Future<void> _createConnection() async {
    _logger.d('Creating WebSocket connection');
    
    // Use IOWebSocketChannel to pass the Origin header which is required by TradingView
    try {
      _ws = IOWebSocketChannel.connect(
        Uri.parse(_wsUrl),
        headers: _wsHeaders,
      );
    } catch (e) {
      // Fallback or rethrow
      _logger.e('Failed to create IOWebSocketConnection: $e');
      rethrow;
    }

    // Wait for connection to be established
    await Future.delayed(const Duration(milliseconds: 500));
  }

  /// Generate random session ID.
  String _generateSession() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    final random = Random();
    final randomString = List.generate(
      12,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return 'qs_$randomString';
  }

  /// Generate random chart session ID.
  String _generateChartSession() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    final random = Random();
    final randomString = List.generate(
      12,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return 'cs_$randomString';
  }

  /// Prepend header to message.
  String _prependHeader(String st) {
    return '~m~${st.length}~m~$st';
  }

  /// Construct message payload.
  String _constructMessage(String func, List<dynamic> paramList) {
    return jsonEncode({'m': func, 'p': paramList});
  }

  /// Create formatted message.
  String _createMessage(String func, List<dynamic> paramList) {
    return _prependHeader(_constructMessage(func, paramList));
  }

  /// Send message via WebSocket.
  void _sendMessage(String func, List<dynamic> args) {
    final message = _createMessage(func, args);
    if (wsDebug) {
      print('Sending: $message');
    }
    _ws?.sink.add(message);
  }

  /// Parse raw WebSocket data into OHLCV list.
  List<OHLCVData> _parseRawData(String rawData, String symbol) {
    try {
      // Find the start of the "s" array
      final start = rawData.indexOf('"s":');
      if (start == -1) {
        _logger.e('No "s" data found in response');
        return [];
      }

      // Find the start of the array bracket
      final arrayStart = rawData.indexOf('[', start);
      if (arrayStart == -1) return [];

      // Find the matching closing bracket for the array
      int bracketCount = 0;
      int arrayEnd = -1;
      for (int i = arrayStart; i < rawData.length; i++) {
        if (rawData[i] == '[') {
          bracketCount++;
        } else if (rawData[i] == ']') {
          bracketCount--;
          if (bracketCount == 0) {
            arrayEnd = i + 1;
            break;
          }
        }
      }

      if (arrayEnd == -1) {
        _logger.e('Malformed JSON array in response');
        return [];
      }

      final jsonArrayString = rawData.substring(arrayStart, arrayEnd);
      final List<dynamic> jsonList = jsonDecode(jsonArrayString);

      final List<OHLCVData> result = [];

      for (final item in jsonList) {
        if (item is Map && item['v'] is List) {
          final v = item['v'] as List;
          if (v.length >= 6) {
            final timestamp = DateTime.fromMillisecondsSinceEpoch(
              ((v[0] as num) * 1000).toInt(),
            );

            result.add(OHLCVData(
              symbol: symbol,
              datetime: timestamp,
              open: (v[1] as num).toDouble(),
              high: (v[2] as num).toDouble(),
              low: (v[3] as num).toDouble(),
              close: (v[4] as num).toDouble(),
              volume: (v[5] as num).toDouble(),
            ));
          }
        }
      }

      return result;
    } catch (e) {
      _logger.e('Error parsing data: $e');
      return [];
    }
  }

  /// Format symbol string for TradingView.
  String _formatSymbol(String symbol, String exchange, {int? contract}) {
    if (symbol.contains(':')) {
      return symbol;
    }

    if (contract == null) {
      return '$exchange:$symbol';
    }

    return '$exchange:$symbol$contract!';
  }

  /// Get historical OHLCV data.
  ///
  /// Parameters:
  /// - [symbol]: Symbol name (e.g., 'AAPL', 'NIFTY').
  /// - [exchange]: Exchange name (e.g., 'NASDAQ', 'NSE').
  /// - [interval]: Chart interval (default: daily).
  /// - [nBars]: Number of bars to download (default: 10, max: 5000).
  /// - [futContract]: Futures contract number (optional).
  /// - [extendedSession]: Include extended session data (default: false).
  ///
  /// Returns a list of [OHLCVData] objects.
  Future<List<OHLCVData>> getHist({
    required String symbol,
    String exchange = 'NSE',
    Interval interval = Interval.inDaily,
    int nBars = 10,
    int? futContract,
    bool extendedSession = false,
  }) async {
    if (!_isInitialized) {
      throw StateError('TvDatafeed not initialized. Call init() first.');
    }

    final formattedSymbol = _formatSymbol(
      symbol,
      exchange,
      contract: futContract,
    );

    await _createConnection();

    final completer = Completer<List<OHLCVData>>();
    final rawDataBuffer = StringBuffer();

    // Listen for WebSocket messages
    _ws!.stream.listen(
      (data) {
        rawDataBuffer.write(data.toString());
        rawDataBuffer.write('\n');

        if (data.toString().contains('series_completed')) {
          final result =
              _parseRawData(rawDataBuffer.toString(), formattedSymbol);
          if (!completer.isCompleted) {
            completer.complete(result);
          }
        }
      },
      onError: (error) {
        _logger.e('WebSocket error: $error');
        if (!completer.isCompleted) {
          completer.complete([]);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          final result =
              _parseRawData(rawDataBuffer.toString(), formattedSymbol);
          completer.complete(result);
        }
      },
    );

    // Send initialization messages
    _sendMessage('set_auth_token', [_token]);
    _sendMessage('chart_create_session', [_chartSession, '']);
    _sendMessage('quote_create_session', [_session]);
    _sendMessage('quote_set_fields', [
      _session,
      'ch',
      'chp',
      'current_session',
      'description',
      'local_description',
      'language',
      'exchange',
      'fractional',
      'is_tradable',
      'lp',
      'lp_time',
      'minmov',
      'minmove2',
      'original_name',
      'pricescale',
      'pro_name',
      'short_name',
      'type',
      'update_mode',
      'volume',
      'currency_code',
      'rchp',
      'rtc',
    ]);
    _sendMessage('quote_add_symbols', [
      _session,
      formattedSymbol,
      {
        'flags': ['force_permission']
      },
    ]);
    _sendMessage('quote_fast_symbols', [_session, formattedSymbol]);
    _sendMessage('resolve_symbol', [
      _chartSession,
      'symbol_1',
      '={"symbol":"$formattedSymbol","adjustment":"splits","session":${extendedSession ? '"extended"' : '"regular"'}}',
    ]);
    _sendMessage('create_series', [
      _chartSession,
      's1',
      's1',
      'symbol_1',
      interval.value,
      nBars,
    ]);
    _sendMessage('switch_timezone', [_chartSession, 'exchange']);

    _logger.d('Getting data for $formattedSymbol...');

    // Wait for result with timeout
    try {
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _logger.e('Timeout waiting for data');
          return [];
        },
      );
    } finally {
      await _ws?.sink.close();
      _ws = null;
    }
  }

  /// Search for symbols on TradingView.
  ///
  /// Parameters:
  /// - [text]: Search query.
  /// - [exchange]: Filter by exchange (optional).
  ///
  /// Returns a list of search results.
  Future<List<Map<String, dynamic>>> searchSymbol(
    String text, {
    String exchange = '',
  }) async {
    final url = _searchUrl
        .replaceAll('{text}', text)
        .replaceAll('{exchange}', exchange);

    try {
      final response = await _dio.get(url);

      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }
    } catch (e) {
      _logger.e('Search error: $e');
    }

    return [];
  }

  /// Check if client is initialized.
  bool get isInitialized => _isInitialized;

  /// Dispose of resources.
  Future<void> dispose() async {
    await _ws?.sink.close();
    _ws = null;
    _dio.close();
  }
}
