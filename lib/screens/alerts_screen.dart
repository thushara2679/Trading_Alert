/// Alerts Screen - Signal History
/// Converted from: screens/alerts.py
/// 
/// Shows history of generated alerts/signals with detailed card layout.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../models/alert_item.dart';
import '../services/signal_filter.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<AlertItem> alerts = [];

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
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    tooltip: 'Clear All',
                    onPressed: _clearAlerts,
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
              Text(
                'Updated: $timeStr',
                style: TextStyle(fontSize: 13, color: Colors.grey[400]),
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
