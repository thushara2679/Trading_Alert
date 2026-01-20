/// Watchlist Screen - Stock List with Scan Functionality
/// Converted from: screens/watchlist.py
/// 
/// Main screen showing the watchlist with scan and data fetching.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../models/stock_symbol.dart';
import '../services/data_fetcher.dart';
import '../services/model_inference.dart';
import '../services/signal_filter.dart';

class WatchlistScreen extends StatefulWidget {
  final DataFetcher dataFetcher;
  final ModelInference modelInference;

  const WatchlistScreen({
    super.key,
    required this.dataFetcher,
    required this.modelInference,
  });

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<StockSymbol> stocks = [];
  bool isScanning = false;
  double scanProgress = 0.0;
  String statusText = 'Ready';

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '📊 Watchlist',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.file_upload, color: Colors.white70),
                tooltip: 'Import CSV',
                onPressed: _importCsv,
              ),
            ],
          ),
        ),

        // Scan Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.radar),
                  label: const Text('🔍 Scan All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: isScanning ? null : _scanAll,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${stocks.length} stocks',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),

        // Progress Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: LinearProgressIndicator(
            value: scanProgress,
            backgroundColor: const Color(0xFF1E293B),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            minHeight: 8,
          ),
        ),

        // Status Text
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          alignment: Alignment.centerLeft,
          child: Text(
            statusText,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),

        // Stock List
        Expanded(
          child: stocks.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: stocks.length,
                  itemBuilder: (context, index) => _buildStockTile(stocks[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          const Text(
            'No stocks in watchlist',
            style: TextStyle(color: Colors.grey),
          ),
          TextButton(
            onPressed: _importCsv,
            child: const Text('Import CSV'),
          ),
        ],
      ),
    );
  }

  Widget _buildStockTile(StockSymbol stock) {
    final signalColor = SignalFilter.getColor(stock.signalType);

    // Calculate time ago
    String timeText = '';
    if (stock.lastUpdated != null) {
      try {
        final scanTime = DateTime.parse(stock.lastUpdated!);
        final delta = DateTime.now().difference(scanTime);
        final minutes = delta.inMinutes;
        if (minutes < 60) {
          timeText = '${minutes}m ago';
        } else {
          timeText = '${minutes ~/ 60}h ago';
        }
      } catch (_) {}
    }

    // Status color
    Color statusColor = Colors.grey;
    if (stock.dataStatus == 'Live') {
      statusColor = Colors.green;
    } else if (stock.dataStatus == 'Cached') {
      statusColor = Colors.orange;
    } else if (stock.dataStatus == 'No Data') {
      statusColor = Colors.red;
    }

    return Card(
      color: stock.signalType != null ? const Color(0xFF1E293B) : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor: signalColor,
              child: Text(
                stock.symbol.substring(0, 2).toUpperCase(),
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),

            // Symbol and Exchange
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.symbol,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    stock.exchange,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),

            // Signal Info
            if (stock.signalType != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Signal Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: signalColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      stock.signalType!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Probabilities
                  if (stock.prob4h != null)
                    Text(
                      '4H:${stock.prob4h!.toInt()}% 2D:${stock.prob2d!.toInt()}% 5D:${stock.prob5d!.toInt()}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[300],
                      ),
                    ),
                  const SizedBox(height: 2),
                  // Status Row
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 10, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        stock.dataStatus,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      if (timeText.isNotEmpty) ...[
                        Text(
                          ' • $timeText',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                        ),
                      ],
                    ],
                  ),
                ],
              )
            else
              Text(
                stock.dataStatus,
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanAll() async {
    if (isScanning || stocks.isEmpty) return;

    setState(() {
      isScanning = true;
      scanProgress = 0.0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚀 Scanning ${stocks.length} stocks...'),
        duration: const Duration(seconds: 2),
      ),
    );

    final total = stocks.length;

    for (var i = 0; i < stocks.length; i++) {
      final stock = stocks[i];

      setState(() {
        statusText = 'Fetching ${stock.symbol} (${i + 1}/$total)...';
        scanProgress = (i + 1) / total;
      });

      // Fetch data
      final data = await widget.dataFetcher.getData(
        stock.symbol,
        exchange: stock.exchange,
      );

      if (data != null && data.containsKey('features')) {
        setState(() {
          statusText = 'Analyzing ${stock.symbol}...';
        });

        // Load models and predict
        await widget.modelInference.loadModels(stock.symbol);
        final features = Map<String, double>.from(
          (data['features'] as Map).map(
            (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
          ),
        );
        final probs = widget.modelInference.predict(stock.symbol, features);

        // Evaluate signal
        final result = SignalFilter.evaluate(probs);

        stocks[i] = stock.copyWith(
          prob4h: probs['4H'],
          prob2d: probs['2D'],
          prob5d: probs['5D'],
          signalType: result.typeName,
          dataStatus: data['is_live'] == true ? 'Live' : 'Cached',
          lastUpdated: data['timestamp'] as String?,
        );
      } else {
        stocks[i] = stock.copyWith(
          dataStatus: 'No Data',
          signalType: null,
        );
      }

      setState(() {});
    }

    // Sort by signal priority
    stocks.sort((a, b) {
      final priorityA = SignalFilter.getSignalPriority(a.signalType ?? 'NEUTRAL');
      final priorityB = SignalFilter.getSignalPriority(b.signalType ?? 'NEUTRAL');
      return priorityB.compareTo(priorityA);
    });

    setState(() {
      isScanning = false;
      scanProgress = 0.0;
      statusText = 'Scan complete (${widget.dataFetcher.getFailedSymbols().length} failed)';
    });

    await _saveStocks();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Scan Complete'),
          backgroundColor: Color(0xFF15803D),
        ),
      );
    }
  }

  Future<void> _importCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = File(result.files.single.path!);
      final content = await file.readAsString();

      final lines = content.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) return;

      stocks.clear();

      // Logic: Row 1 = Exchange, Row 2+ = Symbols
      final exchange = lines[0].split(',')[0].trim();

      var addedCount = 0;
      for (var i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final parts = line.split(',');
        final rawSymbol = parts[0].trim();

        // Skip header row
        if (rawSymbol.toLowerCase() == 'symbol') continue;

        stocks.add(StockSymbol(symbol: rawSymbol, exchange: exchange));
        addedCount++;
      }

      setState(() {});
      await _saveStocks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Imported $addedCount stocks from $exchange'),
            backgroundColor: const Color(0xFF15803D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Import failed: $e'),
            backgroundColor: const Color(0xFFB91C1C),
          ),
        );
      }
    }
  }

  Future<void> _saveStocks() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/stocks.json');
      final data = stocks.map((s) => s.toJson()).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('Failed to save stocks: $e');
    }
  }

  Future<void> _loadStocks() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/stocks.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as List;
        stocks = data
            .map((d) => StockSymbol.fromJson(d as Map<String, dynamic>))
            .toList();
        setState(() {});
      }
    } catch (e) {
      print('Failed to load stocks: $e');
    }
  }
}
