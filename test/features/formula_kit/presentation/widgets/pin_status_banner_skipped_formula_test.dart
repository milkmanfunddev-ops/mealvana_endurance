import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/pin_decision.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/widgets/pin_status_banner.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/plan_section.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/utils/pin_banner_rows_builder.dart';

// Regression cover for the audit of 2026-07-18
// (docs/architecture/formula-not-honored-audit-2026-07-18.md).
//
// Reported bug: a user authored a cycling formula for rides over 90 minutes,
// then created a ~75 minute ride. The formula was excluded by duration scope,
// an unrelated system pin fired instead, and the wire response reported
// `usedPin: true` naming THAT pin. The banner therefore rendered a green
// "Using your pinned formulas" state for a formula the user never chose, and
// nothing on screen said their own formula had been dropped.
//
// The contract these tests lock in:
//   1. A skipped personal formula is never rendered as an unqualified success,
//      even when something else was legitimately honored.
//   2. The "?" affordance appears whenever a formula was skipped.
//   3. An EPHEMERAL decision carrying skips survives the rows-builder filter
//      (the ephemeral default-formula path is the most common way to hit this).

const _skippedByDuration = SkippedPersonalFormula(
  id: 'pf-1',
  name: 'Carb Drink Mix + Stroopwafel',
  reason: SkippedFormulaReason.durationOutOfScope,
  formulaDurations: ['90-150 min', '150-240 min'],
  workoutBracket: '< 90 min',
);

const _skippedByActivity = SkippedPersonalFormula(
  id: 'pf-2',
  name: 'Long Run Fuel',
  reason: SkippedFormulaReason.activityOutOfScope,
  formulaDurations: [],
  workoutBracket: '< 90 min',
);

/// The exact shape the edge function now emits for the reported scenario: a
/// system pin fired, AND the user's own formula was skipped.
const _systemPinHonoredButFormulaSkipped = PinDecision(
  usedPin: true,
  pinnedTemplateId: 'tpl-sports-drink',
  pinnedTemplateName: 'Sports Drink Only',
  fallthroughReason: null,
  pinSetSize: 1,
  skippedPersonalFormulas: [_skippedByDuration],
);

Widget _host(List<PinStatusBannerRow> rows) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(child: PinStatusBanner(rows: rows)),
  ),
);

