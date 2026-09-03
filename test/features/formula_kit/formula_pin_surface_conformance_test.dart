// Design conformance — formula-pin surface (plan-detail banner + rows,
// library cards, detail DIETARY section, authoring save-time disclosure).
// SSOT: docs/ssot/spec/design/components/formula-pin-surface.md (RATIFIED
// Xuan, 2026-09-03); manifest:
// docs/ssot/conformance/design/formula-pin-surface.yaml
// (run via qa/conformance/run_dart.sh formula-pin-surface).
//
//   FP-2  — expanded banner rows derive strictly from the pin_decision wire
//           via the REAL pin_banner_rows_builder: an EPHEMERAL decision
//           renders NO pin row (the F-31 guard), except the audit-hardened
//           skipped-formulas carve-out; honored rows carry the formula name
//   FP-4a — conflicted pin tap mounts the INLINE in-card warning (never a
//           dialog): allergy = exact full copy + "Choose another" FILLED /
//           "Pin anyway" OUTLINE (R-01 option 1); diet = the softer
//           one-liner, no action pair (R-02 option 1), pin proceeds
//   FP-4b — honored conflicting pin carries the persistent COLLAPSIBLE
//           dragonfruit label; expanding shows the policy sentence + Keep
//           pin / Unpin; a profile-allergy change NEVER auto-unpins
//   FP-7  — detail DIETARY chips in human copy with the S-04 emphasis rule
//   FP-8  — authoring save-time disclosure above Save, exact closing
//           sentence; Save NEVER disabled (disclose-never-block, §1a)
//
// Goldens (one PNG per manifest row, stored at goldens/<id>.png):
//   fp_banner_collapsed_mixed · fp_banner_collapsed_none_applied ·
//   fp_banner_collapsed_invitation · fp_banner_expanded_rows ·
//   fp_conflict_label_collapsed
// FP-9 (Coach insight) is OUT of this bundle — never asserted, and no
// golden contains it (the editor golden path runs with
// coachInsightsEnabled: false).
//
// RULE: a golden may only be regenerated AFTER the design spec changes —
// never to make a red test pass. Regeneration commits cite the spec change.
//
//   flutter test test/features/formula_kit/formula_pin_surface_conformance_test.dart \
//     --update-goldens
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/src/internals.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/application/athlete_conflict_profile_provider.dart';
import 'package:mealvana_endurance/features/formula_kit/application/formula_editor_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/application/formula_pin_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_pin.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_profile_conflict.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_view.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/pin_decision.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/screens/formula_editor_screen.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/widgets/before_formula_card.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/widgets/dietary_section.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/widgets/pin_status_banner.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/plan_section.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/utils/pin_banner_rows_builder.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

// ── Fixtures ───────────────────────────────────────────────────────────────

const _glutenProfile = AthleteConflictProfile(allergyDbValues: ['gluten']);
const _ketoProfile = AthleteConflictProfile(dietDbValue: 'keto');

BeforeFormulaView _beforeFormula({
  String id = 'tpl-oats',
  List<String> allergens = const [],
  List<String> excludedDiets = const [],
}) => BeforeFormulaView(
  id: id,
  name: 'Oatmeal + Banana',
  subPhase: null,
  digestionSpeed: 'slow',
  templateType: 'food',
  componentDisplayStrings: const ['1 cup Oatmeal', '1 Banana'],
  allergens: allergens,
  excludedDiets: excludedDiets,
  totalCarbsG: 54,
  totalProteinG: 8,
  totalFatG: 4,
  totalSodiumMg: 120,
  totalFluidMl: 0,
  totalCalories: 280,
  timingWindow: '2-4 hours',
);

PinDecision _honored({String name = 'Bagel + Jam'}) => PinDecision(
  usedPin: true,
  pinnedTemplateId: 'tpl-bagel',
  pinnedTemplateName: name,
  fallthroughReason: null,
  pinSetSize: 1,
);

const _noPinForScope = PinDecision(
  usedPin: false,
  pinnedTemplateId: null,
  pinnedTemplateName: null,
  fallthroughReason: PinFallthroughReason.noPinForScope,
  pinSetSize: 0,
);

