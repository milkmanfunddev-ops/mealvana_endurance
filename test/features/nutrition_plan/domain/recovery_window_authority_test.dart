/// The recovery-window authority (`docs/ssot/spec/fueling/post-workout.md`,
/// RATIFIED v1): branch selection across the 8 h threshold (7.99 / 8.0 /
/// null, its Conformance item 1), the 8–24 h band's softened copy (§6 Q1),
/// the fuel-demanding gate (§6 Q2), and the window each branch holds open.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/recovery_window_authority.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  group('branch', () {
    test('under 8 h to the next fuel-demanding session is urgent', () {
      expect(
        recoveryBranch(const Duration(hours: 7, minutes: 59, seconds: 24)),
        RecoveryBranch.urgent,
      );
    });

    test('8 h exactly is relaxed', () {
      expect(recoveryBranch(const Duration(hours: 8)), RecoveryBranch.relaxed);
    });

    test('no next session known is relaxed', () {
      expect(recoveryBranch(null), RecoveryBranch.relaxed);
    });
  });

  group('the 8–24 h band: relaxed, with copy softened', () {
    test('8 h up to under 24 h is softened', () {
      expect(recoveryCopySoftened(const Duration(hours: 8)), isTrue);
      expect(
        recoveryCopySoftened(const Duration(hours: 23, minutes: 59)),
        isTrue,
      );
    });

    test('urgent, a day or more, or unknown is not', () {
      expect(recoveryCopySoftened(const Duration(hours: 7)), isFalse);
      expect(recoveryCopySoftened(const Duration(hours: 24)), isFalse);
      expect(recoveryCopySoftened(null), isFalse);
    });
  });

  group('window', () {
    test('urgent: carbs through the next 4 h', () {
      expect(recoveryWindow(RecoveryBranch.urgent), const Duration(hours: 4));
    });

    test('relaxed: the protein dose within 2 h', () {
      expect(recoveryWindow(RecoveryBranch.relaxed), const Duration(hours: 2));
    });
  });

  group('fuel-demanding', () {
    test('an endurance session of 60 min or more', () {
      for (final type in [
        ActivityType.running,
        ActivityType.cycling,
        ActivityType.swimming,
        ActivityType.brick,
        ActivityType.triathlon,
      ]) {
        expect(
          isFuelDemandingSession(type: type, durationMinutes: 60),
          isTrue,
          reason: type.name,
        );
      }
    });

    test('under 60 min, or of unknown length, is not', () {
      expect(
        isFuelDemandingSession(type: ActivityType.running, durationMinutes: 59),
        isFalse,
      );
      expect(
        isFuelDemandingSession(
          type: ActivityType.running,
          durationMinutes: null,
        ),
        isFalse,
      );
    });

    test('a strength-only (import-only) hour is not', () {
      expect(
        isFuelDemandingSession(type: ActivityType.other, durationMinutes: 90),
        isFalse,
      );
    });
  });
}
