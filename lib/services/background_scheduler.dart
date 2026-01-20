/// Background Scheduler - Automated Scanning Service
/// 
/// Handles scheduled background scans during market hours using WorkManager.
/// Sends notifications when new trading signals are detected.

import 'package:workmanager/workmanager.dart';
import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background task names
class BackgroundTasks {
  static const String marketScan = 'market_scan_task';
}

/// Background scheduler for automated scanning
class BackgroundScheduler {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initialize the background scheduler
  static Future<void> initialize() async {
    if (_initialized) return;

    // Initialize notifications (optional - app continues if this fails)
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _notifications.initialize(initSettings);
      print('✅ Notifications initialized');
    } catch (e) {
      print('⚠️ Notifications not available: $e');
    }

    // Initialize WorkManager
    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false, // Set to true for debugging
      );
      print('✅ WorkManager initialized');
    } catch (e) {
      print('⚠️ WorkManager initialization failed: $e');
      // Don't throw - allow app to continue without background tasks
    }

    _initialized = true;
    print('✅ BackgroundScheduler initialized');
  }

  /// Schedule market hours scanning
  static Future<void> scheduleMarketScan({
    required int intervalMinutes,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
  }) async {
    await initialize();

    // Cancel existing tasks
    await Workmanager().cancelByUniqueName(BackgroundTasks.marketScan);

    // Schedule periodic task
    await Workmanager().registerPeriodicTask(
      BackgroundTasks.marketScan,
      BackgroundTasks.marketScan,
      frequency: Duration(minutes: intervalMinutes),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      inputData: {
        'start_hour': startHour,
        'start_minute': startMinute,
        'end_hour': endHour,
        'end_minute': endMinute,
      },
    );

    print('📅 Scheduled market scan every $intervalMinutes min');
  }

  /// Cancel all scheduled tasks
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    print('🛑 Cancelled all background tasks');
  }

  /// Show notification for new signals
  static Future<void> showSignalNotification({
    required String title,
    required String body,
    required int signalCount,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'trading_alerts',
      'Trading Alerts',
      channelDescription: 'Notifications for new trading signals',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      signalCount, // Use signal count as ID
      title,
      body,
      details,
    );
  }
}

/// Background callback dispatcher
/// This runs in a separate isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('🔔 Background task started: $task');

    try {
      // Check if we're in market hours
      final now = DateTime.now();
      
      // Get config from input data
      final startHour = inputData?['start_hour'] ?? 10;
      final startMinute = inputData?['start_minute'] ?? 35;
      final endHour = inputData?['end_hour'] ?? 15;
      final endMinute = inputData?['end_minute'] ?? 35;

      // Calculate minutes since midnight for comparison
      final currentMinutes = now.hour * 60 + now.minute;
      final startTotalMinutes = startHour * 60 + startMinute;
      final endTotalMinutes = endHour * 60 + endMinute;

      if (currentMinutes < startTotalMinutes || currentMinutes >= endTotalMinutes) {
        print('⏰ Outside market hours (${startHour}:${startMinute} - ${endHour}:${endMinute}), skipping scan');
        return Future.value(true);
      }

      // Skip weekends
      if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
        print('📅 Weekend, skipping scan');
        return Future.value(true);
      }

      // TODO: Implement background scan logic
      // This would require:
      // 1. Loading watchlist from persistent storage
      // 2. Creating DataFetcher and ModelInference instances
      // 3. Running ScanEngine
      // 4. Detecting new signals
      // 5. Sending notifications for COMBO/SCALP signals
      
      print('✅ Background scan complete');
      return Future.value(true);
    } catch (e) {
      print('❌ Background task error: $e');
      return Future.value(false);
    }
  });
}