PinDecision _ephemeral({
  List<SkippedPersonalFormula> skipped = const [],
}) => PinDecision(
  usedPin: true,
  ephemeral: true,
  pinnedTemplateId: 'tpl-system',
  pinnedTemplateName: 'System Sports Drink',
  fallthroughReason: null,
  pinSetSize: 0,
  skippedPersonalFormulas: skipped,
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

// ── Test doubles (the real notifiers, minus the repositories) ──────────────

/// Extends the REAL [FormulaPinController]: the public toggle methods
/// (`toggleBefore` etc.) run unmodified; only [build] (Drift/Supabase
/// hydration) and [togglePin]'s persistence are stubbed with the same
/// optimistic set-flip, so every card write path exercises the real
/// notifier surface.
class _StubPinController extends FormulaPinController {
  _StubPinController({Set<String> initiallyPinned = const {}})
    : _initial = initiallyPinned;

  final Set<String> _initial;

  @override
  FutureOr<FormulaPinState> build() =>
      FormulaPinState(pinnedTemplateIds: _initial);

  @override
  Future<void> togglePin({
    required String templateId,
    required TemplateKind kind,
    required String source,
    String? subPhase,
    List<String>? activities,
    List<String>? durationBrackets,
    FormulaPhase? phaseOverride,
  }) async {
    final current = state.value ?? FormulaPinState.empty;
    final next = Set<String>.from(current.pinnedTemplateIds);
    if (!next.remove(templateId)) next.add(templateId);
    state = AsyncData(current.copyWith(pinnedTemplateIds: next));
  }
}

/// Editor controller pre-seeded with a draft; skips the repository read.
class _StubEditorController extends FormulaEditorController {
  _StubEditorController(this._draft);

  final FormulaDraft _draft;

  @override
  FutureOr<FormulaDraft> build(String? formulaId, FormulaPhase phase) =>
      _draft;
}

// ── Harness ────────────────────────────────────────────────────────────────

Widget _app(
  Widget child, {
  List<Override> overrides = const [],
  bool scroll = true,
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    home: Scaffold(
      body: scroll
          ? SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: child,
              ),
            )
          : child,
    ),
  ),
);

List<Override> _cardOverrides({
  AthleteConflictProfile Function()? profile,
  Set<String> pinned = const {},
}) => [
  formulaPinControllerProvider.overrideWith(
    () => _StubPinController(initiallyPinned: pinned),
  ),
  athleteConflictProfileProvider.overrideWith(
    (ref) async => profile?.call() ?? AthleteConflictProfile.empty,
  ),
];

Finder _pinToggle(String id) =>
    find.byKey(ValueKey('formula_kit.before_card_pin_$id'));

const _warningKey = ValueKey('formula_kit.pin_conflict_warning');
const _labelKey = ValueKey('formula_kit.pin_conflict_label');

const _glutenWarningCopy =
    'This formula contains gluten, which you\'ve listed as an allergy. '
    'Pinning it means Mealvana will always include it.';
const _policySentence =
    'Pins always win: this formula stays in your plans even though it '
    'conflicts with the profile you added later.';

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(BeforeFormulaCard)),
      listen: false,
    );

Future<void> _loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final path in paths) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(
      Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
    );
  }
  await loader.load();
}

/// Resolve a file inside a pub package via `.dart_tool/package_config.json`.
String? _packageFontPath(String package, String relative) {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;
  final match = RegExp(
    '"name":\\s*"$package",\\s*"rootUri":\\s*"([^"]+)"',
  ).firstMatch(config.readAsStringSync());
  if (match == null) return null;
  final root = Uri.parse(match.group(1)!);
  final dir = root.isAbsolute
      ? root.toFilePath()
      : Directory('.dart_tool').uri.resolveUri(root).toFilePath();
  final path = '$dir/$relative';
  return File(path).existsSync() ? path : null;
}

