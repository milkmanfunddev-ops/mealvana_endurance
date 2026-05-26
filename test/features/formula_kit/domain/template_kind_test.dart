import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_pin.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

/// Forward-compat tests for [TemplateKind] and [FormulaPin.fromDriftEntry].
///
/// PR 3 widens the `template_kind` CHECK constraint to include `'post_system'`.
/// Old binaries running the PR 2 enum must NOT crash when reading rows whose
/// wire value they don't recognize. They should decode to null and be skipped
/// at the repository layer. These tests lock in that contract so future enum
/// widenings (e.g. `personal_template` in PR 5) inherit the same tolerance.
void main() {
  group('TemplateKind.fromWireValue', () {
    test('returns enum for pre_system', () {
      expect(
        TemplateKind.fromWireValue('pre_system'),
        TemplateKind.preSystem,
      );
    });

    test('returns enum for during_system', () {
      expect(
        TemplateKind.fromWireValue('during_system'),
        TemplateKind.duringSystem,
      );
    });

    test('returns null for unknown wire value (forward-compat)', () {
      // Simulates a PR 2 binary reading a PR 3 `post_system` row written by
      // a newer client. Old binary must tolerate the unknown value, not crash.
      expect(TemplateKind.fromWireValue('post_system'), isNull);
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
      // PR 2 binary reading a PR 3 row. The repository's _decodePinEntries
      // helper skips + logs these; the algorithm sees a smaller pin set and
      // falls through gracefully rather than crashing on launch.
      final pin = FormulaPin.fromDriftEntry(
        buildEntry(templateKind: 'post_system'),
      );
      expect(pin, isNull);
    });
  });
}
