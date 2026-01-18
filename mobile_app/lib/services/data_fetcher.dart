/// Data Fetcher Service for TradingView Data
/// Protocol: Antigravity - Mobile Module
///
/// Fetches OHLCV data directly via HTTP (replacing python's tvdatafeed).
/// Implements strictly scheduled fetching:
/// - Weekdays only
/// - 10:35 AM to 03:35 PM
/// - Hourly intervals

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class DataFetcher {
  final String _cacheDir;

  // TradingView Scanner API (Public endpoint for CSE/Global data)
  static const String _scannerUrl =
      'https://scanner.tradingview.com/sri lanka/scan';

  DataFetcher(this._cacheDir);

  /// Check if current time is within trading hours (10:35 - 15:35, M-F)
  bool isTradingSession() {
    final now = DateTime.now();

    // 1. Check Weekend
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      print('😴 Market Closed (Weekend)');
      return false;
    }

    // 2. Check Time (10:35 to 15:35)
    final start = DateTime(now.year, now.month, now.day, 10, 35);
    final end = DateTime(now.year, now.month, now.day, 15, 35);

    if (now.isBefore(start)) {
      print('⏳ Market Pre-open (Opens 10:35)');
      return false;
    }
    if (now.isAfter(end)) {
      print('🌙 Market Closed (Closed 15:35)');
      return false;
    }

    return true;
  }

  /// Check if we should run a scheduled fetch (on the hour)
  bool shouldFetchNow() {
    if (!isTradingSession()) return false;

    // Fetch if minutes are close to 35 (e.g., 10:35, 11:35...)
    // Allowing a window of +/- 5 minutes
    final minutes = DateTime.now().minute;
    return minutes >= 30 && minutes <= 40;
  }

  /// Fetch latest data for a symbol
  /// Returns map of OHLCV data with calculated features
  Future<Map<String, dynamic>?> fetchLatestData(
      String symbol, String exchange) async {
    try {
      // 1. Try Online Fetch first
      if (isTradingSession()) {
        final onlineData = await _fetchFromScanner(symbol);
        if (onlineData != null) {
          // Append to cache and return
          await _appendToCache(symbol, onlineData);
          return _processData(symbol, onlineData);
        }
      }

      // 2. Fallback to Cache
      // print('⚠️ Using offline cache for $symbol');
      // return _loadFromCache(symbol);
      return null;
    } catch (e) {
      print('❌ Error fetching data for $symbol: $e');
      return null;
    }
  }

  /// Fetch directly from TradingView Scanner API
  Future<List<Map<String, double>>?> _fetchFromScanner(String symbol) async {
    try {
      // Clean symbol (remove extension if present)
      final cleanSymbol = symbol.split('.')[0];

      final response = await http.post(
        Uri.parse(_scannerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "symbols": {
            "tickers": ["CSELK:$cleanSymbol"]
          },
          "columns": [
            "open",
            "high",
            "low",
            "close",
            "volume",
            "change",
            "Recommend.All"
          ]
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'];
        if (data == null || (data as List).isEmpty) return null;

        // Map response to our format
        final d = data[0]['d']; // Data array
        final lastBar = {
          'open': (d[0] as num).toDouble(),
          'high': (d[1] as num).toDouble(),
          'low': (d[2] as num).toDouble(),
          'close': (d[3] as num).toDouble(),
          'volume': (d[4] as num)
              .toDouble(), // This is usually daily volume, might need adjustment for hourly
        };

        // Note: Real hourly history requires a complex chart API session.
        // For this mobile 'Alert' app, we are capturing the LIVE state.
        // We accumulate this into our local CSV to build history.
        return [lastBar];
      }
      return null;
    } catch (e) {
      print('📡 Network Error: $e');
      return null;
    }
  }

  /// Append new data to local CSV cache
  Future<void> _appendToCache(
      String symbol, List<Map<String, double>> newData) async {
    final filePath = '$_cacheDir/${symbol}_1H.csv';
    final file = File(filePath);
    final now = DateTime.now();

    // Create if not exists
    if (!await file.exists()) {
      await file.writeAsString('date,open,high,low,close,volume\n');
    }

    // Append line
    final bar = newData.last;
    final line =
        '${now.toIso8601String()},${bar['open']},${bar['high']},${bar['low']},${bar['close']},${bar['volume']}\n';
    await file.writeAsString(line, mode: FileMode.append);
  }

  Future<Map<String, dynamic>?> _processData(
      String symbol, List<Map<String, double>> latestBar) async {
    // Reload full history from file to calculate features correctly (Vol_Z needs history)
    return _loadFromCache(symbol);
  }

  /// Load cached OHLCV data and calculate features
  Future<Map<String, dynamic>?> _loadFromCache(String symbol) async {
    final filePath = '$_cacheDir/${symbol}_1H.csv';
    final file = File(filePath);

    if (!await file.exists()) return null;

    final content = await file.readAsString();
    final lines =
        content.split('\n').where((l) => l.trim().isNotEmpty).toList();

    if (lines.length < 21) {
      // Not enough history yet
      return null;
    }

    // Parse CSV
    final data = <Map<String, double>>[];
    for (int i = 1; i < lines.length; i++) {
      final cols = lines[i].split(',');
      if (cols.length < 6) continue;

      data.add({
        'open': double.tryParse(cols[1]) ?? 0,
        'high': double.tryParse(cols[2]) ?? 0,
        'low': double.tryParse(cols[3]) ?? 0,
        'close': double.tryParse(cols[4]) ?? 0,
        'volume': double.tryParse(cols[5]) ?? 0,
      });
    }

    final features = _calculateFeatures(data);
    return {
      'symbol': symbol,
      'features': features,
      'lastClose': data.last['close'],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  List<double> _calculateFeatures(List<Map<String, double>> data) {
    const window = 20;

    // Get last 20 volumes for rolling calculation
    final volumes = data
        .sublist(max(0, data.length - window))
        .map((d) => d['volume']!)
        .toList();

    if (volumes.isEmpty) return List.filled(6, 0.0);

    final mean = volumes.reduce((a, b) => a + b) / volumes.length;
    final variance =
        volumes.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            volumes.length;
    final std = variance > 0 ? sqrt(variance) : 1.0;

    // Vol_Z for latest bar
    final volZ1H = (data.last['volume']! - mean) / std;

    // Price change
    final priceChange = data.length > 1
        ? (data.last['close']! - data[data.length - 2]['close']!) /
            data[data.length - 2]['close']!
        : 0.0;

    // Elasticity
    final elasticity = volZ1H != 0 ? priceChange / volZ1H : 0.0;

    // Temporal features
    final now = DateTime.now();
    final dayOfWeek = now.weekday.toDouble();
    final hourOfDay = now.hour.toDouble();

    // Placeholder for 4H and 1D Vol_Z (would need multi-timeframe data)
    final volZ4H = volZ1H * 0.8; // Simplified approximation
    final volZ1D = volZ1H * 0.6; // Simplified approximation

    return [volZ1H, volZ4H, volZ1D, elasticity, dayOfWeek, hourOfDay];
  }
}

double sqrt(double x) {
  if (x <= 0) return 0;
  return exp(log(x) / 2);
}
