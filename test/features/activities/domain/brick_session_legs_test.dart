// Brick → per-leg session decomposition (`BrickSessionLegs.sessionLegs`).
//
// Fixtures go through `BrickMetadata.fromJson` on the WIRE shape (snake_case,
// the exact JSON `activity_mapper` persists) rather than the Dart
// constructors — per the producer→consumer rule, the shape under test is the
// one the producer actually writes.
//
// INTERIM decomposition pending
// qa/intake/2026-09-04-brick-per-leg-pricing-ratification.md.
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_metadata.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_session_legs.dart';

BrickMetadata _wire(List<Map<String, dynamic>> segments) =>
    BrickMetadata.fromJson({
      'segment_order': [for (final s in segments) s['sport']],
      'segments': segments,
      'created_from_existing': false,
      'total_duration_minutes': segments.fold<int>(
        0,
        (sum, s) => sum + (s['duration_minutes'] as int),
      ),
    });

void main() {
  test('legs keep segment order and their own sport and duration', () {
    // The reported Sept 5 brick: run 65 → bike 100 → run 144 (309 min total),
    // which shipped priced as ONE 309-min conservative-rate session.
    final legs = _wire([
      {'sport': 'running', 'order': 1, 'duration_minutes': 65, 'intensity': 'moderate'},
      {'sport': 'cycling', 'order': 2, 'duration_minutes': 100, 'intensity': 'moderate'},
      {'sport': 'running', 'order': 3, 'duration_minutes': 144, 'intensity': 'moderate'},
    ]).sessionLegs;

    expect(legs.map((l) => l.sport), ['running', 'cycling', 'running']);
    expect(legs.map((l) => l.durationMinutes), [65, 100, 144]);
  });

  test('a swim leg maps to the swimming rate, not running', () {
    final legs = _wire([
      {'sport': 'swimming', 'order': 1, 'duration_minutes': 30, 'intensity': 'moderate'},
    ]).sessionLegs;
    expect(legs.single.sport, 'swimming');
  });

  test('a zero-minute leg derives duration from its own distance × pace', () {
    // Same ladder as a standalone session: explicit minutes win, else the
    // leg's prescribed pace derives them.
    final legs = _wire([
      {
        'sport': 'running',
        'order': 1,
        'duration_minutes': 0,
        'intensity': 'moderate',
        'distance_miles': 6.0,
        'pace_minutes_per_mile': 10.0,
      },
    ]).sessionLegs;
    expect(legs.single.durationMinutes, 60);
  });

  test('a zero-minute swim leg derives from meters via the miles ladder', () {
    // 1500 m at 2:00/100m = 30 min. The segment stores meters; the shared
    // ladder speaks miles — the conversion must not lose the derivation.
    final legs = _wire([
      {
        'sport': 'swimming',
        'order': 1,
        'duration_minutes': 0,
        'intensity': 'moderate',
        'distance_meters': 1500.0,
        'pace_per_100m_seconds': 120,
      },
    ]).sessionLegs;
    expect(legs.single.durationMinutes, 30);
  });

  test('empty segments yield no legs (caller falls back to single-session)',
      () {
    expect(_wire([]).sessionLegs, isEmpty);
  });
}
