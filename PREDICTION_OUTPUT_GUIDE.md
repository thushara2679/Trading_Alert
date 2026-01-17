# Prediction Output Explanation

## What Does the Application Predict?

The XGBoost Stock Trainer predicts the **probability of a 1% price increase in the next 4 hours** (next 4 one-hour candles).

---

## Output Components

### 1. **Price Hike Probability**
- **Range**: 0% to 100%
- **Meaning**: The likelihood that the stock price will increase by at least 1% within the next 4 hours
- **Example**: "72.5% Price Hike Probability" means there's a 72.5% chance of a ≥1% price increase

### 2. **Signal Classification**

| Probability | Signal | Color | Meaning |
|-------------|--------|-------|---------|
| ≥ 70% | BULLISH 📈 | Green | High confidence - Strong buy signal |
| 50-70% | NEUTRAL ➡️ | Orange | Moderate confidence - Wait and watch |
| < 50% | BEARISH 📉 | Red | Low confidence - Potential downside risk |

### 3. **Predicted Label**
- **HIKE**: Model predicts price will increase ≥1%
- **NO HIKE**: Model predicts price will NOT increase ≥1%

---

## How is the Prediction Made?

The model uses **4 key features** from multi-timeframe analysis:

### Features Used

1. **Vol_Z_1H** - Volume Z-Score on 1-hour timeframe
   - Measures how unusual current volume is compared to recent 20-period average
   - High Z-score = Abnormally high volume (potential breakout)

2. **Vol_Z_4H** - Volume Z-Score on 4-hour timeframe
   - Captures medium-term volume trends
   - Helps identify sustained momentum

3. **Vol_Z_1D** - Volume Z-Score on daily timeframe
   - Captures long-term volume context
   - Identifies major institutional activity

4. **Elasticity_1H** - Price Elasticity on 1-hour timeframe
   - Formula: `Price_Pct_Change / Vol_Z`
   - Measures how efficiently price moves relative to volume
   - High elasticity = Price moves significantly with less volume (strong trend)

---

## Example Interpretation

### Example 1: Strong Bullish Signal
```
78.3% Price Hike Probability
Signal: BULLISH 📈 | Predicted: HIKE | Symbol: AAPL

📊 High probability of 1% price increase in next 4 hours (4 candles)
Prediction based on Volume Z-Score and Price Elasticity across 1H, 4H, and 1D timeframes.
```

**Interpretation**: 
- 78.3% chance of ≥1% price increase in next 4 hours
- Strong buy signal
- Model detected favorable volume and price elasticity patterns across all timeframes

### Example 2: Bearish Signal
```
32.1% Price Hike Probability
Signal: BEARISH 📉 | Predicted: NO HIKE | Symbol: TSLA

📊 Low probability of price increase - potential downside risk
Prediction based on Volume Z-Score and Price Elasticity across 1H, 4H, and 1D timeframes.
```

**Interpretation**:
- Only 32.1% chance of ≥1% price increase
- 67.9% chance of either flat or declining price
- Avoid buying, consider selling or staying out

---

## Technical Details

### Model Type
- **Algorithm**: XGBoost Binary Classifier
- **Training Target**: Binary (1 = price increases ≥1% in next 4 candles, 0 = otherwise)
- **Hyperparameters**:
  - n_estimators: 100
  - max_depth: 3
  - learning_rate: 0.1

### Data Processing
1. **Feature Engineering**:
   - Volume Z-Score calculated using 20-period rolling window
   - Elasticity = Price % Change / Volume Z-Score
   
2. **Multi-Timeframe Merging**:
   - 1H data as base
   - 4H and 1D features forward-filled to prevent look-ahead bias
   
3. **Target Creation**:
   - Future_Close = Close price 4 candles ahead
   - Target = 1 if Future_Close > Current_Close * 1.01, else 0

### Export Format
- **ONNX**: Open Neural Network Exchange format
- **Runtime**: ONNX Runtime for fast inference
- **Portability**: Can be used in any ONNX-compatible environment (Python, C++, JavaScript, etc.)

---

## Limitations & Disclaimers

⚠️ **Important Notes**:

1. **Not Financial Advice**: This is a machine learning experiment, not professional financial advice
2. **Past Performance**: Historical patterns may not predict future results
3. **Market Conditions**: Model trained on specific market conditions may not generalize
4. **Data Quality**: Predictions depend on TradingView data availability and accuracy
5. **Timeframe**: 4-hour prediction window is very short-term
6. **Risk Management**: Always use proper risk management and position sizing

---

## CSV Format Requirements

### Single-Column Format (Recommended)
```csv
Exchange
RELIANCE
INFY
TCS
AAPL
MSFT
```

- **Header**: "Exchange" (or any exchange name like "NSE", "NYSE")
- **Rows**: Stock symbols only
- **Default Exchange**: NSE (if header is not a recognized exchange)

### Multi-Column Format (Also Supported)
```csv
Exchange,Symbol
NSE,RELIANCE
NYSE,AAPL
```

---

## Usage Workflow

1. **Upload CSV** → Load stock symbols
2. **Fetch Data** → Download 1D, 4H, 1H data from TradingView
3. **Train Models** → Train XGBoost and export to ONNX
4. **Run Inference** → Get probability predictions for any trained stock

---

*Last Updated: 2026-01-18*
