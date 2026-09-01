import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/cooking_step_timers.dart';

void main() {
  group('CookingStepTimers.findDurations (port of food.cook_.\$id.tsx)', () {
    test('a range takes the upper bound', () {
      final t = CookingStepTimers.findDurations('Simmer for 10-12 minutes');
      expect(t, [
        const StepTimer(label: '10-12 minutes', seconds: 720, index: 11),
      ]);
    });

    test('en/em dashes and "to" are ranges too', () {
      expect(
        CookingStepTimers.findDurations('Bake 10–12 mins').single.seconds,
        720,
      );
      expect(
        CookingStepTimers.findDurations('Bake 10—12 mins').single.seconds,
        720,
      );
      expect(
        CookingStepTimers.findDurations('Bake 10 to 15 min').single.seconds,
        900,
      );
    });

    test('several durations in one step, in text order', () {
      final t = CookingStepTimers.findDurations(
        'Bake 25 mins, then rest 5 min before slicing',
      );
      expect(t.map((d) => d.seconds), [1500, 300]);
      expect(t.map((d) => d.label), ['25 mins', '5 min']);
    });

    test('unit spellings', () {
      int s(String text) =>
          CookingStepTimers.findDurations(text).single.seconds;
      expect(s('90 seconds'), 90);
      expect(s('90 secs'), 90);
      expect(s('45 sec'), 45);
      expect(s('5sec'), 5);
      expect(s('3 minutes'), 180);
      expect(s('3 minute'), 180);
      expect(s('3 mins'), 180);
      expect(s('about 1 hour'), 3600);
      expect(s('2 hours'), 7200);
      expect(s('1.5 hrs'), 5400);
      expect(s('1 hr'), 3600);
    });

    test('is case-insensitive', () {
      expect(
        CookingStepTimers.findDurations('Roast 20 MINUTES').single.seconds,
        1200,
      );
    });

    test('drops durations under 5 s and over 12 h', () {
      expect(CookingStepTimers.findDurations('Whisk for 3 seconds'), isEmpty);
      expect(CookingStepTimers.findDurations('Marinate 24 hours'), isEmpty);
      expect(
        CookingStepTimers.findDurations('Rest 12 hours').single.seconds,
        12 * 3600,
      );
    });

    test('a number over 600 is a parse error, whatever the unit', () {
      expect(CookingStepTimers.findDurations('700 minutes'), isEmpty);
      expect(
        CookingStepTimers.findDurations('600 minutes').single.seconds,
        36000,
      );
    });

    test('ignores numbers without a time unit', () {
      expect(CookingStepTimers.findDurations('Add 2 cups of stock'), isEmpty);
      expect(
        CookingStepTimers.findDurations('Preheat to 200 degrees'),
        isEmpty,
      );
      expect(CookingStepTimers.findDurations('Chop 3 minted leaves'), isEmpty);
    });

    test('collapses duplicates (same seconds), keeping the first', () {
      final t = CookingStepTimers.findDurations(
        'Cook 5 min, stir, another 5 minutes, then 5 mins more',
      );
      expect(t, hasLength(1));
      expect(t.single.label, '5 min');
    });

    test('caps at three per step', () {
      final t = CookingStepTimers.findDurations(
        '1 min, then 2 min, then 3 min, then 4 min',
      );
      expect(t.map((d) => d.seconds), [60, 120, 180]);
    });

    test('no durations → empty', () {
      expect(CookingStepTimers.findDurations('Serve immediately.'), isEmpty);
      expect(CookingStepTimers.findDurations(''), isEmpty);
    });
  });

  group('CookingStepTimers.clock', () {
    test('m:ss below an hour', () {
      expect(CookingStepTimers.clock(0), '0:00');
      expect(CookingStepTimers.clock(5), '0:05');
      expect(CookingStepTimers.clock(65), '1:05');
      expect(CookingStepTimers.clock(720), '12:00');
    });

    test('h:mm:ss from an hour', () {
      expect(CookingStepTimers.clock(3600), '1:00:00');
      expect(CookingStepTimers.clock(3725), '1:02:05');
    });

    test('negative clamps to zero', () {
      expect(CookingStepTimers.clock(-9), '0:00');
    });
  });
}
