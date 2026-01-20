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
import '../services/scan_engine.dart';
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
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white70),
                tooltip: 'Menu',
                onSelected: (value) {
                  if (value == 'import') _importCsv();
                  if (value == 'clear_results') _clearResults();
                  if (value == 'clear_watchlist') _clearWatchlist();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'import',
                    child: Row(
                      children: [
                        Icon(Icons.file_upload, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Import CSV'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear_results',
                    child: Row(
                      children: [
                        Icon(Icons.cleaning_services, size: 20, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Clear Scan Results'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear_watchlist',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Clear Watchlist'),
                      ],
                    ),
                  ),
                ],
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
                  Row(
                    children: [
                      Text(
                        stock.exchange,
                        style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                      ),
                      if (stock.lastPrice > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            stock.lastPrice.toStringAsFixed(2),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ),
                      ],
                    ],
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
        content: Text('🚀 Turbo Scan: ${stocks.length} stocks (parallel)...'),
        duration: const Duration(seconds: 2),
      ),
    );

    // Create scan engine
    final scanEngine = ScanEngine(
      dataFetcher: widget.dataFetcher,
      modelInference: widget.modelInference,
    );

    // Run parallel scan
    final results = await scanEngine.scanParallel(
      stocks,
      onProgress: (completed, total) {
        setState(() {
          scanProgress = completed / total;
          statusText = 'Processing: $completed/$total stocks...';
        });
      },
    );

    // Update stocks with results
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      
      if (result.probabilities != null) {
        final signalResult = SignalFilter.evaluate(result.probabilities!);
        
        stocks[i] = stocks[i].copyWith(
          prob4h: result.probabilities!['4H'],
          prob2d: result.probabilities!['2D'],
          prob5d: result.probabilities!['5D'],
          signalType: signalResult.typeName,
          dataStatus: result.dataStatus,
          lastUpdated: result.timestamp,
          lastPrice: result.lastPrice,
        );
      } else {
        stocks[i] = stocks[i].copyWith(
          dataStatus: result.dataStatus,
          signalType: null,
        );
      }
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
      statusText = 'Turbo Scan complete! (${widget.dataFetcher.getFailedSymbols().length} failed)';
    });

    await _saveStocks();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Turbo Scan Complete'),
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

  Future<void> _clearResults() async {
    if (stocks.isEmpty) return;
    
    setState(() {
      for (var i = 0; i < stocks.length; i++) {
        stocks[i] = stocks[i].copyWith(
          prob4h: null,
          prob2d: null,
          prob5d: null,
          signalType: null,
          dataStatus: 'Not Scanned',
          lastUpdated: null,
          lastPrice: 0.0,
        );
      }
      statusText = 'Results cleared';
    });
    
    await _saveStocks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🧹 Scan results cleared')),
      );
    }
  }

  Future<void> _clearWatchlist() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        title: const Text('⚠️ Clear Watchlist?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will delete all symbols from your watchlist. You will need to import a CSV to add them back.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        stocks.clear();
        statusText = 'Watchlist empty';
      });
      await _saveStocks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Watchlist cleared')),
        );
      }
    }
  }
}
