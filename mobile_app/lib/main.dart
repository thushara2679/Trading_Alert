/// Stock Alert Mobile App - Main Entry Point
/// Protocol: Antigravity - Mobile Module
///
/// Flutter app for real-time stock signal alerts using trained XGBoost models.
/// Features:
/// - CSV watchlist import/export (same format as PC app)
/// - Multi-timeframe combo signal filter (4H + 5D)
/// - On-device XGBoost inference
/// - Local push notifications for high-confidence signals

import 'package:flutter/material.dart';
import 'screens/watchlist_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/settings_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  runApp(const StockAlertApp());
}

class StockAlertApp extends StatelessWidget {
  const StockAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stock Alert',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF0EA5E9), // Sky Blue
          secondary: const Color(0xFF6366F1), // Indigo
          surface: const Color(0xFF1E293B), // Slate
          background: const Color(0xFF0F172A), // Deep Navy
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: const Color(0xFFF8FAFC), // Slate White
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          foregroundColor: Color(0xFFF8FAFC),
          elevation: 0,
        ),
        fontFamily: 'Roboto',
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const WatchlistScreen(),
    const AlertsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt),
            selectedIcon: Icon(Icons.list_alt, color: Color(0xFF0EA5E9)),
            label: 'Watchlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications, color: Color(0xFF0EA5E9)),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: Color(0xFF0EA5E9)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
