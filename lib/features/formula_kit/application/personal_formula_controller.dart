import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/services/app_external_deps.dart';
import '../../auth/data/user_repository.dart';
import '../data/personal_formulas_repository.dart';
import '../domain/formula_phase.dart';
import '../domain/formula_view.dart';
import '../domain/personal_formula.dart';

part 'personal_formula_controller.g.dart';

/// Owns the current user's saved personal formulas (the "Make this mine"
/// forks). [build] loads them — with an on-demand sync gate so a fresh install
/// pulls from Supabase before reading — and the mutation methods persist via
/// [PersonalFormulasRepository] then refresh state.
///
/// PR 5a wires the Before save path. The list this exposes powers the "Your
/// Formulas" library section (PR 5b) and During saves (PR 5c).
///
/// keepAlive: this is the session-scoped owner of the user's saved formulas,
/// mutated via transient `ref.read(...notifier)` calls from detail screens that
/// only read (never watch) it. Under the default autoDispose, the provider had
/// no listeners during a save and was disposed mid-flight, so the post-`await`
/// `ref.read` / `state =` calls threw "Ref ... used after it was disposed".
@Riverpod(keepAlive: true)
class PersonalFormulaController extends _$PersonalFormulaController {
  static const _uuid = Uuid();

  @override
  FutureOr<List<PersonalFormula>> build() async {
    final userId = await _currentUserId();
    if (userId == null) return const [];

    final repo = ref.read(personalFormulasRepositoryProvider);

    // On-demand sync gate (mirrors FormulaPinController): an empty local cache
    // is ambiguous on a fresh install, so pull from Supabase before reading.
    if (await repo.isStale()) {
      await repo.syncFromRemote(userId);
    }

    return repo.getForUser(userId);
  }

  /// Persist the Before edit-state [draft] as a personal formula forked from
  /// [source]. Recomputes macro totals from the edited components, writes
  /// local-first (dirty), and refreshes state. Returns the saved formula, or
  /// null if there is no authenticated user.
  Future<PersonalFormula?> saveBeforeEdit({
    required BeforeFormulaView source,
    required List<BeforeComponent> draft,
    String? name,
  }) async {
    final previous = state;

    // Everything fallible — resolving the user, reading the repo, building the
    // formula, and the Drift write/read — runs inside the guard. Anything that
    // throws becomes an AsyncError here rather than escaping to the caller,
    // which is what previously stranded the Save spinner.
    PersonalFormula? saved;
    final result = await AsyncValue.guard(() async {
      final userId = await _currentUserId();
      if (userId == null) {
        // No authenticated user: not an error, just nothing to save. Keep the
        // prior list and leave [saved] null so the caller gets null back.
        return previous.asData?.value ?? const <PersonalFormula>[];
      }

      final repo = ref.read(personalFormulasRepositoryProvider);
      final components =
          draft.map(PersonalFormulaComponent.fromBeforeComponent).toList();
      final totals = _Totals.fromComponents(components);
      final now = DateTime.now();

      final formula = PersonalFormula(
        id: _uuid.v4(),
        userId: userId,
        name: (name == null || name.trim().isEmpty) ? source.name : name.trim(),
        phase: FormulaPhase.before,
        sourceTemplateId: source.id,
        subPhase: source.subPhase,
        digestionSpeed: source.digestionSpeed,
        templateType: source.templateType,
        components: components,
        totalCarbsG: totals.carbs,
        totalProteinG: totals.protein,
        totalFatG: totals.fat,
        totalSodiumMg: totals.sodiumMg,
        totalFluidMl: totals.fluidMl,
        totalCalories: totals.calories,
        createdAt: now,
        updatedAt: now,
      );

      await repo.save(formula);
      saved = formula;
      return repo.getForUser(userId);
    });

    if (result.hasError) {
      // Surface the failure to the caller but keep the prior list visible.
      state = previous;
      ref.read(appExternalDepsProvider).logger.error(
            'Failed to save personal formula: ${result.error}',
            context: 'FORMULA_KIT',
            error: result.error,
            stackTrace: result.stackTrace,
            data: {'error': result.error.toString()},
          );
      return null;
    }

    state = result;
    // [saved] is null only on the no-user path; otherwise it's the saved row.
    return saved;
  }

  /// Soft-delete a saved personal formula and refresh state.
  Future<void> delete(String id) async {
    final userId = await _currentUserId();
    if (userId == null) return;
    final repo = ref.read(personalFormulasRepositoryProvider);
    state = await AsyncValue.guard(() async {
      await repo.deleteFormula(userId: userId, id: id);
      return repo.getForUser(userId);
    });
  }

  Future<String?> _currentUserId() async {
    final userRepo = await ref.read(userRepositoryProvider.future);
    final user = await userRepo.getCurrentUser();
    return user?.id;
  }
}

/// Aggregated macro totals over a set of components. Macros are per-serving,
/// scaled by each component's quantity. Calories follow the canonical
/// 4/4/9 formula (carbs*4 + protein*4 + fat*9).
class _Totals {
  const _Totals({
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.sodiumMg,
    required this.fluidMl,
    required this.calories,
  });

  final double carbs;
  final double protein;
  final double fat;
  final double sodiumMg;
  final double fluidMl;
  final int calories;

  factory _Totals.fromComponents(List<PersonalFormulaComponent> components) {
    var carbs = 0.0;
    var protein = 0.0;
    var fat = 0.0;
    var sodiumMg = 0.0;
    var fluidMl = 0.0;
    for (final c in components) {
      carbs += c.carbsPerServing * c.quantity;
      protein += c.proteinPerServing * c.quantity;
      fat += c.fatPerServing * c.quantity;
      sodiumMg += c.sodiumMgPerServing * c.quantity;
      fluidMl += c.fluidMlPerServing * c.quantity;
    }
    final calories = (carbs * 4 + protein * 4 + fat * 9).round();
    return _Totals(
      carbs: carbs,
      protein: protein,
      fat: fat,
      sodiumMg: sodiumMg,
      fluidMl: fluidMl,
      calories: calories,
    );
  }
}
