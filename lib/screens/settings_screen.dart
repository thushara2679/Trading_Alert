/// Settings Screen - Configuration
/// Converted from: screens/settings.py
/// 
/// App settings, Model Manager, and signal threshold configuration.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../services/config_manager.dart';
import '../services/data_fetcher.dart';
import '../services/model_inference.dart';

class SettingsScreen extends StatefulWidget {
  final DataFetcher dataFetcher;
  final ModelInference modelInference;

  const SettingsScreen({
    super.key,
    required this.dataFetcher,
    required this.modelInference,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<String> availableSymbols = [];
  
  // Diagnostics
  final TextEditingController _testSymbolController = TextEditingController();
  String _testOutput = 'No test run yet';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshModelList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _testSymbolController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.centerLeft,
          child: const Text(
            '⚙️ Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),

        // Tabs
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.settings), text: 'General'),
            Tab(icon: Icon(Icons.bug_report), text: 'Diagnostics'),
          ],
          indicatorColor: const Color(0xFF0EA5E9),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildGeneralTab(),
              _buildDiagnosticsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Model Manager
        _buildSection('📦 Model Manager', [
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Import Models'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F),
                ),
                onPressed: _importModels,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                onPressed: _refreshModelList,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...availableSymbols.isEmpty
              ? [
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.folder_off, size: 32, color: Colors.grey[600]),
                        const SizedBox(height: 4),
                        Text('No models found', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ]
              : availableSymbols.map((symbol) => _buildModelTile(symbol)).toList(),
        ]),

        const SizedBox(height: 20),

        // Signal Thresholds
        _buildThresholdsSection(),

        const SizedBox(height: 20),

        // Data Settings
        _buildSection('📡 Data Settings', [
          _buildSettingTile('Default Exchange', 'For new watchlist items', 'CSELK'),
          _buildSettingTile('Data Validity', 'Skip re-fetch if data is newer than', '15 min'),
          _buildSettingTile('Bars to Fetch', 'Historical bars per symbol', '50'),
        ]),

        const SizedBox(height: 20),

        // About
        _buildSection('ℹ️ About', [
          _buildSettingTile('Version', 'Stock Alert Mobile App (Flutter)', '1.0.0'),
        ]),
      ],
    );
  }

  Widget _buildDiagnosticsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Data Status
        _buildSection('📡 Data Status (Last 5)', [
          if (widget.dataFetcher.fetchTimestamps.isEmpty)
            Text('No data fetched yet', style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic))
          else
            ...widget.dataFetcher.fetchTimestamps.entries
                .toList()
                .reversed
                .take(5)
                .map((entry) {
              final failed = widget.dataFetcher.failedSymbols.contains(entry.key);
              final statusIcon = failed ? '❌' : '✅';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$statusIcon ${entry.key}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      '${entry.value.hour}:${entry.value.minute.toString().padLeft(2, '0')}:${entry.value.second.toString().padLeft(2, '0')}',
                      style: TextStyle(color: Colors.grey[400], fontFamily: 'monospace'),
                    ),
                  ],
                ),
              );
            }).toList(),
        ]),

        const SizedBox(height: 20),

        // Model Tester
        _buildSection('🧪 Model Tester', [
          Text(
            'Verify inference with dummy features',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _testSymbolController,
                  decoration: InputDecoration(
                    labelText: 'Symbol',
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue[400]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _runModelTest,
                child: const Text('Test Model'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Text(
              _testOutput,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.white70,
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildThresholdsSection() {
    final thresholds = ConfigManager.instance.getThresholds();
    return _buildSection('🎯 Signal Thresholds', [
      _buildSlider('COMBO 4H', 'Min 4H Prob', 'COMBO_4H', thresholds),
      _buildSlider('COMBO 5D', 'Min 5D Prob', 'COMBO_5D', thresholds),
      _buildSlider('SCALP 4H', 'Min Scalp Prob', 'SCALP_4H', thresholds),
      _buildSlider('WATCH 5D', 'Min Watch Prob', 'WATCH_5D', thresholds),
      _buildSlider('AVOID', 'Max Risk Prob', 'AVOID', thresholds),
    ]);
  }

  Widget _buildSlider(String label, String sub, String key, Map<String, double> thresholds) {
    final val = thresholds[key] ?? 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                  Text(sub, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
              Text(
                '${val.toInt()}%',
                style: TextStyle(color: Colors.blue[400], fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Slider(
            min: 0,
            max: 100,
            divisions: 100,
            value: val,
            onChanged: (value) {
              ConfigManager.instance.set('thresholds', key, value);
              setState(() {});
            },
            activeColor: const Color(0xFF0EA5E9),
          ),
        ],
      ),
    );
  }

  Future<void> _runModelTest() async {
    final symbol = _testSymbolController.text.trim();
    if (symbol.isEmpty) return;

    setState(() {
      _testOutput = 'Running inference...';
    });

    final result = await widget.modelInference.testInference(symbol);

    setState(() {
      _testOutput = const JsonEncoder.withIndent('  ').convert(result);
    });

    _refreshModelList();
  }

  Future<void> _refreshModelList() async {
    availableSymbols = await widget.modelInference.listAvailableSymbols();
    setState(() {});
  }

  Widget _buildModelTile(String symbol) {
    return FutureBuilder<Map<String, String>>(
      future: widget.modelInference.getModelStatus(symbol),
      builder: (context, snapshot) {
        final status = snapshot.data ?? {};
        final loadedCount = status.values.where((s) => s == 'loaded').length;
        final availableCount = status.values.where((s) => s == 'loaded' || s == 'available').length;

        Widget icon;
        String statusText;

        if (loadedCount == 3) {
          icon = const Icon(Icons.check_circle, color: Colors.green);
          statusText = '3/3 models active';
        } else if (availableCount > 0) {
          icon = const Icon(Icons.warning, color: Colors.orange);
          statusText = '$loadedCount/3 active (on disk)';
        } else {
          icon = const Icon(Icons.error, color: Colors.red);
          statusText = 'Missing data';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      symbol,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                    ),
                    Text(
                      statusText,
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                tooltip: 'Delete Package',
                onPressed: () => _deleteModel(symbol),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importModels() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result == null) return;

      var count = 0;
      final srcDir = Directory(result);

      await for (final entity in srcDir.list()) {
        if (entity is Directory) {
          final name = entity.path.split(Platform.pathSeparator).last;
          if (name.endsWith('_pkg') || name.endsWith('_mobile_pkg')) {
            // Standardize naming
            var safeName = name.replaceAll('.', '_');
            if (safeName.endsWith('_mobile_pkg')) {
              safeName = safeName.replaceAll('_mobile_pkg', '_pkg');
            }

            final destPath = Directory('${widget.modelInference.modelsDir}/$safeName');
            if (await destPath.exists()) {
              await destPath.delete(recursive: true);
            }

            await _copyDirectory(entity, destPath);
            count++;
          }
        }
      }

      await _refreshModelList();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Imported $count packages')),
        );
      }
    } catch (e) {
      print('Import error: $e');
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list()) {
      final newPath = '${destination.path}/${entity.path.split(Platform.pathSeparator).last}';
      if (entity is File) {
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      }
    }
  }

  Future<void> _deleteModel(String symbol) async {
    final success = await widget.modelInference.deleteModelPackage(symbol);
    await _refreshModelList();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '🗑️ Deleted $symbol' : '❌ Failed to delete $symbol'),
        ),
      );
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingTile(String title, String subtitle, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, color: Colors.white)),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
          Text(value, style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}
