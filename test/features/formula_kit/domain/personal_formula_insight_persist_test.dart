import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/personal_formula.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';

/// Regression tests for coach-insight persistence on PersonalFormula.
///
/// Bug: coach insight was stored only in an auto-disposing Riverpod provider
/// and erased on navigation. Fix adds coachInsightText + coachInsightMarker
/// columns persisted through Drift and Supabase.
void main() {
  final now = DateTime.utc(2026, 6, 15);

  PersonalFormula makeFormula({
    String? coachInsightText,
    String? coachInsightMarker,
  }) {
    return PersonalFormula(
      id: 'test-id',
      userId: 'user-1',
      name: 'Pre-Run Oats',
      provenance: FormulaProvenance.fromScratchFormula,
      phase: FormulaPhase.before,
      components: const [],
      createdAt: now,
      updatedAt: now,
      coachInsightText: coachInsightText,
      coachInsightMarker: coachInsightMarker,
    );
  }

  group('Drift companion round-trip', () {
    test('preserves insight fields through toDriftCompanion', () {
      final formula = makeFormula(
        coachInsightText: 'Add more sodium for hot-weather runs.',
        coachInsightMarker: 'abc123',
      );
      final companion = formula.toDriftCompanion();
      expect(
        companion.coachInsightText.value,
        'Add more sodium for hot-weather runs.',
      );
      expect(companion.coachInsightMarker.value, 'abc123');
    });

    test('preserves null insight fields through toDriftCompanion', () {
      final formula = makeFormula();
      final companion = formula.toDriftCompanion();
      expect(companion.coachInsightText.value, isNull);
      expect(companion.coachInsightMarker.value, isNull);
    });
  });

  group('Supabase JSON round-trip', () {
    test('insight fields survive toSupabaseJson -> fromSupabaseJson', () {
      final original = makeFormula(
        coachInsightText: 'Consider a gel at 45 min.',
        coachInsightMarker: 'marker-xyz',
      );
      final json = original.toSupabaseJson();

      expect(json['coach_insight_text'], 'Consider a gel at 45 min.');
      expect(json['coach_insight_marker'], 'marker-xyz');

      final restored = PersonalFormula.fromSupabaseJson(json);
      expect(restored, isNotNull);
      expect(restored!.coachInsightText, 'Consider a gel at 45 min.');
      expect(restored.coachInsightMarker, 'marker-xyz');
    });

    test('null insight fields round-trip correctly', () {
      final original = makeFormula();
      final json = original.toSupabaseJson();

      expect(json['coach_insight_text'], isNull);
      expect(json['coach_insight_marker'], isNull);

      final restored = PersonalFormula.fromSupabaseJson(json);
      expect(restored, isNotNull);
      expect(restored!.coachInsightText, isNull);
      expect(restored.coachInsightMarker, isNull);
    });
  });

  group('copyWith sentinel behavior', () {
    test('preserves existing insight when sentinel (default) is used', () {
      final formula = makeFormula(
        coachInsightText: 'Keep this.',
        coachInsightMarker: 'keep-marker',
      );
      final copied = formula.copyWith(name: 'New Name');
      expect(copied.coachInsightText, 'Keep this.');
      expect(copied.coachInsightMarker, 'keep-marker');
    });

    test('can explicitly set insight to null', () {
      final formula = makeFormula(
        coachInsightText: 'Remove me.',
        coachInsightMarker: 'old-marker',
      );
      final cleared = formula.copyWith(
        coachInsightText: null,
        coachInsightMarker: null,
      );
      expect(cleared.coachInsightText, isNull);
      expect(cleared.coachInsightMarker, isNull);
    });

    test('can update insight to a new value', () {
      final formula = makeFormula(
        coachInsightText: 'Old insight.',
        coachInsightMarker: 'old',
      );
      final updated = formula.copyWith(
        coachInsightText: 'New insight.',
        coachInsightMarker: 'new',
      );
      expect(updated.coachInsightText, 'New insight.');
      expect(updated.coachInsightMarker, 'new');
    });
  });

  group('staleMarker invalidation', () {
    test('insight marker mismatch signals stale insight', () {
      final formula = makeFormula(
        coachInsightText: 'Old advice.',
        coachInsightMarker: 'hash-before-edit',
      );
      const currentDraftMarker = 'hash-after-edit';
      expect(formula.coachInsightMarker, isNot(currentDraftMarker));
    });

    test('insight marker match signals fresh insight', () {
      const marker = 'same-hash';
      final formula = makeFormula(
        coachInsightText: 'Current advice.',
        coachInsightMarker: marker,
      );
      expect(formula.coachInsightMarker, marker);
    });
  });
}
