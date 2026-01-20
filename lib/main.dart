/// Stock Alert Mobile App - Main Entry Point
/// Converted from: main.py
/// 
/// This is the main entry point for the Flutter mobile application.
/// Uses dependency injection pattern matching the Python Flet version.

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'services/config_manager.dart';
import 'services/data_fetcher.dart';
import 'services/model_inference.dart';
import 'services/background_scheduler.dart';
import 'screens/watchlist_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize ConfigManager singleton
  await ConfigManager.getInstance();
  
  // Initialize BackgroundScheduler (WorkManager)
  await BackgroundScheduler.initialize();
  
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
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0EA5E9),    // Sky Blue
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Midnight Indigo
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0EA5E9),      // Sky Blue
          secondary: Color(0xFF6366F1),    // Indigo
          surface: Color(0xFF1E293B),
          error: Color(0xFFEF4444),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E293B),
          elevation: 2,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F172A),
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1E293B),
          indicatorColor: Color.fromRGBO(14, 165, 233, 0.2),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0EA5E9),
            foregroundColor: Colors.white,
          ),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFF0EA5E9),
          thumbColor: Color(0xFF0EA5E9),
          inactiveTrackColor: Color(0xFF1E293B),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3B82F6)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3B82F6)),
          ),
          labelStyle: const TextStyle(color: Colors.grey),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF1E293B),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Shared services (dependency injection pattern)
  late final DataFetcher _dataFetcher;
  late final ModelInference _modelInference;

  // Screens
  List<Widget> _screens = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Get app documents directory for writable storage
    final appDir = await getApplicationDocumentsDirectory();
    final modelsPath = '${appDir.path}/models';
    
    // Initialize shared services
    _dataFetcher = DataFetcher();
    _modelInference = ModelInference(modelsDir: modelsPath);
    
    // Initialize data fetcher
    await _dataFetcher.initialize();

    // Initialize screens with shared services
    setState(() {
      _screens = [
        WatchlistScreen(
          dataFetcher: _dataFetcher,
          modelInference: _modelInference,
        ),
        const AlertsScreen(),
        SettingsScreen(
          dataFetcher: _dataFetcher,
          modelInference: _modelInference,
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading until services are initialized
    if (_screens.isEmpty) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Watchlist',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
