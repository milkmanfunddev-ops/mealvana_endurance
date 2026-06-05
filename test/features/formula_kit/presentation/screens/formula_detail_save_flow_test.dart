import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/application/formula_library_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/application/personal_formula_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/before_sub_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_filter_state.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_view.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/personal_formula.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/screens/formula_detail_screen.dart';

// PR 5a verification — the "Make this mine" Save flow on the Before detail
// screen. The persistence/serialization invariants live in the domain +
// repository suites; this drives the UI orchestration that wires them:
//
//   - tapping Save shows a spinner while the save is in flight (no double-tap),
//   - a successful save → success snackbar + exit edit mode,
//   - a failed save (controller returns null) → error snackbar + STAY in edit
//     mode so the user's draft isn't lost.
//
// Both controllers are stubbed via build() overrides so the screen renders off
// fixed state without touching Drift/Supabase. The analytics methods are
// overridden to no-ops to avoid needing the analytics provider.

const _formulaId = 'tpl-before-1';

BeforeComponent _component() {
  return const BeforeComponent(
    foodKey: 'medjool_dates',
    displayName: 'Medjool Dates',
    displayNamePlural: 'Medjool Dates',
    servingUnit: null,
    quantity: 2,
    carbsPerServing: 18,
    proteinPerServing: 0.4,
    fatPerServing: 0.1,
    sodiumMgPerServing: 0,
    fluidMlPerServing: 0,
  );
}

BeforeFormulaView _view() {
  return BeforeFormulaView(
    id: _formulaId,
    name: 'Dates Snack',
    subPhase: BeforeSubPhase.snack,
    digestionSpeed: 'fast',
    templateType: 'food',
    componentDisplayStrings: const ['2 Medjool Dates'],
    components: [_component()],
    allergens: const [],
    excludedDiets: const [],
    totalCarbsG: 36,
    totalProteinG: 0.8,
    totalFatG: 0.2,
    totalSodiumMg: 0,
    totalFluidMl: 0,
    totalCalories: 149,
    timingWindow: '30-90 min',
  );
}

FormulaLibraryState _libraryState() {
  return FormulaLibraryState(
    filter: const FormulaFilterState(),
    beforeFormulas: [_view()],
    duringFormulas: const [],
    afterFormulas: const [],
    userDiets: const [],
    userAllergies: const [],
  );
}

PersonalFormula _savedFormula() {
  final now = DateTime.utc(2026, 6, 1, 12);
  return PersonalFormula(
    id: 'pf-saved',
    userId: 'user-abc',
    name: 'Dates Snack',
    phase: FormulaPhase.before,
    sourceTemplateId: _formulaId,
    components: [PersonalFormulaComponent.fromBeforeComponent(_component())],
    totalCarbsG: 36,
    totalProteinG: 0.8,
    totalFatG: 0.2,
    totalSodiumMg: 0,
    totalFluidMl: 0,
    totalCalories: 149,
    createdAt: now,
    updatedAt: now,
  );
}

/// Renders off fixed [FormulaLibraryState]; analytics fire-and-forget calls are
/// overridden to no-ops so no analytics provider is required.
class _StubLibraryController extends FormulaLibraryController {
  _StubLibraryController(this._state);

  final FormulaLibraryState _state;

  @override
  FutureOr<FormulaLibraryState> build() async => _state;

  @override
  Future<void> trackDetailViewed({
    required String templateId,
    required FormulaPhase phase,
    required bool isPersonal,
  }) async {}

  @override
  Future<void> trackMakeThisMineTapped({
    required String templateId,
    required FormulaPhase phase,
  }) async {}

  @override
  Future<void> trackPersonalFormulaSaved({
    required FormulaPhase phase,
    required int componentCount,
    required int editDurationSec,
    String provenance = 'forked_formula',
  }) async {}

  @override
  Future<void> trackPersonalFormulaEditCancelled({
    required FormulaPhase phase,
  }) async {}
}

/// [saveBeforeEdit] returns whatever [_onSave] yields, letting each test drive
/// success (a formula), failure (null), or an in-flight (uncompleted) save.
class _StubPersonalFormulaController extends PersonalFormulaController {
  _StubPersonalFormulaController(this._onSave);

