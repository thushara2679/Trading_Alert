/// CSV Handler for Stock Watchlist Import/Export
/// Protocol: Antigravity - Mobile Module
///
/// Supports the same CSV format as the PC app:
/// - Single column: Header is Exchange name, rows are symbols
/// - Multi column: Exchange, Symbol columns

import 'dart:io';
import '../models/stock_symbol.dart';

class CsvHandler {
  /// Import stocks from CSV file (same format as PC app)
  static Future<List<StockSymbol>> importFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', filePath);
    }

    final content = await file.readAsString();
    return parseContent(content);
  }

  /// Parse CSV content string
  static List<StockSymbol> parseContent(String content) {
    final lines = content
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return [];

    final stocks = <StockSymbol>[];
    final header = lines[0].split(',');

    // Single column format: Header is Exchange name
    if (header.length == 1) {
      final exchange = header[0].trim();
      for (int i = 1; i < lines.length; i++) {
        final symbol = lines[i].trim();
        if (symbol.isNotEmpty &&
            symbol.toLowerCase() != exchange.toLowerCase()) {
          stocks.add(StockSymbol.fromCsvRow(symbol, exchange));
        }
      }
    }
    // Multi column format
    else {
      final exchIdx = _findColumnIndex(header, ['exchange', 'exch', 'mkt']);
      final symIdx = _findColumnIndex(header, [
        'symbol',
        'ticker',
        'stock',
        'name',
      ]);

      if (symIdx == -1) {
        throw FormatException('Could not identify Symbol column');
      }

      for (int i = 1; i < lines.length; i++) {
        final cols = lines[i].split(',');
        if (cols.length <= symIdx) continue;

        final exchange = exchIdx >= 0 && cols.length > exchIdx
            ? cols[exchIdx].trim()
            : 'Unknown';
        final symbol = cols[symIdx].trim();

        if (symbol.isNotEmpty && symbol.toLowerCase() != 'nan') {
          stocks.add(StockSymbol.fromCsvRow(symbol, exchange));
        }
      }
    }

    return stocks;
  }

  /// Export alerted stocks to CSV file
  static Future<String> exportAlerts(
    List<StockSymbol> stocks,
    String outputPath,
  ) async {
    final alertedStocks = stocks.where((s) => s.hasSignal).toList();

    final buffer = StringBuffer();
    buffer.writeln('Exchange,Symbol,Signal,Prob_4H,Prob_5D,Timestamp');

    for (final stock in alertedStocks) {
      buffer.writeln(stock.toCsvRow());
    }

    final file = File(outputPath);
    await file.writeAsString(buffer.toString());
    return outputPath;
  }

  /// Export all stocks (same format as import - single column)
  static Future<String> exportWatchlist(
    List<StockSymbol> stocks,
    String outputPath,
  ) async {
    if (stocks.isEmpty) return outputPath;

    // Group by exchange
    final byExchange = <String, List<String>>{};
    for (final stock in stocks) {
      byExchange.putIfAbsent(stock.exchange, () => []).add(stock.symbol);
    }

    final buffer = StringBuffer();

    // For simplicity, export first exchange group in single-column format
    final firstExchange = byExchange.keys.first;
    buffer.writeln(firstExchange);
    for (final symbol in byExchange[firstExchange]!) {
      buffer.writeln(symbol);
    }

    final file = File(outputPath);
    await file.writeAsString(buffer.toString());
    return outputPath;
  }

  static int _findColumnIndex(List<String> headers, List<String> keywords) {
    for (int i = 0; i < headers.length; i++) {
      final headerLower = headers[i].toLowerCase().trim();
      for (final kw in keywords) {
        if (headerLower.contains(kw)) return i;
      }
    }
    return -1;
  }
}