void main() {
  group('PinStatusBanner — skipped personal formula', () {
    testWidgets(
      'does NOT claim success when a formula was skipped, even though a '
      'system pin was honored',
      (tester) async {
        await tester.pumpWidget(
          _host(const [
            PinStatusBannerRow(
              label: 'During',
              decision: _systemPinHonoredButFormulaSkipped,
            ),
          ]),
        );

        // This is the regression: before the fix the header read
        // "Using your pinned formulas" for a formula the user never chose.
        expect(find.text('Using your pinned formulas'), findsNothing);
        expect(find.text('Your formula didn\'t apply here'), findsOneWidget);
      },
    );

    testWidgets('renders the "?" affordance when a formula was skipped', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const [
          PinStatusBannerRow(
            label: 'During',
            decision: _systemPinHonoredButFormulaSkipped,
          ),
        ]),
      );

      expect(
        find.byKey(const ValueKey('pin_status_banner.skip_details_button')),
        findsOneWidget,
      );
    });

    testWidgets('hides the "?" affordance when nothing was skipped', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const [
          PinStatusBannerRow(
            label: 'During',
            decision: PinDecision(
              usedPin: true,
              pinnedTemplateId: 'tpl-1',
              pinnedTemplateName: 'Bagel + Jam',
              fallthroughReason: null,
              pinSetSize: 1,
            ),
          ),
        ]),
      );

      expect(
        find.byKey(const ValueKey('pin_status_banner.skip_details_button')),
        findsNothing,
      );
      expect(find.text('Using your pinned formulas'), findsOneWidget);
    });

    testWidgets('tapping "?" explains the duration miss in plain language', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const [
          PinStatusBannerRow(
            label: 'During',
            decision: _systemPinHonoredButFormulaSkipped,
          ),
        ]),
      );

      await tester.tap(
        find.byKey(const ValueKey('pin_status_banner.skip_details_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Why your formula wasn\'t used'), findsOneWidget);
      // Names the formula, what it targets, and what this workout was.
      expect(
        find.textContaining('Carb Drink Mix + Stroopwafel'),
        findsOneWidget,
      );
      expect(find.textContaining('90-150 min'), findsOneWidget);
      expect(find.textContaining('< 90 min'), findsOneWidget);
    });

    testWidgets('explains an activity miss differently from a duration miss', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const [
          PinStatusBannerRow(
            label: 'During',
            decision: PinDecision(
              usedPin: false,
              pinnedTemplateId: null,
              pinnedTemplateName: null,
              fallthroughReason: PinFallthroughReason.noPinForScope,
              pinSetSize: 0,
              skippedPersonalFormulas: [_skippedByActivity],
            ),
          ),
        ]),
      );

      await tester.tap(
        find.byKey(const ValueKey('pin_status_banner.skip_details_button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('isn\'t set up for this activity type'),
        findsOneWidget,
      );
    });
  });

  group('PinDecision — skipped formula parsing', () {
    test('parses skipped_personal_formulas from the edge function shape', () {
      final decision = PinDecision.fromJson(const {
        'used_pin': true,
        'pinned_template_id': 'tpl-sports-drink',
        'pinned_template_name': 'Sports Drink Only',
        'fallthrough_reason': null,
        'pin_set_size': 1,
        'skipped_personal_formulas': [
          {
            'id': 'pf-1',
            'name': 'Carb Drink Mix + Stroopwafel',
            'reason': 'duration_out_of_scope',
            'formula_durations': ['90-150 min'],
            'workout_bracket': '< 90 min',
          },
        ],
      });

      expect(decision.hasSkippedFormulas, isTrue);
      expect(
        decision.skippedPersonalFormulas.single.name,
        'Carb Drink Mix + Stroopwafel',
      );
      expect(
        decision.skippedPersonalFormulas.single.reason,
        SkippedFormulaReason.durationOutOfScope,
      );
      expect(
        decision.skippedPersonalFormulas.single.workoutBracket,
        '< 90 min',
      );
    });

    test('legacy plans with no skip list parse to empty, not null', () {
      final decision = PinDecision.fromJson(const {
        'used_pin': false,
        'pinned_template_id': null,
        'pinned_template_name': null,
        'fallthrough_reason': 'no_pin_for_scope',
        'pin_set_size': 0,
      });

      expect(decision.skippedPersonalFormulas, isEmpty);
      expect(decision.hasSkippedFormulas, isFalse);
    });

    test('unknown reason parses to null rather than throwing', () {
      final decision = PinDecision.fromJson(const {
        'used_pin': false,
        'pinned_template_id': null,
        'pinned_template_name': null,
        'fallthrough_reason': 'no_pin_for_scope',
        'pin_set_size': 0,
        'skipped_personal_formulas': [
          {'id': 'x', 'name': 'Future', 'reason': 'season_out_of_scope'},
        ],
      });

      expect(decision.skippedPersonalFormulas.single.reason, isNull);
      expect(decision.hasSkippedFormulas, isTrue);
    });

    test('round-trips through toJson', () {
      const original = _systemPinHonoredButFormulaSkipped;
      final restored = PinDecision.fromJson(original.toJson());
      expect(
        restored.skippedPersonalFormulas.single.name,
        original.skippedPersonalFormulas.single.name,
      );
      expect(
        restored.skippedPersonalFormulas.single.reason,
        original.skippedPersonalFormulas.single.reason,
      );
    });
  });

  group('collectPinBannerRows — ephemeral decisions carrying skips', () {
    test('an ephemeral decision WITH skips is kept, not filtered away', () {
      // The ephemeral default-formula safety net is normally invisible to the
      // banner. But when it fires *because* the user's formula was scope-
      // excluded, hiding it is what made the bug undiagnosable.
      final sections = <PlanSection>[
        PlanSection(
          id: 'during_run',
          title: 'During',
          foodItems: const [],
          pinDecision: const PinDecision(
            usedPin: true,
            ephemeral: true,
            pinnedTemplateId: 'tpl-default',
            pinnedTemplateName: 'Sports Drink Only',
            fallthroughReason: null,
            pinSetSize: 0,
            skippedPersonalFormulas: [_skippedByDuration],
          ),
        ),
      ];

      final data = collectPinBannerRows(sections);

      expect(data.isOnboarding, isFalse);
      expect(data.rows, hasLength(1));
      expect(data.rows.single.decision.hasSkippedFormulas, isTrue);
    });

    test('an ephemeral decision WITHOUT skips stays invisible', () {
      final sections = <PlanSection>[
        PlanSection(
          id: 'during_run',
          title: 'During',
          foodItems: const [],
          pinDecision: const PinDecision(
            usedPin: true,
            ephemeral: true,
            pinnedTemplateId: 'tpl-default',
            pinnedTemplateName: 'Banana',
            fallthroughReason: null,
            pinSetSize: 0,
          ),
        ),
      ];

      // No real decisions → onboarding prompt, exactly as before the change.
      expect(collectPinBannerRows(sections).isOnboarding, isTrue);
    });
  });
}
