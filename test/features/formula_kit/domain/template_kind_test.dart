import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_pin.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

/// Forward-compat tests for [TemplateKind] and [FormulaPin.fromDriftEntry].
///
/// PR 3 substep 1 made [TemplateKind.fromWireValue] return null on unknown
/// inputs; substep 3 widened the enum with `postSystem`. The "unknown wire
/// value" tests below use a stand-in (`'personal_template'`) that future PR 5
/// will likely turn into a real case. These tests lock in the contract so
/// future enum widenings inherit the same tolerance.
void main() {
  group('TemplateKind.fromWireValue', () {
    test('returns enum for pre_system', () {
      expect(TemplateKind.fromWireValue('pre_system'), TemplateKind.preSystem);
    });

    test('returns enum for during_system', () {
      expect(
        TemplateKind.fromWireValue('during_system'),
        TemplateKind.duringSystem,
      );
    });

    test('returns enum for post_system', () {
      expect(
        TemplateKind.fromWireValue('post_system'),
        TemplateKind.postSystem,
      );
    });

    test('returns null for unknown wire value (forward-compat)', () {
      // Simulates a PR 3 binary reading a future `personal_template` row
      // written by a PR 5+ client. Old binary must tolerate the unknown
      // value, not crash.
      expect(TemplateKind.fromWireValue('personal_template'), isNull);
    });

    test('returns null for unrelated string', () {
      expect(TemplateKind.fromWireValue('totally_new_kind'), isNull);
    });

    test('returns null for empty string', () {
      expect(TemplateKind.fromWireValue(''), isNull);
    });

    test('returns null for null input', () {
      expect(TemplateKind.fromWireValue(null), isNull);
    });
  });

  group('FormulaPin.fromDriftEntry', () {
    FormulaPinEntry buildEntry({required String templateKind}) {
      return FormulaPinEntry(
        id: 'pin-1',
        userId: 'user-1',
        templateId: 'tpl-1',
        templateKind: templateKind,
        createdAt: DateTime.utc(2026, 5, 26),
        updatedAt: DateTime.utc(2026, 5, 26),
        isDeleted: false,
      );
    }

    test('decodes a row with a known kind', () {
      final pin = FormulaPin.fromDriftEntry(
        buildEntry(templateKind: 'during_system'),
      );
      expect(pin, isNotNull);
      expect(pin!.templateKind, TemplateKind.duringSystem);
      expect(pin.id, 'pin-1');
    });

    test('returns null for a row with an unknown kind', () {
      // PR 3 binary reading a future PR 5 row. The repository's
      // _decodePinEntries helper skips + logs these; the algorithm sees a
      // smaller pin set and falls through gracefully rather than crashing
      // on launch.
      final pin = FormulaPin.fromDriftEntry(
        buildEntry(templateKind: 'personal_template'),
      );
      expect(pin, isNull);
    });
  });
}
