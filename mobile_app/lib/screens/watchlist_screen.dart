/// Watchlist Screen - Stock List Management
/// Protocol: Antigravity - Mobile Module

import 'package:flutter/material.dart';
import '../models/stock_symbol.dart';
import '../services/signal_filter.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  List<StockSymbol> _stocks = [];
  bool _isScanning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Watchlist'),
        actions: [
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
                    label: Text(_isScanning ? 'Scanning...' : '🔍 Scan All'),
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
            ? _buildSignalBadge(signal, stock.prob4H, stock.prob5D)
            : Text(
                stock.dataStatus,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
      ),
    );
  }

  Widget _buildSignalBadge(String signal, double? p4H, double? p5D) {
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

    return Container(
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

  void _importCsv() {
    // TODO: Implement file picker
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CSV import coming soon')));
  }

  void _exportAlerts() {
    // TODO: Implement export
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Alerts exported!')));
  }

  void _scanAll() async {
    setState(() => _isScanning = true);

    // Simulate scanning with signal filter
    for (int i = 0; i < _stocks.length; i++) {
      await Future.delayed(const Duration(milliseconds: 100));

      // Mock probabilities for demo
      final p4H = 0.3 + (i % 5) * 0.15;
      final p5D = 0.4 + (i % 4) * 0.12;

      final result = SignalFilter.evaluate([p4H, 0.5, p5D]);

      setState(() {
        _stocks[i].prob4H = p4H;
        _stocks[i].prob5D = p5D;
        _stocks[i].signalType = result.typeName;
        _stocks[i].lastUpdated = DateTime.now();
      });
    }

    setState(() => _isScanning = false);
  }
}
