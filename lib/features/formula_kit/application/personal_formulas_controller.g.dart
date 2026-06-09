// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_formulas_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(PersonalFormulasController)
const personalFormulasControllerProvider =
    PersonalFormulasControllerProvider._();

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
final class PersonalFormulasControllerProvider
    extends
        $AsyncNotifierProvider<
          PersonalFormulasController,
          List<PersonalFormula>
        > {
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
  const PersonalFormulasControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalFormulasControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalFormulasControllerHash();

  @$internal
  @override
  PersonalFormulasController create() => PersonalFormulasController();
}

String _$personalFormulasControllerHash() =>
    r'348b4f04d9bbf10f44be9db9732af38c6fce8700';

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

abstract class _$PersonalFormulasController
    extends $AsyncNotifier<List<PersonalFormula>> {
  FutureOr<List<PersonalFormula>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<List<PersonalFormula>>, List<PersonalFormula>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<PersonalFormula>>,
                List<PersonalFormula>
              >,
              AsyncValue<List<PersonalFormula>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
