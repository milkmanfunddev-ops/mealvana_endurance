/// A lapsed account cannot write personal formulas or pins (mp-457 §4,
/// mp-491, ticket 12).
///
/// Through the real PersonalFormulasController, FormulaEditorController and
/// FormulaPinController: each write path asks the write guard first;
/// refused, it opens the paywall once and never constructs a repository, so
/// nothing is written or queued. The editor refuses before it delegates, so
/// the paywall opens once for a save, not twice.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/formula_kit/application/formula_editor_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/application/formula_pin_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/application/personal_formulas_controller.dart';
import 'package:mealvana_endurance/features/formula_kit/data/formula_pins_repository.dart';
import 'package:mealvana_endurance/features/formula_kit/data/personal_formulas_repository.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_pin.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_view.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/personal_formula.dart';

import '../../helpers/write_access.dart';

class _FakeFormula extends Fake implements PersonalFormula {}

class _FakeDraft extends Fake implements FormulaDraft {}

class _FakePinState extends Fake implements FormulaPinState {}

class _FakeBefore extends Fake implements BeforeFormulaView {}

class _FakeDuring extends Fake implements DuringFormulaView {}

class _FakeAfter extends Fake implements AfterFormulaView {}

class _SeededFormulas extends PersonalFormulasController {
  @override
  FutureOr<List<PersonalFormula>> build() => const [];
}

class _SeededEditor extends FormulaEditorController {
  @override
  FutureOr<FormulaDraft> build(String? formulaId, FormulaPhase phase) =>
      _FakeDraft();
}

class _SeededPins extends FormulaPinController {
  @override
  FutureOr<FormulaPinState> build() => _FakePinState();
}

void main() {
  late PaywallOpens opens;
  late ProviderContainer container;

  setUp(() {
    opens = PaywallOpens();
    container = ProviderContainer(
      overrides: [
        writesRefused(),
        opens.override,
        personalFormulasRepositoryProvider.overrideWith(
          untouched('personalFormulasRepository'),
        ),
        formulaPinsRepositoryProvider.overrideWith(
          untouched('formulaPinsRepository'),
        ),
        userRepositoryProvider.overrideWith(untouched('userRepository')),
        personalFormulasControllerProvider.overrideWith(_SeededFormulas.new),
        formulaEditorControllerProvider.overrideWith(_SeededEditor.new),
        formulaPinControllerProvider.overrideWith(_SeededPins.new),
      ],
    );
    addTearDown(container.dispose);
  });

  group('PersonalFormulasController, lapsed', () {
    PersonalFormulasController ctrl() =>
        container.read(personalFormulasControllerProvider.notifier);
    final paths = <String, Future<Object?> Function()>{
      'createFormula': () => ctrl().createFormula(_FakeFormula()),
      'updateFormula': () => ctrl().updateFormula(_FakeFormula()),
      'deleteFormula': () => ctrl().deleteFormula('f1'),
    };
    for (final entry in paths.entries) {
      test('${entry.key} opens the paywall and writes nothing', () async {
        await expectWriteRefused(opens, entry.value);
      });
    }
  });

  test('FormulaEditorController.save, lapsed: refused once', () async {
    final provider = formulaEditorControllerProvider(null, FormulaPhase.before);
    await container.read(provider.future);
    await expectWriteRefused(
      opens,
      () => container.read(provider.notifier).save(),
    );
  });

  group('FormulaPinController, lapsed', () {
    FormulaPinController ctrl() =>
        container.read(formulaPinControllerProvider.notifier);
    final paths = <String, Future<Object?> Function()>{
      'togglePin': () => ctrl().togglePin(
        templateId: 't1',
        kind: TemplateKind.preSystem,
        source: 'test',
      ),
      'toggleBefore': () =>
          ctrl().toggleBefore(formula: _FakeBefore(), source: 'test'),
      'toggleDuring': () =>
          ctrl().toggleDuring(formula: _FakeDuring(), source: 'test'),
      'toggleAfter': () =>
          ctrl().toggleAfter(formula: _FakeAfter(), source: 'test'),
      'togglePersonalFormula': () => ctrl().togglePersonalFormula(
        formulaId: 'f1',
        phase: FormulaPhase.before,
        source: 'test',
      ),
    };
    for (final entry in paths.entries) {
      test('${entry.key} opens the paywall and writes nothing', () async {
        await container.read(formulaPinControllerProvider.future);
        await expectWriteRefused(opens, entry.value);
      });
    }
  });
}
