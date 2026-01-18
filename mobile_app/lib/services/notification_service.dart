/// Notification Service for Stock Alerts
/// Protocol: Antigravity - Mobile Module
///
/// Handles local push notifications for high-confidence signals.
/// Uses flutter_local_notifications package.

import 'signal_filter.dart';

/// Notification configuration
class NotificationConfig {
  bool enableCombo;
  bool enableScalp;
  bool enableWatch;
  bool soundEnabled;
  bool vibrationEnabled;

  NotificationConfig({
    this.enableCombo = true,
    this.enableScalp = true,
    this.enableWatch = false,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });
}

/// Notification service for stock alerts
class NotificationService {
  static NotificationConfig config = NotificationConfig();
  static bool _initialized = false;

  /// Initialize the notification service
  static Future<void> initialize() async {
    if (_initialized) return;

    // In real Flutter app, this would initialize flutter_local_notifications
    // FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    //     FlutterLocalNotificationsPlugin();
    // await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    _initialized = true;
    print('📱 Notification service initialized');
  }

  /// Check if a signal type should trigger notification based on config
  static bool shouldNotify(SignalType type) {
    switch (type) {
      case SignalType.combo:
        return config.enableCombo;
      case SignalType.scalp:
        return config.enableScalp;
      case SignalType.watch:
        return config.enableWatch;
      case SignalType.avoid:
      case SignalType.none:
        return false;
    }
  }

  /// Send a stock signal notification
  static Future<void> sendSignalNotification({
    required String symbol,
    required SignalResult signal,
    required double prob4H,
    required double prob5D,
  }) async {
    if (!shouldNotify(signal.type)) {
      print('🔕 Notification filtered: ${signal.typeName} for $symbol');
      return;
    }

    final title = '${signal.emoji} ${signal.typeName}: $symbol';
    final body = _buildNotificationBody(symbol, signal, prob4H, prob5D);

    // In real Flutter app:
    // await flutterLocalNotificationsPlugin.show(
    //   id,
    //   title,
    //   body,
    //   notificationDetails,
    // );

    print('🔔 NOTIFICATION SENT:');
    print('   Title: $title');
    print('   Body: $body');
  }

  static String _buildNotificationBody(
    String symbol,
    SignalResult signal,
    double prob4H,
    double prob5D,
  ) {
    final p4H = (prob4H * 100).toStringAsFixed(0);
    final p5D = (prob5D * 100).toStringAsFixed(0);

    switch (signal.type) {
      case SignalType.combo:
        return 'High confidence! 4H: $p4H%, 5D: $p5D%. Strong alignment detected.';
      case SignalType.scalp:
        return 'Quick trade opportunity! 4H momentum: $p4H%. Take profits fast.';
      case SignalType.watch:
        return 'Monitor this stock. 5D trend: $p5D%. Wait for 4H momentum.';
      default:
        return signal.message;
    }
  }

  /// Update notification configuration
  static void updateConfig(NotificationConfig newConfig) {
    config = newConfig;
    print('⚙️ Notification config updated');
  }
}
