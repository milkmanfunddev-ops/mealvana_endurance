// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'formula_editor_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Drives the create/edit screen for a single personal formula.
///
/// Family keys: `formulaId` (null = create-from-scratch) + `phase` (required
/// for create; ignored when editing since the loaded formula carries it).
/// On save, delegates to [PersonalFormulasController] so the analytics +
/// list-invalidation happen in one place.

@ProviderFor(FormulaEditorController)
const formulaEditorControllerProvider = FormulaEditorControllerFamily._();

/// Drives the create/edit screen for a single personal formula.
///
/// Family keys: `formulaId` (null = create-from-scratch) + `phase` (required
/// for create; ignored when editing since the loaded formula carries it).
/// On save, delegates to [PersonalFormulasController] so the analytics +
/// list-invalidation happen in one place.
final class FormulaEditorControllerProvider
    extends $AsyncNotifierProvider<FormulaEditorController, FormulaDraft> {
  /// Drives the create/edit screen for a single personal formula.
  ///
  /// Family keys: `formulaId` (null = create-from-scratch) + `phase` (required
  /// for create; ignored when editing since the loaded formula carries it).
  /// On save, delegates to [PersonalFormulasController] so the analytics +
  /// list-invalidation happen in one place.
  const FormulaEditorControllerProvider._({
    required FormulaEditorControllerFamily super.from,
    required (String?, FormulaPhase) super.argument,
  }) : super(
         retry: null,
         name: r'formulaEditorControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$formulaEditorControllerHash();

  @override
  String toString() {
    return r'formulaEditorControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  FormulaEditorController create() => FormulaEditorController();

  @override
  bool operator ==(Object other) {
    return other is FormulaEditorControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$formulaEditorControllerHash() =>
    r'19b6a3249508a55e90bf24f029e90cdb1aa6b6ea';

/// Drives the create/edit screen for a single personal formula.
///
/// Family keys: `formulaId` (null = create-from-scratch) + `phase` (required
/// for create; ignored when editing since the loaded formula carries it).
/// On save, delegates to [PersonalFormulasController] so the analytics +
/// list-invalidation happen in one place.

final class FormulaEditorControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          FormulaEditorController,
          AsyncValue<FormulaDraft>,
          FormulaDraft,
          FutureOr<FormulaDraft>,
          (String?, FormulaPhase)
        > {
  const FormulaEditorControllerFamily._()
    : super(
        retry: null,
        name: r'formulaEditorControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Drives the create/edit screen for a single personal formula.
  ///
  /// Family keys: `formulaId` (null = create-from-scratch) + `phase` (required
  /// for create; ignored when editing since the loaded formula carries it).
  /// On save, delegates to [PersonalFormulasController] so the analytics +
  /// list-invalidation happen in one place.

  FormulaEditorControllerProvider call(String? formulaId, FormulaPhase phase) =>
      FormulaEditorControllerProvider._(
        argument: (formulaId, phase),
        from: this,
      );

  @override
  String toString() => r'formulaEditorControllerProvider';
}

/// Drives the create/edit screen for a single personal formula.
///
/// Family keys: `formulaId` (null = create-from-scratch) + `phase` (required
/// for create; ignored when editing since the loaded formula carries it).
/// On save, delegates to [PersonalFormulasController] so the analytics +
/// list-invalidation happen in one place.

abstract class _$FormulaEditorController extends $AsyncNotifier<FormulaDraft> {
  late final _$args = ref.$arg as (String?, FormulaPhase);
  String? get formulaId => _$args.$1;
  FormulaPhase get phase => _$args.$2;

  FutureOr<FormulaDraft> build(String? formulaId, FormulaPhase phase);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args.$1, _$args.$2);
    final ref = this.ref as $Ref<AsyncValue<FormulaDraft>, FormulaDraft>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<FormulaDraft>, FormulaDraft>,
              AsyncValue<FormulaDraft>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
