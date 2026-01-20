/// Configuration Manager Service
/// Converted from: services/config_manager.py
/// 
/// Handles persistent app configuration including signal thresholds.
/// Uses SharedPreferences for persistence (replaces Python's JSON file).

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigManager {
  static ConfigManager? _instance;
  static SharedPreferences? _prefs;

  // Default Configuration
  static const Map<String, double> defaultThresholds = {
    'COMBO_4H': 70.0,
    'COMBO_5D': 60.0,
    'SCALP_4H': 70.0,
    'WATCH_5D': 60.0,
    'AVOID': 40.0,
  };

  static const Map<String, dynamic> defaultData = {
    'n_bars': 50,
    'validity_minutes': 15,
  };

  static const Map<String, dynamic> defaultSchedule = {
    'enabled': false,
    'start_hour': 10,
    'start_minute': 35,
    'end_hour': 15, // 3:00 PM
    'end_minute': 35,
    'interval_minutes': 60,
  };

  Map<String, double> _thresholds = Map.from(defaultThresholds);
  Map<String, dynamic> _dataConfig = Map.from(defaultData);
  Map<String, dynamic> _scheduleConfig = Map.from(defaultSchedule);

  ConfigManager._internal();

  /// Get singleton instance (async initialization)
  static Future<ConfigManager> getInstance() async {
    if (_instance == null) {
      _instance = ConfigManager._internal();
      _prefs = await SharedPreferences.getInstance();
      await _instance!._loadConfig();
    }
    return _instance!;
  }

  /// Synchronous getter after initialization
  static ConfigManager get instance {
    if (_instance == null) {
      throw StateError('ConfigManager not initialized. Call getInstance() first.');
    }
    return _instance!;
  }

  /// Load config from SharedPreferences
  Future<void> _loadConfig() async {
    final thresholdsJson = _prefs?.getString('thresholds');
    if (thresholdsJson != null) {
      try {
        final saved = jsonDecode(thresholdsJson) as Map<String, dynamic>;
        _thresholds = saved.map((key, value) => 
          MapEntry(key, (value as num).toDouble()));
      } catch (e) {
        print('⚠️ Failed to load thresholds: $e');
      }
    }

    final dataJson = _prefs?.getString('data_config');
    if (dataJson != null) {
      try {
        _dataConfig = jsonDecode(dataJson) as Map<String, dynamic>;
      } catch (e) {
        print('⚠️ Failed to load data config: $e');
      }
    }

    final scheduleJson = _prefs?.getString('schedule_config');
    if (scheduleJson != null) {
      try {
        _scheduleConfig = jsonDecode(scheduleJson) as Map<String, dynamic>;
      } catch (e) {
        print('⚠️ Failed to load schedule config: $e');
      }
    }
  }

  /// Save current config to SharedPreferences
  Future<void> _saveConfig() async {
    await _prefs?.setString('thresholds', jsonEncode(_thresholds));
    await _prefs?.setString('data_config', jsonEncode(_dataConfig));
    await _prefs?.setString('schedule_config', jsonEncode(_scheduleConfig));
  }

  /// Get a specific config value
  dynamic get(String section, String key) {
    if (section == 'thresholds') {
      return _thresholds[key] ?? defaultThresholds[key];
    } else if (section == 'data') {
      return _dataConfig[key] ?? defaultData[key];
    } else if (section == 'schedule') {
      return _scheduleConfig[key] ?? defaultSchedule[key];
    }
    return null;
  }

  /// Set a config value and save
  Future<void> set(String section, String key, dynamic value) async {
    if (section == 'thresholds' && value is num) {
      _thresholds[key] = value.toDouble();
    } else if (section == 'data') {
      _dataConfig[key] = value;
    } else if (section == 'schedule') {
      _scheduleConfig[key] = value;
    }
    await _saveConfig();
  }

  /// Get all signal thresholds
  Map<String, double> getThresholds() {
    return Map.from(_thresholds);
  }

  /// Update multiple thresholds at once
  Future<void> updateThresholds(Map<String, double> newThresholds) async {
    _thresholds.addAll(newThresholds);
    await _saveConfig();
  }

  /// Reset to defaults
  Future<void> resetToDefaults() async {
    _thresholds = Map.from(defaultThresholds);
    _dataConfig = Map.from(defaultData);
    _scheduleConfig = Map.from(defaultSchedule); // Reset schedule too? Maybe optional
    await _saveConfig();
  }
}
