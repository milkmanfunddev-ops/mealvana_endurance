// BrickInputController models a brick as an ORDERED LIST OF LEGS — the same
// sport may appear more than once and legs are fuelled in brick order
// (Lee, 2026-08-26). The previous sport-keyed state collapsed Run → Bike → Run
// into two legs and silently dropped the first run's duration; these tests
// pin the leg model end to end.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_metadata.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/brick_input_controller.dart';

void main() {
  late ProviderContainer container;
  late BrickInputController notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(brickInputControllerProvider.notifier);
  });
  tearDown(() => container.dispose());

  BrickFormState state() => container.read(brickInputControllerProvider);

  const runBikeRun = BrickMetadata(
    segmentOrder: ['running', 'cycling', 'running'],
    segments: [
      BrickSegment(
        sport: 'running',
        order: 1,
        durationMinutes: 30,
        intensity: 'moderate',
      ),
      BrickSegment(
        sport: 'cycling',
        order: 2,
        durationMinutes: 60,
        intensity: 'moderate',
      ),
      BrickSegment(
        sport: 'running',
        order: 3,
        durationMinutes: 20,
        intensity: 'moderate',
      ),
    ],
    originalActivityIds: ['r1', 'b1', 'r2'],
    createdFromExisting: true,
    totalDurationMinutes: 110,
  );

  group('initializeFromBrickMetadata', () {
    test(
      'Run(30)→Bike(60)→Run(20) seeds 3 legs in order, durations intact',
      () {
        notifier.initializeFromBrickMetadata(
          runBikeRun,
          DateTime(2026, 8, 26, 8),
        );

        expect(state().legs.length, 3);
        expect(state().segmentOrder, ['running', 'cycling', 'running']);
        expect(state().legs.map((l) => l.durationMinutes), [30, 60, 20]);
        expect(state().legs.map((l) => l.order), [1, 2, 3]);
        expect(notifier.getTotalDuration(), 110);
        expect(state().activityTitle, 'RUN/BIKE/RUN BRICK');
        expect(state().sports, {'running', 'cycling'});
      },
    );

    test('segments are ordered by their `order`, not list position', () {
      const shuffled = BrickMetadata(
        segmentOrder: ['cycling', 'running'],
        segments: [
          BrickSegment(
            sport: 'running',
            order: 2,
            durationMinutes: 20,
            intensity: 'moderate',
          ),
          BrickSegment(
            sport: 'cycling',
            order: 1,
            durationMinutes: 60,
            intensity: 'moderate',
          ),
        ],
        originalActivityIds: ['b1', 'r1'],
        createdFromExisting: true,
        totalDurationMinutes: 80,
      );
      notifier.initializeFromBrickMetadata(shuffled, DateTime(2026, 8, 26));
      expect(state().segmentOrder, ['cycling', 'running']);
    });
  });

  group('legs', () {
    test('default brick is Swim → Run', () {
      expect(state().segmentOrder, ['swimming', 'running']);
    });

    test('addLeg allows a repeated sport and caps at 3', () {
      notifier.addLeg('running');
      expect(state().segmentOrder, ['swimming', 'running', 'running']);
      expect(state().canAddLeg, isFalse);

      notifier.addLeg('cycling'); // ignored — brick is full
      expect(state().legs.length, 3);
    });

    test('removeLegAt renumbers and refuses to go below 2', () {
      notifier.addLeg('cycling'); // swim, run, bike
      notifier.removeLegAt(0); // run, bike
      expect(state().segmentOrder, ['running', 'cycling']);
      expect(state().legs.map((l) => l.order), [1, 2]);

      notifier.removeLegAt(0); // ignored — minimum 2
      expect(state().legs.length, 2);
    });

    test('reorderLegs moves a leg and renumbers', () {
      notifier.addLeg('cycling'); // swim, run, bike
      notifier.reorderLegs(2, 0); // bike, swim, run
      expect(state().segmentOrder, ['cycling', 'swimming', 'running']);
      expect(state().legs.map((l) => l.order), [1, 2, 3]);
      expect(state().activityTitle, 'BIKE/SWIM/RUN BRICK');
    });

    test(
      'updateSegmentInput edits ONE leg by index, not every leg of the sport',
      () {
        notifier.initializeFromBrickMetadata(runBikeRun, DateTime(2026, 8, 26));
        notifier.updateSegmentInput(
          2,
          state().legs[2].copyWith(durationMinutes: 45),
        );
        expect(state().legs.map((l) => l.durationMinutes), [30, 60, 45]);
        expect(notifier.getTotalDuration(), 135);
      },
    );

    test('getSegments emits every leg with order 1..n', () {
      notifier.initializeFromBrickMetadata(runBikeRun, DateTime(2026, 8, 26));
      final segments = notifier.getSegments();
      expect(segments.map((s) => s.sport), ['running', 'cycling', 'running']);
      expect(segments.map((s) => s.order), [1, 2, 3]);
      expect(segments.map((s) => s.durationMinutes), [30, 60, 20]);
      expect(notifier.isValid(), isTrue);
    });
  });
}
