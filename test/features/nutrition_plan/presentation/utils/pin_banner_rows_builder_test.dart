import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/pin_decision.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/plan_section.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/utils/pin_banner_rows_builder.dart';

// Locks in the three-state synthesis rule for the activity-detail pin
// banner (Formula Kit PR 2 substep 11 polish). See
// `docs/features/formula-kit/PLAN.md` → "PinStatusBanner V1 polish".
//
// The rule, in short:
//   - If the plan has no pinnable phases at all (short walk, no
//     Before/During) → return Hidden. Banner stays off-screen.
//   - If the plan has pinnable phases but ZERO real PinDecisions →
//     return Onboarding. Banner becomes a discovery prompt for users
//     who haven't engaged with pins yet.
//   - Otherwise emit a row per pinnable phase present in the plan
//     (Status mode):
//       * Pinnable sub_phases (meal / snack / top_up) on Before sections
//       * The During section itself
//     Real decisions render as-is; missing ones get a synthesized
//     `PinDecision(usedPin: false, pinSetSize: 0, fallthroughReason:
//     noPinForScope)` so the banner is honest about every place a pin
//     could have applied.

PinDecision _honored({String name = 'Bagel + Jam'}) => PinDecision(
      usedPin: true,
      pinnedTemplateId: 'tpl-bagel',
      pinnedTemplateName: name,
      fallthroughReason: null,
      pinSetSize: 1,
    );

const _fallthroughNoScope = PinDecision(
  usedPin: false,
  pinnedTemplateId: null,
  pinnedTemplateName: null,
  fallthroughReason: PinFallthroughReason.noPinForScope,
  pinSetSize: 0,
);

BeforeSubPhase _sub(String type, {PinDecision? pin}) => BeforeSubPhase(
      subPhaseType: type,
      foodItems: const [],
      pinDecision: pin,
    );

PlanSection _beforeSection({required List<BeforeSubPhase> subs}) =>
    PlanSection(
      id: 'before_run',
      title: 'Before Run',
      foodItems: const [],
      subPhases: subs,
    );

PlanSection _duringSection({PinDecision? pin}) => PlanSection(
      id: 'during_run',
      title: 'During Run',
      foodItems: const [],
      pinDecision: pin,
    );

PlanSection _afterSection() => PlanSection(
      id: 'after_run',
      title: 'After Run',
      foodItems: const [],
    );