  final Future<PersonalFormula?> Function() _onSave;

  @override
  FutureOr<List<PersonalFormula>> build() async => const [];

  @override
  Future<PersonalFormula?> saveBeforeEdit({
    required BeforeFormulaView source,
    required List<BeforeComponent> draft,
    String? name,
  }) {
    return _onSave();
  }
}

Widget _wrap({required Future<PersonalFormula?> Function() onSave}) {
  return ProviderScope(
    overrides: [
      formulaLibraryControllerProvider.overrideWith(
        () => _StubLibraryController(_libraryState()),
      ),
      personalFormulaControllerProvider.overrideWith(
        () => _StubPersonalFormulaController(onSave),
      ),
    ],
    child: const MaterialApp(
      home: FormulaDetailScreen(id: _formulaId, phase: FormulaPhase.before),
    ),
  );
}

Finder _saveButton() => find.byKey(const ValueKey('formula_kit.edit_save'));
Finder _makeThisMine() =>
    find.byKey(const ValueKey('formula_kit.make_this_mine'));

/// Build the screen, settle the async controller, then enter edit mode.
Future<void> _enterEditMode(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.tap(_makeThisMine());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Save shows an in-flight spinner and blocks while saving',
      (tester) async {
    final gate = Completer<PersonalFormula?>();
    await tester.pumpWidget(_wrap(onSave: () => gate.future));
    await _enterEditMode(tester);

    // Tap Save — the stub future is held open by [gate].
    await tester.tap(_saveButton());
    await tester.pump();

    // Spinner replaces the "Save" label while the save is in flight.
    expect(
      find.descendant(
        of: _saveButton(),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _saveButton(), matching: find.text('Save')),
      findsNothing,
    );

    // Release the save so the pending future/timer doesn't leak.
    gate.complete(_savedFormula());
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('successful save shows the success snackbar and exits edit mode',
      (tester) async {
    await tester.pumpWidget(_wrap(onSave: () async => _savedFormula()));
    await _enterEditMode(tester);

    expect(_saveButton(), findsOneWidget);

    await tester.tap(_saveButton());
    await tester.pump(); // _saving = true
    await tester.pump(); // save resolves
    await tester.pump(const Duration(milliseconds: 800)); // snackbar in

    expect(find.text('Saved to your formulas'), findsOneWidget);
    // Edit mode exited → the Save pill is gone, "Make this mine" is back.
    expect(_saveButton(), findsNothing);
    expect(_makeThisMine(), findsOneWidget);

    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('failed save shows the error snackbar and stays in edit mode',
      (tester) async {
    await tester.pumpWidget(_wrap(onSave: () async => null));
    await _enterEditMode(tester);

    await tester.tap(_saveButton());
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      find.text("Couldn't save your formula. Please try again."),
      findsOneWidget,
    );
    // Draft must be preserved → still in edit mode, Save pill still present.
    expect(_saveButton(), findsOneWidget);
    expect(_makeThisMine(), findsNothing);

    await tester.pumpAndSettle(const Duration(seconds: 4));
  });

  testWidgets('a thrown save never strands the spinner (regression)',
      (tester) async {
    // Before the fix, an exception escaping saveBeforeEdit left `_saving=true`
    // forever — the Save pill spun with no feedback. The finally must reset it
    // and surface the error snackbar.
    await tester.pumpWidget(
      _wrap(onSave: () async => throw Exception('boom')),
    );
    await _enterEditMode(tester);

    await tester.tap(_saveButton());
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(
      find.text("Couldn't save your formula. Please try again."),
      findsOneWidget,
    );
    // Spinner cleared (the pill shows "Save" again, no progress indicator) and
    // we stayed in edit mode so the draft isn't lost.
    expect(
      find.descendant(
        of: _saveButton(),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
    expect(find.descendant(of: _saveButton(), matching: find.text('Save')),
        findsOneWidget);
    expect(_makeThisMine(), findsNothing);

    await tester.pumpAndSettle(const Duration(seconds: 4));
  });
}