void main() {
  setUpAll(() async {
    await _loadFont('Sansita', [
      'assets/fonts/Sansita/Sansita-Regular.otf',
      'assets/fonts/Sansita/Sansita-Bold.ttf',
    ]);
    await _loadFont('Apercu', [
      'assets/fonts/Apercu/Apercu Pro Regular.otf',
      'assets/fonts/Apercu/Apercu Pro Medium.otf',
      'assets/fonts/Apercu/Apercu Pro Bold.otf',
    ]);
    final faSolid = _packageFontPath(
      'font_awesome_flutter',
      'lib/fonts/Font-Awesome-7-Free-Solid-900.otf',
    );
    if (faSolid != null) {
      await _loadFont('packages/font_awesome_flutter/FontAwesomeSolid', [
        faSolid,
      ]);
    }
    // The banner's ✓ / ⓘ / chevron glyphs are Material icons (FP-2 row
    // iconography) — without the face they golden as placeholder boxes.
    final flutterRoot = Platform.environment['FLUTTER_ROOT'];
    if (flutterRoot != null) {
      final materialIcons =
          '$flutterRoot/bin/cache/artifacts/material_fonts/'
          'MaterialIcons-Regular.otf';
      if (File(materialIcons).existsSync()) {
        await _loadFont('MaterialIcons', [materialIcons]);
      }
    }
  });

  group('FP-2 — rows derive strictly from the pin_decision wire', () {
    test('an ephemeral default-formula decision renders NO pin row '
        '(F-31 guard)', () {
      final data = collectPinBannerRows([
        _beforeSection(subs: [_sub('meal')]),
        _duringSection(pin: _ephemeral()),
      ]);
      expect(
        data.isOnboarding,
        isTrue,
        reason: 'ephemeral is not the user\'s pin — banner stays in the '
            'discovery state',
      );
      expect(data.rows, isEmpty);
    });

    test('ephemeral decision alongside a real pin synthesizes a no-pin row, '
        'never an honored one', () {
      final duringPin = _honored(name: 'Sports Drink Mix');
      final data = collectPinBannerRows([
        _duringSection(pin: duringPin),
        PlanSection(
          id: 'after_run',
          title: 'After Run',
          foodItems: const [],
          pinDecision: _ephemeral(),
        ),
      ]);
      expect(data.rows.map((r) => r.label).toList(), ['During', 'After']);
      expect(data.rows[0].decision, same(duringPin));
      expect(data.rows[1].decision.usedPin, isFalse);
    });

    test('audit-hardened carve-out: an ephemeral decision carrying '
        'skippedPersonalFormulas KEEPS its row', () {
      final carveOut = _ephemeral(
        skipped: const [
          SkippedPersonalFormula(
            id: 'pf-1',
            name: 'My race oats',
            reason: SkippedFormulaReason.durationOutOfScope,
          ),
        ],
      );
      final data = collectPinBannerRows([_duringSection(pin: carveOut)]);
      expect(data.isOnboarding, isFalse);
      expect(data.rows, hasLength(1));
      expect(data.rows.single.decision, same(carveOut));
      expect(data.rows.single.decision.hasSkippedFormulas, isTrue);
    });

    testWidgets('a non-ephemeral honored decision renders a row with the '
        'formula name in the expanded banner', (tester) async {
      final data = collectPinBannerRows([
        _beforeSection(subs: [_sub('meal', pin: _honored())]),
        _duringSection(),
      ]);
      await tester.pumpWidget(
        _app(
          PinStatusBanner(rows: data.rows, isOnboarding: data.isOnboarding),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('pin_status_banner.header')));
      await tester.pumpAndSettle();
      expect(find.text('Bagel + Jam'), findsOneWidget);
      expect(find.text('No pin found'), findsOneWidget);
      expect(find.text('Pin your favorite formula'), findsOneWidget);
    });
  });

  group('FP-4a — inline pre-pin warning at the decision moment', () {
    testWidgets('allergy conflict: tapping pin mounts the in-card warning '
        'with exact copy, filled/outline emphasis, and no dialog', (
      tester,
    ) async {
      final formula = _beforeFormula(allergens: const ['gluten']);
      await tester.pumpWidget(
        _app(
          BeforeFormulaCard(formula: formula, onTap: () {}),
          overrides: _cardOverrides(profile: () => _glutenProfile),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_pinToggle(formula.id));
      await tester.pumpAndSettle();

      // Exact ratified copy, mounted INSIDE the card — never a modal.
      expect(find.text(_glutenWarningCopy), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(BeforeFormulaCard),
          matching: find.byKey(_warningKey),
        ),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);

      // R-01 option 1: "Choose another" is the FILLED primary
      // (KylePrimaryButton → ElevatedButton); "Pin anyway" the OUTLINE
      // (KyleSecondaryButton → OutlinedButton).
      expect(
        find.widgetWithText(ElevatedButton, 'Choose another'),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'Pin anyway'), findsOneWidget);

      // The pin did NOT complete at the warning stage.
      final container = _containerOf(tester);
      expect(
        container
            .read(formulaPinControllerProvider)
            .value!
            .pinnedTemplateIds,
        isEmpty,
      );
    });

    testWidgets('"Pin anyway" completes the pin; "Choose another" dismisses '
        'without pinning', (tester) async {
      final formula = _beforeFormula(allergens: const ['gluten']);
      await tester.pumpWidget(
        _app(
          BeforeFormulaCard(formula: formula, onTap: () {}),
          overrides: _cardOverrides(profile: () => _glutenProfile),
        ),
      );
      await tester.pumpAndSettle();

      // Choose another → dismissed, not pinned.
      await tester.tap(_pinToggle(formula.id));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('formula_kit.pin_conflict_choose_another')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_warningKey), findsNothing);
      final container = _containerOf(tester);
      expect(
        container
            .read(formulaPinControllerProvider)
            .value!
            .pinnedTemplateIds,
        isEmpty,
      );

      // Pin anyway → honored (and the FP-4b label takes over).
      await tester.tap(_pinToggle(formula.id));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('formula_kit.pin_conflict_pin_anyway')),
      );
      await tester.pumpAndSettle();
      expect(
        container
            .read(formulaPinControllerProvider)
            .value!
            .pinnedTemplateIds,
        contains(formula.id),
      );
      expect(find.byKey(_warningKey), findsNothing);
      expect(find.byKey(_labelKey), findsOneWidget);
    });

    testWidgets('diet conflict: the softer one-liner, no action pair, and '
        'the pin proceeds (R-02 option 1)', (tester) async {
      final formula = _beforeFormula(excludedDiets: const ['keto']);
      await tester.pumpWidget(
        _app(
          BeforeFormulaCard(formula: formula, onTap: () {}),
          overrides: _cardOverrides(profile: () => _ketoProfile),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_pinToggle(formula.id));
      await tester.pumpAndSettle();

      expect(find.text('Doesn\'t match your keto preference.'), findsOneWidget);
      // No interrupting action pair.
      expect(find.byKey(_warningKey), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Choose another'),
          findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Pin anyway'), findsNothing);
      // The pin proceeded.
      final container = _containerOf(tester);
      expect(
        container
            .read(formulaPinControllerProvider)
            .value!
            .pinnedTemplateIds,
        contains(formula.id),
      );
    });
  });

  group('FP-4b — persistent collapsible conflict label', () {
    testWidgets('honored conflicting pin renders the collapsed dragonfruit '
        'label; expanding shows the policy sentence + Keep pin / Unpin', (
      tester,
    ) async {
      final formula = _beforeFormula(allergens: const ['gluten']);
      await tester.pumpWidget(
        _app(
          BeforeFormulaCard(formula: formula, onTap: () {}),
          overrides: _cardOverrides(
            profile: () => _glutenProfile,
            pinned: {formula.id},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_labelKey), findsOneWidget);
      final collapsed = tester.widget<Text>(
        find.text('Pinned despite your gluten allergy'),
      );
      expect(collapsed.style?.color, AppColors.dragonfruit);
      // The pin glyph carries the conflict dot.
      expect(
        find.byKey(const ValueKey('formula_kit.pin_conflict_dot')),
        findsOneWidget,
      );
      expect(find.text(_policySentence), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('formula_kit.pin_conflict_label_header')),
      );
      await tester.pumpAndSettle();
      expect(find.text(_policySentence), findsOneWidget);
      expect(find.text('Keep pin'), findsOneWidget);
      expect(find.text('Unpin'), findsOneWidget);
    });

    testWidgets('a profile-allergy change labels the pin but NEVER unpins it '
        '(label is presentation only)', (tester) async {
      final formula = _beforeFormula(allergens: const ['gluten']);
      var profile = AthleteConflictProfile.empty;
      await tester.pumpWidget(
        _app(
          BeforeFormulaCard(formula: formula, onTap: () {}),
          overrides: _cardOverrides(
            profile: () => profile,
            pinned: {formula.id},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No conflict yet: pinned, no label.
      expect(find.byKey(_labelKey), findsNothing);
      final container = _containerOf(tester);
      expect(
        container
            .read(formulaPinControllerProvider)
            .value!
            .pinnedTemplateIds,
        contains(formula.id),
      );

      // The athlete adds a gluten allergy AFTER pinning.
      profile = _glutenProfile;
      container.invalidate(athleteConflictProfileProvider);
      await tester.pumpAndSettle();

      // The label appears — and the pin, read through the real controller
      // state, is untouched.
      expect(find.byKey(_labelKey), findsOneWidget);
      expect(find.text('Pinned despite your gluten allergy'), findsOneWidget);
      expect(
        container
            .read(formulaPinControllerProvider)
            .value!
            .pinnedTemplateIds,
        contains(formula.id),
      );
    });
  });

  group('FP-7 — detail DIETARY section, S-04 emphasis rule', () {
    testWidgets('personalized-emphasized / neutral allergen / neutral diet '
        'chips with exact human copy', (tester) async {
      await tester.pumpWidget(
        _app(
          const DietarySection(
            allergens: ['gluten', 'peanut'],
            excludedDiets: ['keto'],
            athleteAllergyDbValues: ['gluten'],
          ),
        ),
      );
      await tester.pump();

      // Allergen the athlete HAS: personalized + emphasized, dragonfruit.
      final personal = tester.widget<Text>(
        find.text('Contains gluten — your allergy'),
      );
      expect(personal.style?.color, AppColors.dragonfruit);
      expect(personal.style?.fontWeight, FontWeight.w700);

      // Allergen they do NOT have: neutral.
      final neutral = tester.widget<Text>(find.text('Contains peanut'));
      expect(neutral.style?.color, isNot(AppColors.dragonfruit));

      // Diet exclusion: neutral, capitalized diet name, no machine strings.
      final diet = tester.widget<Text>(find.text('Not Keto'));
      expect(diet.style?.color, isNot(AppColors.dragonfruit));
      expect(find.textContaining('gluten_free'), findsNothing);
      expect(find.textContaining('keto', findRichText: true), findsNothing);
    });
  });

  group('FP-8 — authoring save-time disclosure, Save never disabled', () {
    FormulaDraft draft(Map<String, dynamic> component) => FormulaDraft(
      name: 'Race-day bagel',
      phase: FormulaPhase.before,
      subPhase: 'full_meal',
      components: [component],
    );

    Map<String, dynamic> component({
      List<String> allergens = const [],
      List<String> excludedDiets = const [],
    }) => <String, dynamic>{
      'food_id': 'food-1',
      'food_name': 'Wheat bagel',
      'quantity': 1.0,
      'serving_unit': 'bagel',
      'source': 'template',
      'carbs_per_serving': 48.0,
      'protein_per_serving': 9.0,
      'fat_per_serving': 1.5,
      'sodium_mg': 430.0,
      'fluid_ml_per_serving': 0.0,
      'calories_per_serving': 245.0,
      'allergens': allergens,
      'excluded_diets': excludedDiets,
    };

    Future<void> pumpEditor(
      WidgetTester tester, {
      required FormulaDraft seeded,
      required AthleteConflictProfile profile,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            formulaEditorControllerProvider(
              null,
              FormulaPhase.before,
            ).overrideWith(() => _StubEditorController(seeded)),
            athleteConflictProfileProvider.overrideWith((ref) async => profile),
            // FP-9: Coach insight is out of this bundle — keep it off.
            appConfigProvider.overrideWithValue(
              AppConfig.forTesting(coachInsightsEnabled: false),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            home: const FormulaEditorScreen(
              formulaId: null,
              phase: FormulaPhase.before,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('allergy-conflicting component renders the full disclosure '
        'with the exact closing sentence, above an ENABLED Save', (
      tester,
    ) async {
      await pumpEditor(
        tester,
        seeded: draft(component(allergens: const ['gluten'])),
        profile: _glutenProfile,
      );

      expect(
        find.text(
          '“Wheat bagel” contains gluten, which you\'ve listed as an '
          'allergy. You can still save — Mealvana will always include your '
          'own formulas.',
        ),
        findsOneWidget,
      );

      // Save is NEVER disabled by a conflict (disclose-never-block, §1a).
      final saveButton = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(const ValueKey('formula_kit.editor_save')),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(saveButton.onPressed, isNotNull);
      // FP-9: no Coach insight anywhere on this surface.
      expect(find.textContaining('Coach insight'), findsNothing);
    });

    testWidgets('diet-conflicting component renders the softer one-liner; '
        'Save stays enabled', (tester) async {
      await pumpEditor(
        tester,
        seeded: draft(component(excludedDiets: const ['keto'])),
        profile: _ketoProfile,
      );

      expect(find.text('Doesn\'t match your keto preference.'), findsOneWidget);
      final saveButton = tester.widget<ElevatedButton>(
        find.descendant(
          of: find.byKey(const ValueKey('formula_kit.editor_save')),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(saveButton.onPressed, isNotNull);
    });
  });

  // ── Goldens ──────────────────────────────────────────────────────────────

  group('goldens', () {
    Future<void> golden(
      WidgetTester tester,
      Widget app,
      String name, {
      double height = 400,
    }) async {
      tester.view.physicalSize = Size(428, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/$name.png'),
      );
    }

    // Rows for the mixed + expanded goldens come from the REAL builder over
    // wire-shaped sections (FP-2: never invented client-side).
    PinBannerData mixed() => collectPinBannerRows([
      _beforeSection(
        subs: [
          _sub('meal', pin: _honored(name: 'Oatmeal + Banana')),
          _sub('snack', pin: _noPinForScope),
        ],
      ),
      _duringSection(),
    ]);

    testWidgets('fp_banner_collapsed_mixed', (tester) async {
      final data = mixed();
      await golden(
        tester,
        _app(
          PinStatusBanner(rows: data.rows, isOnboarding: data.isOnboarding),
        ),
        'fp_banner_collapsed_mixed',
        height: 220,
      );
    });

    testWidgets('fp_banner_collapsed_none_applied', (tester) async {
      final data = collectPinBannerRows([
        _beforeSection(subs: [_sub('meal', pin: _noPinForScope)]),
        _duringSection(),
      ]);
      await golden(
        tester,
        _app(
          PinStatusBanner(rows: data.rows, isOnboarding: data.isOnboarding),
        ),
        'fp_banner_collapsed_none_applied',
        height: 220,
      );
    });

    testWidgets('fp_banner_collapsed_invitation', (tester) async {
      // Zero pins anywhere → the discovery invitation state.
      final data = collectPinBannerRows([
        _beforeSection(subs: [_sub('meal'), _sub('snack')]),
        _duringSection(),
      ]);
      await golden(
        tester,
        _app(
          PinStatusBanner(rows: data.rows, isOnboarding: data.isOnboarding),
        ),
        'fp_banner_collapsed_invitation',
        height: 200,
      );
    });

    testWidgets('fp_banner_expanded_rows', (tester) async {
      final data = mixed();
      tester.view.physicalSize = const Size(428, 520);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          PinStatusBanner(rows: data.rows, isOnboarding: data.isOnboarding),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('pin_status_banner.header')));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/fp_banner_expanded_rows.png'),
      );
    });

    testWidgets('fp_conflict_label_collapsed', (tester) async {
      final formula = _beforeFormula(allergens: const ['gluten']);
      await golden(
        tester,
        _app(
          BeforeFormulaCard(formula: formula, onTap: () {}),
          overrides: _cardOverrides(
            profile: () => _glutenProfile,
            pinned: {formula.id},
          ),
        ),
        'fp_conflict_label_collapsed',
        height: 360,
      );
    });
  });
}
