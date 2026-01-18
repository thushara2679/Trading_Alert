/// Watchlist Screen - Stock List Management
/// Protocol: Antigravity - Mobile Module

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'dart:async';
import '../models/stock_symbol.dart';
import '../services/signal_filter.dart';
import '../services/model_inference.dart';
import '../services/data_fetcher.dart';
import '../models/alert_item.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<StockSymbol> _stocks = [];
  bool _isScanning = false;
  String _statusMessage = '';
  Timer? _scheduler;
  late DataFetcher _dataFetcher;
  final _inference = ModelInference('assets/models');
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _initServices();
    _loadStocks();
    _startScheduler();
  }
  
  void _initServices() async {
     final docDir = await getApplicationDocumentsDirectory();
     _dataFetcher = DataFetcher(docDir.path);
  }

  void _startScheduler() {
    // Check every minute
    _scheduler = Timer.periodic(const Duration(minutes: 1), (timer) {
      final now = DateTime.now();
      // Weekdays only
      if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) return;
      
      // Time window: 10:35 - 15:35
      // exact minutes check (allow 0-1 min offset)
      if (now.minute == 35 && now.hour >= 10 && now.hour <= 15) {
         if (!_isScanning) {
           print('⏰ Auto-Refresh: ${now.toLocal()}');
           _scanAll();
         }
      }
    });
  }

  @override
  void dispose() {
    _scheduler?.cancel();
    super.dispose();
  }

  Future<void> _saveStocks() async {
    if (kIsWeb) return; // No persistence on web demo
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/stocks.json');
      final jsonList = _stocks.map((s) => s.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print('Failed to save stocks: $e');
    }
  }

  Future<void> _loadStocks() async {
    if (kIsWeb) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/stocks.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        setState(() {
          _stocks = jsonList.map((j) => StockSymbol.fromJson(j)).toList();
        });
      }
    } catch (e) {
      print('Failed to load stocks: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Watchlist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology),
            tooltip: 'Import Model',
            onPressed: _importModel,
          ),
          IconButton(
            icon: const Icon(Icons.data_object),
            tooltip: 'Import Data JSON',
            onPressed: _importDataJson,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Import CSV',
            onPressed: _importCsv,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Alerts',
            onPressed: _stocks.any((s) => s.hasSignal) ? _exportAlerts : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Control Panel
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _scanAll,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.radar),
                    label: Text(_isScanning ? _statusMessage : '🔍 Scan All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_stocks.length} stocks',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ],
            ),
          ),

          // Stock List
          Expanded(
            child: _stocks.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _stocks.length,
                    itemBuilder: (context, index) =>
                        _buildStockTile(_stocks[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No stocks in watchlist',
            style: TextStyle(fontSize: 18, color: Colors.grey[400]),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _importCsv,
            icon: const Icon(Icons.upload_file),
            label: const Text('Import CSV'),
          ),
        ],
      ),
    );
  }

  Widget _buildStockTile(StockSymbol stock) {
    final signal = stock.signalType;
    final hasSignal = stock.hasSignal;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: hasSignal ? const Color(0xFF1E3A5F) : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getSignalColor(signal),
          child: Text(
            stock.symbol.substring(0, 2).toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        title: Text(
          stock.symbol,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          stock.exchange,
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
        trailing: signal != null
            ? _buildSignalBadge(signal, stock.prob4H, stock.prob2D, stock.prob5D)
            : Text(
                stock.dataStatus,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
      ),
    );
  }

  Widget _buildSignalBadge(String signal, double? p4H, double? p2D, double? p5D) {
    String emoji = '';
    Color color = Colors.grey;

    switch (signal) {
      case 'COMBO':
        emoji = '🔥';
        color = Colors.orange;
        break;
      case 'SCALP':
        emoji = '⚡';
        color = Colors.yellow;
        break;
      case 'WATCH':
        emoji = '📈';
        color = Colors.blue;
        break;
      case 'AVOID':
        emoji = '❄️';
        color = Colors.cyan;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                signal,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '4H:${(p4H ?? 0).toStringAsFixed(2)}  2D:${(p2D ?? 0).toStringAsFixed(2)}  5D:${(p5D ?? 0).toStringAsFixed(2)}',
          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
        ),
      ],
    );
  }

  Color _getSignalColor(String? signal) {
    switch (signal) {
      case 'COMBO':
        return Colors.orange;
      case 'SCALP':
        return Colors.yellow;
      case 'WATCH':
        return Colors.blue;
      case 'AVOID':
        return Colors.cyan;
      default:
        return const Color(0xFF334155);
    }
  }

  void _importCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true, // Required for Web to get bytes
      );

      if (result == null || result.files.isEmpty) {
        return; // User canceled
      }

      String content;

      if (kIsWeb) {
        // On Web, path is null. We must use bytes.
        final bytes = result.files.single.bytes;
        if (bytes != null) {
          content = utf8.decode(bytes);
        } else {
          throw Exception("No data received (Web)");
        }
      } else {
        // On Mobile/Desktop, use path.
        final path = result.files.single.path;
        if (path != null) {
          final file = File(path);
          content = await file.readAsString();
        } else {
          // Fallback if path is missing but bytes exist
          final bytes = result.files.single.bytes;
          if (bytes != null) {
            content = utf8.decode(bytes);
          } else {
             throw Exception("File path unavailable");
          }
        }
      }
      
      final lines = content.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

      if (lines.isEmpty) throw Exception("CSV file is empty");

      final newStocks = <StockSymbol>[];
      final firstLine = lines[0];
      final firstLineParts = firstLine.split(',');

      if (firstLineParts.length == 1) {
        // Single-column format: First row is the Exchange Name
        final exchange = firstLine;
        for (int i = 1; i < lines.length; i++) {
          final symbol = lines[i].trim();
          if (symbol.isNotEmpty && symbol.toLowerCase() != 'symbol') {
            newStocks.add(StockSymbol.fromCsvRow(symbol, exchange));
          }
        }
      } else {
        // Multi-column format: Exchange,Symbol[,...]
        // Check if first line is a header
        int startIdx = 0;
        final h0 = firstLineParts[0].toLowerCase();
        final h1 = firstLineParts[1].toLowerCase();
        if (h0 == 'exchange' || h1 == 'symbol' || h1 == 'ticker') {
          startIdx = 1;
        }

        for (int i = startIdx; i < lines.length; i++) {
          final parts = lines[i].split(',');
          if (parts.length >= 2) {
            final exchange = parts[0].trim();
            final symbol = parts[1].trim();
            if (symbol.isNotEmpty) {
              newStocks.add(StockSymbol.fromCsvRow(symbol, exchange));
            }
          }
        }
      }

      setState(() {
        _stocks = newStocks;
      });
      
      _saveStocks(); // Persist changes

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Imported ${newStocks.length} stocks')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Import failed: $e')),
      );
    }
  }

  void _importModel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;
      
      final file = result.files.single;
      final fileName = file.name;
      
      // Expected format: SYMBOL_HORIZON.json (e.g. CCS_4H.json)
      final docDir = await getApplicationDocumentsDirectory();
      final destination = File('${docDir.path}/$fileName');
      
      if (kIsWeb) return;
      
      if (file.path != null) {
        await File(file.path!).copy(destination.path);
      } else if (file.bytes != null) {
        await destination.writeAsBytes(file.bytes!);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Imported model: $fileName')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Model import failed: $e')),
      );
    }
  }

  void _importDataJson() async {
     try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return;
      
      final file = result.files.single;
      // Extract symbol from name (e.g. CCS.json or CCS.N0000.json -> CCS.N0000)
      final symbol = file.name.replaceAll('.json', '');
      
      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        throw "No data";
      }
      
      await _dataFetcher.importDataJson(symbol, content);
      
      setState(() {
         _statusMessage = 'Imported data for $symbol';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Imported data for $symbol')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Data import failed: $e')),
      );
    }
  }

  void _exportAlerts() {
    // TODO: Implement export
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Alerts exported!')));
  }


  void _scanAll() async {
    setState(() {
      _isScanning = true;
      _statusMessage = 'Initializing...';
    });
    
    final newAlerts = <AlertItem>[];

    for (int i = 0; i < _stocks.length; i++) {
     final stock = _stocks[i];
     
     setState(() => _statusMessage = 'Scanning ${stock.symbol}...');
     
      // Try to load real models first
      bool modelsLoaded = await _inference.loadModels(stock.symbol);
      
      double p4H = 0, p5D = 0, p2D = 0;
      bool usingLiveData = false;
      bool hasValidData = false;
      String dataStatus = 'No Data Available';

      if (modelsLoaded) {
        // Step 1: Fetch
        setState(() => _statusMessage = 'Fetching ${stock.symbol}...');
        List<double>? features;
        try {
           final dataMap = await _dataFetcher.fetchLatestData(stock.symbol, stock.exchange);
           if (dataMap != null && dataMap['features'] != null) {
              features = (dataMap['features'] as List).cast<double>();
              usingLiveData = true;
           }
        } catch (e) {
           print('Fetch failed for ${stock.symbol}: $e');
        }
        
        // Step 2: Inference - ONLY if we have valid features
        if (features != null && features.isNotEmpty) {
          setState(() => _statusMessage = 'Inference ${stock.symbol}...');
          final probs = _inference.predict(stock.symbol, features);
          p4H = probs[0];
          p2D = probs[1];
          p5D = probs[2];
          hasValidData = true;
          dataStatus = usingLiveData ? 'Live Data' : 'Cached Data';
        } else {
          // NO FAKE DATA - Honest status
          dataStatus = 'No Data Available';
          print('⚠️ No features available for ${stock.symbol} - showing honest status');
        }
      } else {
        // Model not loaded - be honest about it
        dataStatus = 'Model Not Found';
        print('⚠️ Model not loaded for ${stock.symbol}');
      }

      // Only evaluate signal if we have valid data
      final result = hasValidData 
          ? SignalFilter.evaluate([p4H, p2D, p5D])
          : SignalFilter.evaluate([0, 0, 0]); // Neutral - no signal

      setState(() {
        _stocks[i].prob4H = hasValidData ? p4H : null;
        _stocks[i].prob2D = hasValidData ? p2D : null; 
        _stocks[i].prob5D = hasValidData ? p5D : null;
        _stocks[i].signalType = hasValidData ? result.typeName : null;
        _stocks[i].lastUpdated = DateTime.now();
        _stocks[i].dataStatus = dataStatus;
      });

      if (_stocks[i].hasSignal) {
         newAlerts.add(AlertItem(
           symbol: _stocks[i].symbol,
           signalType: _stocks[i].signalType!,
           prob4H: _stocks[i].prob4H ?? 0,
           prob2D: _stocks[i].prob2D ?? 0,
           prob5D: _stocks[i].prob5D ?? 0,
           timestamp: DateTime.now(),
         ));
      }
    }
    
    if (newAlerts.isNotEmpty && !kIsWeb) {
       _saveAlerts(newAlerts);
    }

    setState(() {
       _isScanning = false;
       _statusMessage = '';
    });
  }

  Future<void> _saveAlerts(List<AlertItem> newItems) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/alerts.json');
      
      List<AlertItem> currentAlerts = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(content);
        currentAlerts = jsonList.map((j) => AlertItem.fromJson(j)).toList();
      }
      
      // Prepend new alerts
      currentAlerts.insertAll(0, newItems);
      
      // Save back
      final jsonList = currentAlerts.map((a) => a.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🔔 Generated ${newItems.length} new alerts')),
      );
    } catch (e) {
      print('Error saving alerts: $e');
    }
  }
}
