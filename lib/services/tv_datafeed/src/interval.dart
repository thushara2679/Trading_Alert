/// Interval enum for TradingView chart timeframes.
///
/// Defines standard time intervals for TradingView data.
/// Ensures type safety and standardizes interval strings across the application.
enum Interval {
  /// 1 minute interval
  in1Minute('1'),

  /// 3 minute interval
  in3Minute('3'),

  /// 5 minute interval
  in5Minute('5'),

  /// 15 minute interval
  in15Minute('15'),

  /// 30 minute interval
  in30Minute('30'),

  /// 45 minute interval
  in45Minute('45'),

  /// 1 hour interval
  in1Hour('1H'),

  /// 2 hour interval
  in2Hour('2H'),

  /// 3 hour interval
  in3Hour('3H'),

  /// 4 hour interval
  in4Hour('4H'),

  /// Daily interval
  inDaily('1D'),

  /// Weekly interval
  inWeekly('1W'),

  /// Monthly interval
  inMonthly('1M');

  /// The TradingView string representation of the interval.
  final String value;

  const Interval(this.value);

  /// Get interval duration for scheduling.
  Duration get duration {
    switch (this) {
      case Interval.in1Minute:
        return const Duration(minutes: 1);
      case Interval.in3Minute:
        return const Duration(minutes: 3);
      case Interval.in5Minute:
        return const Duration(minutes: 5);
      case Interval.in15Minute:
        return const Duration(minutes: 15);
      case Interval.in30Minute:
        return const Duration(minutes: 30);
      case Interval.in45Minute:
        return const Duration(minutes: 45);
      case Interval.in1Hour:
        return const Duration(hours: 1);
      case Interval.in2Hour:
        return const Duration(hours: 2);
      case Interval.in3Hour:
        return const Duration(hours: 3);
      case Interval.in4Hour:
        return const Duration(hours: 4);
      case Interval.inDaily:
        return const Duration(days: 1);
      case Interval.inWeekly:
        return const Duration(days: 7);
      case Interval.inMonthly:
        return const Duration(days: 30);
    }
  }
}
