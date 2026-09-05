import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/pin_decision.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/plan_section.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/utils/pin_banner_rows_builder.dart';

// Locks in the three-state synthesis rule for the activity-detail pin
// banner (Formula Kit PR 2 substep 11 polish; extended for After in PR 3
// substep 9). See `docs/features/formula-kit/PLAN.md` → "PinStatusBanner
// V1 polish".
//
// The rule, in short:
//   - If the plan has no pinnable phases at all (short walk, no
//     Before/During/After) → return Hidden. Banner stays off-screen.
//   - If the plan has pinnable phases but ZERO real PinDecisions →
//     return Onboarding. Banner becomes a discovery prompt for users
//     who haven't engaged with pins yet.
//   - Otherwise emit a row per pinnable phase present in the plan
//     (Status mode):
//       * Pinnable sub_phases (meal / snack / top_up) on Before sections
//       * The During section itself
//       * The After section itself
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

BeforeSubPhase _sub(String type, {PinDecision? pin}) =>
    BeforeSubPhase(subPhaseType: type, foodItems: const [], pinDecision: pin);

PlanSection _beforeSection({required List<BeforeSubPhase> subs}) => PlanSection(
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

PlanSection _afterSection({PinDecision? pin}) => PlanSection(
  id: 'after_run',
  title: 'After Run',
  foodItems: const [],
  pinDecision: pin,
);

void main() {
  group('collectPinBannerRows — Hidden mode (no pinnable phases at all)', () {
    test('empty section list returns Hidden', () {
      final data = collectPinBannerRows(const []);
      expect(data.rows, isEmpty);
      expect(data.isOnboarding, isFalse);
      expect(data.shouldRender, isFalse);
    });

    test('Before section with only NON-pinnable sub-phases returns Hidden', () {
      // Forward-compat: a hypothetical "warmup" sub_phase that isn't
      // pinnable shouldn't trigger the banner.
      final data = collectPinBannerRows([
        _beforeSection(subs: [_sub('warmup')]),
      ]);
      expect(data.shouldRender, isFalse);
    });
  });

  group('collectPinBannerRows — Onboarding mode (zero pins, but pinnable)', () {
    test(
      'plan with pinnable phases but zero PinDecisions returns Onboarding',
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
        expect(data.rows, isEmpty, reason: 'Onboarding mode shows no row list');
        expect(data.shouldRender, isTrue);
      },
    );

    test(
      'short workout with only a snack sub_phase still triggers onboarding',
      () {
        // Even one pinnable phase is enough to justify the prompt — the
        // user could pin a snack for this kind of activity.
        final sections = [
          _beforeSection(subs: [_sub('snack')]),
        ];
        final data = collectPinBannerRows(sections);
        expect(data.isOnboarding, isTrue);
        expect(data.rows, isEmpty);
      },
    );

    test('plan with only a During section (no Before) → Onboarding', () {
      final data = collectPinBannerRows([_duringSection()]);
      expect(data.isOnboarding, isTrue);
      expect(data.rows, isEmpty);
    });

    test('plan with only an After section → Onboarding', () {
      // After is pinnable in PR 3 substep 9. An After-only plan with no
      // real decision should now surface the discovery prompt rather than
      // stay hidden.
      final data = collectPinBannerRows([_afterSection()]);
      expect(data.isOnboarding, isTrue);
      expect(data.rows, isEmpty);
    });
  });

  group('collectPinBannerRows — Status mode (pass-through real decisions)', () {
    test('emits one row per real decision, Before sub-phases then During '
        'then After', () {
      final mealPin = _honored(name: 'Bagel + Jam');
      final snackPin = _honored(name: 'OJ + Toast');
      final duringPin = _honored(name: 'Sports Drink');
      final afterPin = _honored(name: 'Chocolate Milk');

      final sections = [
        _beforeSection(
          subs: [
            _sub('meal', pin: mealPin),
            _sub('snack', pin: snackPin),
            _sub('top_up', pin: _fallthroughNoScope),
          ],
        ),
        _duringSection(pin: duringPin),
        _afterSection(pin: afterPin),
      ];

      final data = collectPinBannerRows(sections);

      expect(data.isOnboarding, isFalse);
      expect(data.rows.map((r) => r.label).toList(), [
        'Meal',
        'Snack',
        'Top-Off',
        'During',
        'After',
      ]);
      expect(data.rows[0].decision, same(mealPin));
      expect(data.rows[1].decision, same(snackPin));
      expect(data.rows[2].decision, same(_fallthroughNoScope));
      expect(data.rows[3].decision, same(duringPin));
      expect(data.rows[4].decision, same(afterPin));
    });
  });

  group('collectPinBannerRows — ephemeral decisions are invisible', () {
    // The server-side default-formula safety net emits pin_decisions with
    // `ephemeral: true` on plans for users who have NOT pinned anything.
    // These must NOT flip the banner into Status mode ("Using your pinned
    // formulas") — an unpinned user should still see the Onboarding
    // discovery prompt. Formula-first flip, 2026-07-03.
    PinDecision ephemeral({String name = 'System Sports Drink'}) => PinDecision(
      usedPin: true,
      ephemeral: true,
      pinnedTemplateId: 'tpl-system',
      pinnedTemplateName: name,
      fallthroughReason: null,
      pinSetSize: 0,
    );

    test('ephemeral-only during decision → Onboarding (not Status)', () {
      final sections = [
        _beforeSection(subs: [_sub('meal')]),
        _duringSection(pin: ephemeral()),
      ];

      final data = collectPinBannerRows(sections);

      expect(data.isOnboarding, isTrue);
      expect(data.rows, isEmpty);
    });

    test('ephemeral after decision alongside a real during pin → real pin '
        'shows, ephemeral row is synthesized as no-pin', () {
      final duringPin = _honored(name: 'Bagel + Jam');
      final sections = [
        _duringSection(pin: duringPin),
        _afterSection(pin: ephemeral(name: 'System Recovery')),
      ];

      final data = collectPinBannerRows(sections);

      expect(data.isOnboarding, isFalse);
      expect(data.rows.map((r) => r.label).toList(), ['During', 'After']);
      // During = the real pin; After = synthesized no-pin (ephemeral hidden).
      expect(data.rows[0].decision, same(duringPin));
      expect(data.rows[1].decision.usedPin, isFalse);
      expect(data.rows[1].decision.ephemeral, isFalse);
    });
  });

  group('collectPinBannerRows — synthesis of missing pinnable rows', () {
    test('scenario 4 case: Before snack honored, no During pin → '
        'synthesizes During row instead of skipping it', () {
      // Reproduces the smoke-test finding on 2026-05-24. The edge fn omits
      // pin_decision on the During section when pinsSupplied is false for
      // that scope; pre-fix the banner showed Meal/Snack/Top-Off only.
      final snackPin = _honored(name: 'OJ + Toast');
      final sections = [
        _beforeSection(
          subs: [
            _sub('meal', pin: _fallthroughNoScope),
            _sub('snack', pin: snackPin),
            _sub('top_up', pin: _fallthroughNoScope),
          ],
        ),
        _duringSection(), // no pinDecision — synthesized
      ];

      final data = collectPinBannerRows(sections);

      expect(data.isOnboarding, isFalse);
      expect(data.rows.map((r) => r.label).toList(), [
        'Meal',
        'Snack',
        'Top-Off',
        'During',
      ]);
      expect(data.rows.last.decision.usedPin, isFalse);
      expect(data.rows.last.decision.pinSetSize, 0);
      expect(
        data.rows.last.decision.fallthroughReason,
        PinFallthroughReason.noPinForScope,
      );
    });

    test('plan with only one real Before pin (snack) synthesizes the other '
        'four pinnable phases', () {
      final snackPin = _honored();
      final sections = [
        _beforeSection(
          subs: [
            _sub('meal'),
            _sub('snack', pin: snackPin),
            _sub('top_up'),
          ],
        ),
        _duringSection(),
        _afterSection(),
      ];

      final data = collectPinBannerRows(sections);

      expect(data.isOnboarding, isFalse);
      expect(data.rows.map((r) => r.label).toList(), [
        'Meal',
        'Snack',
        'Top-Off',
        'During',
        'After',
      ]);
      expect(
        data.rows[0].decision.usedPin,
        isFalse,
        reason: 'Meal synthesized — no real decision',
      );
      expect(data.rows[1].decision, same(snackPin), reason: 'Snack real');
      expect(
        data.rows[2].decision.usedPin,
        isFalse,
        reason: 'Top-Off synthesized',
      );
      expect(
        data.rows[3].decision.usedPin,
        isFalse,
        reason: 'During synthesized',
      );
      expect(
        data.rows[4].decision.usedPin,
        isFalse,
        reason: 'After synthesized',
      );
    });

    test('After section with real decision renders, missing During gets '
        'synthesized between Before and After', () {
      // Mirrors the scenario-4 synthesis case but in reverse: pin lives on
      // After, During is silent and must be filled in.
      final afterPin = _honored(name: 'Greek Yogurt + Berries');
      final sections = [
        _beforeSection(subs: [_sub('meal', pin: _fallthroughNoScope)]),
        _duringSection(),
        _afterSection(pin: afterPin),
      ];

      final data = collectPinBannerRows(sections);

      expect(data.isOnboarding, isFalse);
      expect(data.rows.map((r) => r.label).toList(), [
        'Meal',
        'During',
        'After',
      ]);
      expect(data.rows[1].decision.usedPin, isFalse);
      expect(
        data.rows[1].decision.fallthroughReason,
        PinFallthroughReason.noPinForScope,
      );
      expect(data.rows[2].decision, same(afterPin));
    });

    test('unknown sub_phase types are skipped (not synthesized)', () {
      // Forward-compat: if a future server introduces a new sub_phase type,
      // synthesis should ignore it rather than invent a row for it.
      final mealPin = _honored();
      final sections = [
        _beforeSection(
          subs: [
            _sub('meal', pin: mealPin),
            _sub('mystery_phase'), // unknown — should be ignored
          ],
        ),
      ];

      final data = collectPinBannerRows(sections);

      expect(data.rows.map((r) => r.label).toList(), ['Meal']);
    });
  });

  group('collectPinBannerRows — After section synthesis (PR 3 substep 9)', () {
    test('After section without a decision IS synthesized', () {
      // PR 3 substep 9: After is pinnable. An After section without a
      // decision must now get a synthesized "No pin found" row, matching
      // the During behavior.
      final mealPin = _honored();
      final sections = [
        _beforeSection(subs: [_sub('meal', pin: mealPin)]),
        _afterSection(),
      ];

      final data = collectPinBannerRows(sections);

      expect(data.rows.map((r) => r.label).toList(), ['Meal', 'After']);
      expect(data.rows[1].decision.usedPin, isFalse);
      expect(data.rows[1].decision.pinSetSize, 0);
      expect(
        data.rows[1].decision.fallthroughReason,
        PinFallthroughReason.noPinForScope,
      );
    });

    test("section id 'after' (not 'after_run') is recognized as pinnable", () {
      // Alias coverage parallel to the During alias test below.
      final mealPin = _honored();
      final sections = [
        _beforeSection(subs: [_sub('meal', pin: mealPin)]),
        PlanSection(id: 'after', title: 'After', foodItems: const []),
      ];

      final data = collectPinBannerRows(sections);

      expect(data.rows.map((r) => r.label).toList(), ['Meal', 'After']);
    });
  });

  group('collectPinBannerRows — section id aliases', () {
    test("section id 'during' (not 'during_run') is recognized as pinnable", () {
      // PinStatusBanner consumers join across both casings (the wire uses
      // 'during_run' but the persisted blob has been observed using 'during'
      // in some legacy paths — see _sectionLabel fallback for the same reason).
      final mealPin = _honored();
      final sections = [
        _beforeSection(subs: [_sub('meal', pin: mealPin)]),
        PlanSection(id: 'during', title: 'During', foodItems: const []),
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

    test(
      'sectionLabel maps known ids (both wire spellings) to display strings',
      () {
        expect(sectionLabel('before_run'), 'Before');
        expect(sectionLabel('before'), 'Before');
        expect(sectionLabel('during_run'), 'During');
        expect(sectionLabel('during'), 'During');
        expect(sectionLabel('after_run'), 'After');
        expect(sectionLabel('after'), 'After');
      },
    );

    test('sectionLabel falls back to raw id for unknown ids', () {
      expect(sectionLabel('mystery'), 'mystery');
    });
  });

  group('collectPinBannerRows — brick per-leg During sections', () {
    // A brick plan carries one During section per leg (during_segment_N).
    // Until 2026-09-04 those ids were unrecognized: a brick banner listed
    // only Snack/Top-Off/After and the athlete's During pins had no
    // on-screen trace (Xuan's Sept 5 RUN/BIKE/RUN brick — bug
    // 2026-09-04-brick-during-pins-invisible-and-tri-scope-unreachable).
    PlanSection segment(
      int order,
      String sportName, {
      PinDecision? pin,
    }) => PlanSection(
      id: 'during_segment_$order',
      title: 'During $sportName',
      foodItems: const [],
      pinDecision: pin,
    );

    test('each leg gets its OWN row, labeled by the section title', () {
      final data = collectPinBannerRows([
        segment(1, 'Run', pin: _honored(name: 'Gel + Water')),
        segment(2, 'Bike', pin: _fallthroughNoScope),
        segment(3, 'Run'),
      ]);

      expect(data.isOnboarding, isFalse);
      expect(data.rows, hasLength(3));
      expect(data.rows[0].label, 'During Run');
      expect(data.rows[0].decision.usedPin, isTrue);
      expect(data.rows[1].label, 'During Bike');
      expect(data.rows[1].decision.usedPin, isFalse);
      // A decision-less leg still gets an honest synthetic row.
      expect(data.rows[2].label, 'During Run');
      expect(
        data.rows[2].decision.fallthroughReason,
        PinFallthroughReason.noPinForScope,
      );
    });

    test('brick segments count as pinnable phases for the onboarding state',
        () {
      // Segments alone, zero decisions anywhere, user has no pins → the
      // banner must offer discovery, not hide.
      final data = collectPinBannerRows([
        segment(1, 'Run'),
        segment(2, 'Bike'),
      ]);
      expect(data.isOnboarding, isTrue);
      expect(data.rows, isEmpty);
    });

    test('transition sections (T1/T2) stay non-pinnable', () {
      final data = collectPinBannerRows([
        PlanSection(id: 'T1', title: 'Transition (T1)', foodItems: const []),
        segment(1, 'Run', pin: _honored()),
      ]);
      expect(data.rows, hasLength(1));
      expect(data.rows.single.label, 'During Run');
    });
  });
}
