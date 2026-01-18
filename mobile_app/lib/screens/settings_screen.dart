/// Settings Screen - App Configuration
/// Protocol: Antigravity - Mobile Module

import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../services/signal_filter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _comboEnabled = true;
  bool _scalpEnabled = true;
  bool _watchEnabled = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  double _momentum4H = SignalFilter.MIN_MOMENTUM;
  double _trend5D = SignalFilter.MIN_TREND;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Signal Thresholds Section
          _buildSectionHeader('Signal Thresholds'),
          _buildThresholdSlider(
            label: '4H Momentum Threshold',
            value: _momentum4H,
            onChanged: (v) => setState(() => _momentum4H = v),
          ),
          _buildThresholdSlider(
            label: '5D Trend Threshold',
            value: _trend5D,
            onChanged: (v) => setState(() => _trend5D = v),
          ),
          const SizedBox(height: 24),

          // Notification Settings Section
          _buildSectionHeader('Notification Alerts'),
          _buildNotificationToggle(
            title: '🔥 COMBO Signals',
            subtitle: 'Strong alignment (4H + 5D)',
            value: _comboEnabled,
            onChanged: (v) => setState(() => _comboEnabled = v),
          ),
          _buildNotificationToggle(
            title: '⚡ SCALP Signals',
            subtitle: 'Short-term momentum only',
            value: _scalpEnabled,
            onChanged: (v) => setState(() => _scalpEnabled = v),
          ),
          _buildNotificationToggle(
            title: '📈 WATCH Signals',
            subtitle: 'Long-term trend only',
            value: _watchEnabled,
            onChanged: (v) => setState(() => _watchEnabled = v),
          ),
          const Divider(height: 32),
          _buildNotificationToggle(
            title: 'Sound',
            subtitle: 'Play notification sound',
            value: _soundEnabled,
            onChanged: (v) => setState(() => _soundEnabled = v),
          ),
          _buildNotificationToggle(
            title: 'Vibration',
            subtitle: 'Vibrate on notification',
            value: _vibrationEnabled,
            onChanged: (v) => setState(() => _vibrationEnabled = v),
          ),
          const SizedBox(height: 24),

          // Signal Reference Card
          _buildSectionHeader('Signal Reference'),
          _buildSignalReferenceCard(),
          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader('About'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stock Alert v1.0',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Multi-timeframe probability-based stock signal alerts using XGBoost models.',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Antigravity Protocol',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0EA5E9),
        ),
      ),
    );
  }

  Widget _buildThresholdSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label),
                Text(
                  '${(value * 100).toInt()}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0EA5E9),
                  ),
                ),
              ],
            ),
            Slider(
              value: value,
              min: 0.40,
              max: 0.90,
              divisions: 10,
              activeColor: const Color(0xFF0EA5E9),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500])),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF0EA5E9),
      ),
    );
  }

  Widget _buildSignalReferenceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildReferenceRow(
              '🔥 COMBO',
              '4H ≥ 70% AND 5D ≥ 60%',
              'High confidence entry',
            ),
            const Divider(),
            _buildReferenceRow('⚡ SCALP', '4H ≥ 70% only', 'Quick trade'),
            const Divider(),
            _buildReferenceRow('📈 WATCH', '5D ≥ 60% only', 'Monitor'),
            const Divider(),
            _buildReferenceRow('❄️ AVOID', 'All < 40%', 'No trade'),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceRow(String type, String condition, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              type,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(condition, style: const TextStyle(fontSize: 12)),
                Text(
                  action,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
