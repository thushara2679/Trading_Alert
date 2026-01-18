# Trading Alert Mobile App (Flet Python)

## ✅ **Standalone Data Fetching with tvdatafeed**

This mobile app fetches live TradingView data directly using `tvdatafeed` - **NO server, NO PC dependencies**.

---

## 📦 **Installation**

```powershell
cd d:\TEST\Trading_Alerts\mobile_app\flet_app
pip install -r requirements.txt
```

---

## 🚀 **Running the App**

### Desktop (Recommended)
```powershell
python main.py
```

Or double-click **`run.bat`**.

### ⚠️ **DO NOT USE `flet run`**
The `flet-cli` has version conflicts. Always use `python main.py`.

---

## 📱 **Building for Android**

**Note:** APK building requires the `flet build` command, which has dependencies issues in your environment. For now, focus on desktop testing.

If you need an APK, we can create a fresh Python virtual environment to isolate the `flet` installation.

---

## 🎯 **Features**

| Feature | Status |
|---------|--------|
| Direct TradingView data fetch | ✅ tvdatafeed embedded |
| XGBoost model inference | ✅ JSON parser |
| Watchlist persistence | ✅ |
| Alert history | ✅ |
| CSV import | ✅ |

---

## 📂 **Project Structure**

```
flet_app/
├── main.py              # Entry point
├── run.bat              # Quick launch
├── requirements.txt     # Dependencies
├── services/
│   ├── data_fetcher.py  # tvdatafeed ← DIRECT FETCH
│   ├── model_inference.py
│   └── signal_filter.py
├── screens/
│   ├── watchlist.py
│   ├── alerts.py
│   └── settings.py
└── Test_py/
    └── test_data_fetcher.py
```

---

## 🔧 **Troubleshooting**

**Q: The app won't start**  
A: Make sure you're using `python main.py`, NOT `flet run`.

**Q: "ImportError: cannot import name 'cleanup_path'"**  
A: This is a `flet-cli` bug. Ignore it and use `python main.py`.

**Q: "you are using nologin method"**  
A: This is normal. `tvdatafeed` is running in anonymous mode (limited but functional).

---

## 📝 **Next Steps**

1. Run `python main.py`
2. Import your watchlist CSV
3. Click "Scan All" to fetch live data
4. Check the Alerts tab for signals
