# Stock Alert Mobile App - Flutter Version

Converted from the Flet Python version to native Flutter/Dart.

## Project Structure

```
lib/
├── main.dart              # App entry point with navigation
├── models/
│   ├── stock_symbol.dart  # Stock data model
│   ├── alert_item.dart    # Alert data model
│   └── signal_result.dart # Signal evaluation result
├── services/
│   ├── config_manager.dart   # Configuration persistence
│   ├── signal_filter.dart    # Trading signal classification
│   ├── model_inference.dart  # XGBoost inference engine
│   └── data_fetcher.dart     # Data fetching (STUB)
└── screens/
    ├── watchlist_screen.dart # Main stock list with scan
    ├── alerts_screen.dart    # Signal history
    └── settings_screen.dart  # Configuration & diagnostics
```

## Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Create assets directory:
   ```bash
   mkdir -p assets/models
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Note on Data Fetcher

The `data_fetcher.dart` is a **STUB** implementation. The actual TradingView data fetching implementation will be provided separately.

## Features

- **Watchlist**: View and scan stocks for trading signals
- **Alerts**: History of generated signals
- **Settings**: Configure thresholds, manage models, run diagnostics

## Signal Types

| Signal | Condition | Color |
|--------|-----------|-------|
| COMBO  | 4H ≥ 70% AND 5D ≥ 60% | Red |
| SCALP  | 4H ≥ 70% only | Orange |
| WATCH  | 5D ≥ 60% only | Yellow |
| AVOID  | All < 40% | Blue |
| NEUTRAL | Default | Gray |
