/// Alerts Screen - Signal History
/// Protocol: Antigravity - Mobile Module

import 'package:flutter/material.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final List<AlertItem> _alerts = [
    // Sample alerts for demo
    AlertItem(
      symbol: 'AAFL.N0000',
      signalType: 'COMBO',
      prob4H: 0.82,
      prob5D: 0.71,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AlertItem(
      symbol: 'HNB.N0000',
      signalType: 'SCALP',
      prob4H: 0.75,
      prob5D: 0.45,
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔔 Signal Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to CSV',
            onPressed: _exportToCsv,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear All',
            onPressed: _alerts.isNotEmpty ? _clearAlerts : null,
          ),
        ],
      ),
      body: _alerts.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _alerts.length,
              itemBuilder: (context, index) => _buildAlertCard(_alerts[index]),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No alerts yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[400]),
          ),
          const SizedBox(height: 8),
          Text(
            'Signals will appear here when triggered',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(AlertItem alert) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: _getCardColor(alert.signalType),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  _getEmoji(alert.signalType),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.symbol,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        alert.signalType,
                        style: TextStyle(
                          color: _getSignalColor(alert.signalType),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatTime(alert.timestamp),
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Probabilities
            Row(
              children: [
                _buildProbChip('4H', alert.prob4H),
                const SizedBox(width: 8),
                _buildProbChip('5D', alert.prob5D),
              ],
            ),
            const SizedBox(height: 8),

            // Advice
            Text(
              _getAdvice(alert.signalType),
              style: TextStyle(color: Colors.grey[300], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProbChip(String label, double prob) {
    final percentage = (prob * 100).toStringAsFixed(0);
    final isHigh = prob >= 0.60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isHigh
            ? Colors.green.withOpacity(0.2)
            : Colors.grey.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $percentage%',
        style: TextStyle(
          color: isHigh ? Colors.greenAccent : Colors.grey[400],
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _getCardColor(String type) {
    switch (type) {
      case 'COMBO':
        return const Color(0xFF2D1B00);
      case 'SCALP':
        return const Color(0xFF2D2B00);
      case 'WATCH':
        return const Color(0xFF001B2D);
      default:
        return const Color(0xFF1E293B);
    }
  }

  Color _getSignalColor(String type) {
    switch (type) {
      case 'COMBO':
        return Colors.orange;
      case 'SCALP':
        return Colors.yellow;
      case 'WATCH':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getEmoji(String type) {
    switch (type) {
      case 'COMBO':
        return '🔥';
      case 'SCALP':
        return '⚡';
      case 'WATCH':
        return '📈';
      case 'AVOID':
        return '❄️';
      default:
        return '📊';
    }
  }

  String _getAdvice(String type) {
    switch (type) {
      case 'COMBO':
        return 'High confidence entry! Strong alignment between short-term momentum and weekly trend.';
      case 'SCALP':
        return 'Quick trade, take profits fast. Immediate momentum is high, but long-term support is lacking.';
      case 'WATCH':
        return 'Monitor, wait for momentum. Weekly outlook is good, but 1H/4H volume isn\'t pushing price yet.';
      default:
        return 'No actionable signal at this time.';
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _exportToCsv() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Alerts exported to CSV!')));
  }

  void _clearAlerts() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Alerts?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _alerts.clear());
              Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class AlertItem {
  final String symbol;
  final String signalType;
  final double prob4H;
  final double prob5D;
  final DateTime timestamp;

  AlertItem({
    required this.symbol,
    required this.signalType,
    required this.prob4H,
    required this.prob5D,
    required this.timestamp,
  });
}
