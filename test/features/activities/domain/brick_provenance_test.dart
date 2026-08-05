/// Brick provenance must survive a plan re-save (regression for bf0b591f).
///
/// `generateBrickMacros` always builds its [BrickMetadata] with
/// `originalActivityIds: null` / `createdFromExisting: false` hardcoded —
/// values that are only correct for a brick authored from scratch on the Brick
/// tab. That same object was fed to the *update* branch, so re-saving a brick
/// that had been grouped from existing workouts erased the record of which
/// activities it came from, and with it the ability to ungroup.
///
/// The fix carries the existing values across with `copyWith` before the
/// update. These tests pin the two halves of that contract:
///   1. `copyWith` preserves provenance when handed the existing values.
///   2. `copyWith` falls back to the receiver when the existing brick has none,
///      so a from-scratch brick is unaffected.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_metadata.dart';

void main() {
  BrickSegment segment(String sport, int order, int minutes) => BrickSegment(
    sport: sport,
    order: order,
    durationMinutes: minutes,
    intensity: 'moderate',
  );

  /// What `generateBrickMacros` produces on every run — provenance always blank.
  BrickMetadata freshlyGenerated() => BrickMetadata(
    segmentOrder: const ['cycling', 'running'],
    segments: [segment('cycling', 1, 60), segment('running', 2, 30)],
    originalActivityIds: null,
    createdFromExisting: false,
    totalDurationMinutes: 90,
  );

  /// A brick the user built by grouping two existing workouts.
  BrickMetadata groupedFromExisting() => BrickMetadata(
    segmentOrder: const ['cycling', 'running'],
    segments: [segment('cycling', 1, 60), segment('running', 2, 30)],
    originalActivityIds: const ['act-111', 'act-222'],
    createdFromExisting: true,
    totalDurationMinutes: 90,
  );

  group('re-saving a grouped brick', () {
    test('preserves originalActivityIds and createdFromExisting', () {
      final existing = groupedFromExisting();

      // The shape the update branch uses.
      final preserved = freshlyGenerated().copyWith(
        originalActivityIds: existing.originalActivityIds,
        createdFromExisting: existing.createdFromExisting,
      );

      expect(preserved.originalActivityIds, ['act-111', 'act-222']);
      expect(preserved.createdFromExisting, isTrue);
    });

    test('still takes the regenerated segments and duration', () {
      final existing = groupedFromExisting();
      final regenerated = BrickMetadata(
        segmentOrder: const ['swimming', 'cycling', 'running'],
        segments: [
          segment('swimming', 1, 20),
          segment('cycling', 2, 60),
          segment('running', 3, 30),
        ],
        originalActivityIds: null,
        createdFromExisting: false,
        totalDurationMinutes: 110,
      );

      final preserved = regenerated.copyWith(
        originalActivityIds: existing.originalActivityIds,
        createdFromExisting: existing.createdFromExisting,
      );

      // Provenance from the old row, everything else from the new plan.
      expect(preserved.originalActivityIds, ['act-111', 'act-222']);
      expect(preserved.createdFromExisting, isTrue);
      expect(preserved.segmentOrder, ['swimming', 'cycling', 'running']);
      expect(preserved.totalDurationMinutes, 110);
      expect(preserved.segments, hasLength(3));
    });

    test('provenance survives a full JSON round trip', () {
      final preserved = freshlyGenerated().copyWith(
        originalActivityIds: const ['act-111', 'act-222'],
        createdFromExisting: true,
      );

      final restored = BrickMetadata.fromJson(preserved.toJson());

      expect(restored.originalActivityIds, ['act-111', 'act-222']);
      expect(restored.createdFromExisting, isTrue);
      expect(restored, preserved);
    });
  });

  group('re-saving a from-scratch brick', () {
    test('stays blank when the existing row has no provenance', () {
      final existing = freshlyGenerated();

      final preserved = freshlyGenerated().copyWith(
        originalActivityIds: existing.originalActivityIds, // null
        createdFromExisting: existing.createdFromExisting, // false
      );

      expect(preserved.originalActivityIds, isNull);
      expect(preserved.createdFromExisting, isFalse);
    });

    test('stays blank when there is no existing brick metadata at all', () {
      // The update branch reads `existingActivity.brickMetadata?.…`, so both
      // arguments arrive as null when the row had no metadata.
      final preserved = freshlyGenerated().copyWith(
        originalActivityIds: null,
        createdFromExisting: null,
      );

      expect(preserved.originalActivityIds, isNull);
      expect(preserved.createdFromExisting, isFalse);
    });
  });

  group('copyWith fallback semantics the fix depends on', () {
    test('a null argument falls back to the receiver, never to a default', () {
      final grouped = groupedFromExisting();

      // Passing nothing must not silently clear provenance.
      final untouched = grouped.copyWith();

      expect(untouched.originalActivityIds, ['act-111', 'act-222']);
      expect(untouched.createdFromExisting, isTrue);
      expect(untouched, grouped);
    });

    test('an empty provenance list is preserved as empty, not as null', () {
      final withEmpty = groupedFromExisting().copyWith(
        originalActivityIds: const [],
      );

      expect(withEmpty.originalActivityIds, isEmpty);
      expect(withEmpty.originalActivityIds, isNotNull);
    });
  });
}
