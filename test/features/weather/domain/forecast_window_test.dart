import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/weather/domain/forecast_window.dart';

/// Finding 100-004: location is asked for only on an upcoming activity with
/// a forecast. The window mirrors get-weather-forecast's 0-16 days ahead.
void main() {
  final now = DateTime(2026, 9, 26, 10, 30);

  test('today and tomorrow are inside the window', () {
    expect(ForecastWindow.covers(DateTime(2026, 9, 26, 7), now: now), isTrue);
    expect(ForecastWindow.covers(DateTime(2026, 9, 27, 19), now: now), isTrue);
  });

  test('yesterday is outside, whatever the hour', () {
    expect(ForecastWindow.covers(DateTime(2026, 9, 25, 23), now: now), isFalse);
  });

  test('16 days ahead is the last day in; 17 is out', () {
    expect(ForecastWindow.covers(DateTime(2026, 10, 12), now: now), isTrue);
    expect(ForecastWindow.covers(DateTime(2026, 10, 13), now: now), isFalse);
  });
}
