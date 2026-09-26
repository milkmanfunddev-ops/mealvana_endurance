// Finding 117-007 (ticket 141): Event Details said "1 month away" for an
// event 58 days out, because three copies of the countdown floored whole
// months. One shared function now counts weeks up to about nine and rounds
// months beyond that.
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/events/domain/event_countdown.dart';

void main() {
  final today = DateTime(2026, 9, 26, 10, 30);

  String at(int days) =>
      eventCountdownText(today.add(Duration(days: days)), today: today);

  test('58 days reads 8 weeks away, not 1 month', () {
    expect(at(58), '8 weeks away');
  });

  test('days under a week, then weeks rounded to the nearest', () {
    expect(at(0), 'Today!');
    expect(at(1), 'Tomorrow');
    expect(at(6), '6 days away');
    expect(at(7), '1 week away');
    expect(at(10), '1 week away');
    expect(at(11), '2 weeks away');
    expect(at(30), '4 weeks away');
    expect(at(45), '6 weeks away');
    expect(at(62), '9 weeks away');
  });

  test('months from nine weeks on, rounded to the nearest', () {
    expect(at(63), '2 months away');
    expect(at(90), '3 months away');
    expect(at(120), '4 months away');
    expect(at(365), '12 months away');
  });

  test('the past and the one-day labels are the caller\'s', () {
    expect(
      eventCountdownText(
        today.subtract(const Duration(days: 1)),
        today: today,
        pastLabel: 'Event completed',
      ),
      'Event completed',
    );
    expect(
      eventCountdownText(
        today.add(const Duration(days: 1)),
        today: today,
        oneDayLabel: '1 day away',
      ),
      '1 day away',
    );
  });

  test('compares at day level: a late-evening event tomorrow is Tomorrow', () {
    expect(
      eventCountdownText(DateTime(2026, 9, 27, 23, 59), today: today),
      'Tomorrow',
    );
  });
}
