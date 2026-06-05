// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'personal_formula_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(PersonalFormulaController)
const personalFormulaControllerProvider = PersonalFormulaControllerProvider._();

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
final class PersonalFormulaControllerProvider
    extends
        $AsyncNotifierProvider<
          PersonalFormulaController,
          List<PersonalFormula>
        > {
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
  const PersonalFormulaControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'personalFormulaControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$personalFormulaControllerHash();

  @$internal
  @override
  PersonalFormulaController create() => PersonalFormulaController();
}

String _$personalFormulaControllerHash() =>
    r'28dd98e9c10b4f137b2bac24bc8425bb6d803151';

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

abstract class _$PersonalFormulaController
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
