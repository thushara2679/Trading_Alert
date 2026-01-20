/// Alerts Screen - Signal History
/// Converted from: screens/alerts.py
/// 
/// Shows history of generated alerts/signals with detailed card layout.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/alert_item.dart';
import '../services/signal_filter.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<AlertItem> alerts = [];

  String _formatAlert(AlertItem alert) {
    return '🔔 ALERT: ${alert.symbol}\n'
        'Signal: ${alert.signalType}\n'
        'Price: ${alert.lastPrice.toStringAsFixed(2)}\n'
        'Probs: 4H:${alert.prob4h.toInt()}% 2D:${alert.prob2d.toInt()}% 5D:${alert.prob5d.toInt()}%\n'
        'Time: ${alert.timestamp}';
  }

  Future<void> _copyAlertText(AlertItem alert) async {
    final text = _formatAlert(alert);
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📋 Copied alert to clipboard'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _shareAlert(AlertItem alert) async {
    final text = _formatAlert(alert);
    await Share.share(text, subject: 'Trading Alert: ${alert.symbol}');
  }

  Future<void> _shareAllAlerts() async {
    if (alerts.isEmpty) return;
    
    final buffer = StringBuffer();
    buffer.writeln('📊 TRADING ALERTS SUMMARY');
    buffer.writeln('Total Alerts: ${alerts.length}');
    buffer.writeln('Date: ${DateTime.now().toString().substring(0, 16)}');
    buffer.writeln('----------------------------\n');

    for (final alert in alerts) {
      buffer.writeln(_formatAlert(alert));
      buffer.writeln('----------------------------');
    }

    await Share.share(buffer.toString(), subject: 'Trading Alerts Summary');
  }

  Future<void> _exportAlertsToCsv() async {
    if (alerts.isEmpty) return;

    final buffer = StringBuffer();
    // CSV Header
    buffer.writeln('Symbol,Signal,Price,4H%,2D%,5D%,Timestamp');

    // CSV Rows
    for (final alert in alerts) {
      buffer.writeln('${alert.symbol},'
          '${alert.signalType},'
          '${alert.lastPrice.toStringAsFixed(2)},'
          '${alert.prob4h.toInt()},'
          '${alert.prob2d.toInt()},'
          '${alert.prob5d.toInt()},'
          '${alert.timestamp}');
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/alerts_export.csv');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Trading Alerts CSV Export',
        text: 'Attached is the trading alerts CSV export.',
      );
    } catch (e) {
      print('❌ Failed to export CSV: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Export failed: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAlerts();
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
                '🔔 Alerts',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${alerts.length} alerts',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white70),
                    tooltip: 'Menu',
                    onSelected: (value) {
                      if (value == 'share') _shareAllAlerts();
                      if (value == 'export_csv') _exportAlertsToCsv();
                      if (value == 'clear') _clearAlerts();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share, size: 20, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Share All'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export_csv',
                        child: Row(
                          children: [
                            Icon(Icons.file_download, size: 20, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Export to CSV'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          children: [
                            Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Clear All'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Alert List
        Expanded(
          child: alerts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: alerts.length,
                  itemBuilder: (context, index) => _buildAlertCard(alerts[index]),
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
          Icon(Icons.notifications_off, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          const Text(
            'No alerts yet',
            style: TextStyle(color: Colors.grey),
          ),
          Text(
            'Run a scan to generate alerts',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(AlertItem alert) {
    final signalColor = SignalFilter.getColor(alert.signalType);

    // Get signal emoji
    const emojiMap = {
      'COMBO': '🔥',
      'SCALP': '⚡',
      'WATCH': '📈',
      'AVOID': '❄️',
      'NEUTRAL': '➖',
    };
    final emoji = emojiMap[alert.signalType] ?? '➖';

    // Calculate time ago
    String timeStr;
    try {
      final dt = DateTime.parse(alert.timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) {
        timeStr = 'Just now';
      } else if (diff.inHours < 1) {
        timeStr = '${diff.inMinutes} min ago';
      } else if (diff.inDays < 1) {
        timeStr = '${diff.inHours} hrs ago';
      } else {
        timeStr = '${dt.month}/${dt.day}';
      }
    } catch (_) {
      timeStr = alert.timestamp.substring(0, 10);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: alert.signalType == 'COMBO'
            ? Border.all(color: signalColor, width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$emoji ${alert.symbol}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: signalColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  alert.signalType,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Probabilities Row
          Row(
            children: [
              Text(
                '4H: ${alert.prob4h.toInt()}%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[300],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '2D: ${alert.prob2d.toInt()}%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[300],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '5D: ${alert.prob5d.toInt()}%',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[300],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Footer Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (alert.lastPrice > 0)
                Text(
                  'Price: ${alert.lastPrice.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                )
              else
                const SizedBox(),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18, color: Colors.blue),
                    tooltip: 'Copy',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _copyAlertText(alert),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.share, size: 18, color: Colors.blue),
                    tooltip: 'Share',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _shareAlert(alert),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    timeStr,
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void addAlert(AlertItem alert) {
    setState(() {
      alerts.insert(0, alert);
    });
    _saveAlerts();
  }

  Future<void> _clearAlerts() async {
    setState(() {
      alerts.clear();
    });
    await _saveAlerts();
  }

  Future<void> _saveAlerts() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/alerts.json');
      final data = alerts.map((a) => a.toJson()).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      print('Failed to save alerts: $e');
    }
  }

  Future<void> _loadAlerts() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final file = File('${appDir.path}/alerts.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as List;
        alerts = data
            .map((d) => AlertItem.fromJson(d as Map<String, dynamic>))
            .toList();

        // Sort by priority
        alerts.sort((a, b) {
          final priorityA = SignalFilter.getSignalPriority(a.signalType);
          final priorityB = SignalFilter.getSignalPriority(b.signalType);
          return priorityB.compareTo(priorityA);
        });

        setState(() {});
      }
    } catch (e) {
      print('Failed to load alerts: $e');
    }
  }
}
