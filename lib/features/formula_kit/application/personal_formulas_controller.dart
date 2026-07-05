import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/app_external_deps.dart';
import '../../auth/data/user_repository.dart';
import '../data/personal_formulas_repository.dart';
import '../domain/formula_phase.dart';
import '../domain/personal_formula.dart';

part 'personal_formulas_controller.g.dart';

/// Owns the current user's "Your Formulas" list — user-authored personal
/// formulas from the `personal_formulas` table.
///
/// Mirrors [FormulaPinController]'s on-demand sync gate: the Your-Formulas
/// section reads this on first paint, so a fresh install must pull from
/// Supabase before reading Drift or the list renders empty despite remote
/// rows existing.
///
/// Mutations delegate to [PersonalFormulasRepository] (offline-first, soft
/// delete) and `ref.invalidateSelf()` to refresh — matching the
/// `personal_templates` save flow. The repository already schedules a
/// non-blocking remote upload, so there's no separate upload step here.
@riverpod
class PersonalFormulasController extends _$PersonalFormulasController {
  @override
  FutureOr<List<PersonalFormula>> build() async {
    final userRepo = await ref.read(userRepositoryProvider.future);
    final repo = ref.read(personalFormulasRepositoryProvider);
    final logger = ref.read(appExternalDepsProvider).logger;

    final user = await userRepo.getCurrentUser();
    final userId = user?.id;
    if (userId == null) {
      logger.warning(
        'PersonalFormulasController build with no authenticated user — '
        'returning empty list',
        context: 'FORMULA_KIT',
      );
      return const [];
    }

    if (await repo.isStale()) {
      await repo.syncFromRemote(userId);
    }

    return repo.getFormulasForUser(userId);
  }

  /// Personal formulas for [phase] from the loaded state (newest-first).
  List<PersonalFormula> forPhase(FormulaPhase phase) {
    return (state.value ?? const [])
        .where((f) => f.phase == phase)
        .toList(growable: false);
  }

  Future<String?> _currentUserId() async {
    final userRepo = await ref.read(userRepositoryProvider.future);
    final user = await userRepo.getCurrentUser();
    return user?.id;
  }

  /// Persist a new formula (create-from-scratch or fork) and refresh the list.
  /// Returns the saved formula (with assigned id) so the caller can navigate.
  ///
  /// [quantityEditCount]: stepper edits accumulated by the editor session,
  /// attached to the save event instead of firing per tick.
  Future<PersonalFormula?> createFormula(
    PersonalFormula formula, {
    int? quantityEditCount,
  }) async {
    final repo = ref.read(personalFormulasRepositoryProvider);
    final saved = await repo.create(formula);
    ref.invalidateSelf();
    await future;

    final event = formula.provenance == FormulaProvenance.forkedFormula
        ? 'personal_formula_forked'
        : 'personal_formula_created';
    await _track(event, {
      'formula_id': saved.id,
      'phase': saved.phase.analyticsValue,
      'provenance': saved.provenance.wireValue,
      'component_count': saved.components.length,
      if (quantityEditCount != null) 'quantity_edit_count': quantityEditCount,
    });
    return saved;
  }

  /// Overwrite an existing formula and refresh the list.
  Future<PersonalFormula?> updateFormula(
    PersonalFormula formula, {
    int? quantityEditCount,
  }) async {
    final repo = ref.read(personalFormulasRepositoryProvider);
    final saved = await repo.update(formula);
    ref.invalidateSelf();
    await future;
    await _track('personal_formula_edited', {
      'formula_id': saved.id,
      'phase': saved.phase.analyticsValue,
      'component_count': saved.components.length,
      if (quantityEditCount != null) 'quantity_edit_count': quantityEditCount,
    });
    return saved;
  }

  /// Soft-delete a formula and refresh the list.
  Future<void> deleteFormula(String id) async {
    final userId = await _currentUserId();
    if (userId == null) return;
    final repo = ref.read(personalFormulasRepositoryProvider);
    await repo.delete(id: id, userId: userId);
    ref.invalidateSelf();
    await future;
    await _track('personal_formula_deleted', {'formula_id': id});
  }

  Future<void> _track(String event, Map<String, dynamic> properties) async {
    final analytics = ref.read(appExternalDepsProvider).analytics;
    await analytics.track(event, properties: properties);
  }
}