void main() {
  group('collectPinBannerRows — Hidden mode (no pinnable phases at all)', () {
    test('empty section list returns Hidden', () {
      final data = collectPinBannerRows(const []);
      expect(data.rows, isEmpty);
      expect(data.isOnboarding, isFalse);
      expect(data.shouldRender, isFalse);
    });

    test('plan with only an After section returns Hidden', () {
      // Pins don't apply to After. No pinnable phases → banner stays off.
      final data = collectPinBannerRows([_afterSection()]);
      expect(data.shouldRender, isFalse);
    });

    test(
        'Before section with only NON-pinnable sub-phases returns Hidden',
        () {
      // Forward-compat: a hypothetical "warmup" sub_phase that isn't
      // pinnable shouldn't trigger the banner.
      final data = collectPinBannerRows([
        _beforeSection(subs: [_sub('warmup')]),
      ]);
      expect(data.shouldRender, isFalse);
    });
  });

  group('collectPinBannerRows — Onboarding mode (zero pins, but pinnable)',
      () {
    test('plan with pinnable phases but zero PinDecisions returns Onboarding',
        () {
      // Zero-pin user case: the edge function omits pin_decision
      // everywhere when the user has no pins supplied at all. We still
      // want to surface the banner as a discovery prompt because the
      // user has activities where pins WOULD apply.
      final sections = [
        _beforeSection(subs: [_sub('meal'), _sub('snack'), _sub('top_up')]),
        _duringSection(),
      ];
      final data = collectPinBannerRows(sections);
      expect(data.isOnboarding, isTrue);
      expect(data.rows, isEmpty,
          reason: 'Onboarding mode shows no row list');
      expect(data.shouldRender, isTrue);
    });

    test('short workout with only a snack sub_phase still triggers onboarding',
        () {
      // Even one pinnable phase is enough to justify the prompt — the
      // user could pin a snack for this kind of activity.
      final sections = [
        _beforeSection(subs: [_sub('snack')]),
      ];
      final data = collectPinBannerRows(sections);
      expect(data.isOnboarding, isTrue);
      expect(data.rows, isEmpty);
    });

    test('plan with only a During section (no Before) → Onboarding', () {
      final data = collectPinBannerRows([_duringSection()]);
      expect(data.isOnboarding, isTrue);
      expect(data.rows, isEmpty);
    });
  });

  group('collectPinBannerRows — Status mode (pass-through real decisions)',
      () {
    test('emits one row per real decision, Before sub-phases then During', () {
      final mealPin = _honored(name: 'Bagel + Jam');
      final snackPin = _honored(name: 'OJ + Toast');
      final duringPin = _honored(name: 'Sports Drink');

      final sections = [
        _beforeSection(subs: [
          _sub('meal', pin: mealPin),
          _sub('snack', pin: snackPin),
          _sub('top_up', pin: _fallthroughNoScope),
        ]),
        _duringSection(pin: duringPin),
      ];

      final data = collectPinBannerRows(sections);

      expect(data.isOnboarding, isFalse);
      expect(data.rows.map((r) => r.label).toList(),
          ['Meal', 'Snack', 'Top-Off', 'During']);
      expect(data.rows[0].decision, same(mealPin));
      expect(data.rows[1].decision, same(snackPin));
      expect(data.rows[2].decision, same(_fallthroughNoScope));
      expect(data.rows[3].decision, same(duringPin));
    });
  });

  group('collectPinBannerRows — synthesis of missing pinnable rows', () {
    test(
        'scenario 4 case: Before snack honored, no During pin → '
        'synthesizes During row instead of skipping it', () {
      // Reproduces the smoke-test finding on 2026-05-24. The edge fn omits
      // pin_decision on the During section when pinsSupplied is false for
      // that scope; pre-fix the banner showed Meal/Snack/Top-Off only.
      final snackPin = _honored(name: 'OJ + Toast');
      final sections = [
        _beforeSection(subs: [
          _sub('meal', pin: _fallthroughNoScope),
          _sub('snack', pin: snackPin),
          _sub('top_up', pin: _fallthroughNoScope),
        ]),
        _duringSection(), // no pinDecision — synthesized
      ];

      final data = collectPinBannerRows(sections);

      expect(data.isOnboarding, isFalse);
      expect(data.rows.map((r) => r.label).toList(),
          ['Meal', 'Snack', 'Top-Off', 'During']);
      expect(data.rows.last.decision.usedPin, isFalse);
      expect(data.rows.last.decision.pinSetSize, 0);
      expect(data.rows.last.decision.fallthroughReason,
          PinFallthroughReason.noPinForScope);
    });

    test(
        'plan with only one real Before pin (snack) synthesizes the other '
        'three pinnable phases', () {
      final snackPin = _honored();
      final sections = [
        _beforeSection(subs: [
          _sub('meal'),
          _sub('snack', pin: snackPin),
          _sub('top_up'),
        ]),
        _duringSection(),
      ];

      final data = collectPinBannerRows(sections);

      expect(data.isOnboarding, isFalse);
      expect(data.rows.map((r) => r.label).toList(),
          ['Meal', 'Snack', 'Top-Off', 'During']);
      expect(data.rows[0].decision.usedPin, isFalse,
          reason: 'Meal synthesized — no real decision');
      expect(data.rows[1].decision, same(snackPin),
          reason: 'Snack real');
      expect(data.rows[2].decision.usedPin, isFalse,
          reason: 'Top-Off synthesized');
      expect(data.rows[3].decision.usedPin, isFalse,
          reason: 'During synthesized');
    });

    test('unknown sub_phase types are skipped (not synthesized)', () {
      // Forward-compat: if a future server introduces a new sub_phase type,
      // synthesis should ignore it rather than invent a row for it.
      final mealPin = _honored();
      final sections = [
        _beforeSection(subs: [
          _sub('meal', pin: mealPin),
          _sub('mystery_phase'), // unknown — should be ignored
        ]),
      ];

      final data = collectPinBannerRows(sections);

      expect(data.rows.map((r) => r.label).toList(), ['Meal']);
    });
  });

  group('collectPinBannerRows — non-pinnable sections excluded', () {
    test('After section is never synthesized', () {
      // Pins only fire on Before/During. An After section without a decision
      // must not get a synthesized row.
      final mealPin = _honored();
      final sections = [
        _beforeSection(subs: [_sub('meal', pin: mealPin)]),
        _afterSection(),
      ];

      final data = collectPinBannerRows(sections);

      expect(data.rows.map((r) => r.label).toList(), ['Meal']);
    });
  });

  group('collectPinBannerRows — section id aliases', () {
    test("section id 'during' (not 'during_run') is recognized as pinnable",
        () {
      // PinStatusBanner consumers join across both casings (the wire uses
      // 'during_run' but the persisted blob has been observed using 'during'
      // in some legacy paths — see _sectionLabel fallback for the same reason).
      final mealPin = _honored();
      final sections = [
        _beforeSection(subs: [_sub('meal', pin: mealPin)]),
        PlanSection(
          id: 'during',
          title: 'During',
          foodItems: const [],
        ),
      ];

      final data = collectPinBannerRows(sections);

      expect(data.rows.map((r) => r.label).toList(), ['Meal', 'During']);
    });
  });

  group('label helpers', () {
    test('subPhaseLabel maps known types to display strings', () {
      expect(subPhaseLabel('meal'), 'Meal');
      expect(subPhaseLabel('snack'), 'Snack');
      expect(subPhaseLabel('top_up'), 'Top-Off');
    });

    test('subPhaseLabel falls back to raw value for unknown types', () {
      expect(subPhaseLabel('elevenses'), 'elevenses');
    });

    test('sectionLabel maps known ids (both wire spellings) to display strings',
        () {
      expect(sectionLabel('before_run'), 'Before');
      expect(sectionLabel('before'), 'Before');
      expect(sectionLabel('during_run'), 'During');
      expect(sectionLabel('during'), 'During');
      expect(sectionLabel('after_run'), 'After');
      expect(sectionLabel('after'), 'After');
    });

    test('sectionLabel falls back to raw id for unknown ids', () {
      expect(sectionLabel('mystery'), 'mystery');
    });
  });
}
