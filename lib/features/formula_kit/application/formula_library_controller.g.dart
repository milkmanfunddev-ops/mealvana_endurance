// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'formula_library_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FormulaLibraryController)
const formulaLibraryControllerProvider = FormulaLibraryControllerProvider._();

final class FormulaLibraryControllerProvider
    extends
        $AsyncNotifierProvider<FormulaLibraryController, FormulaLibraryState> {
  const FormulaLibraryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'formulaLibraryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$formulaLibraryControllerHash();

  @$internal
  @override
  FormulaLibraryController create() => FormulaLibraryController();
}

String _$formulaLibraryControllerHash() =>
    r'35cab133fb806d4ff975ecf78a7c5725a6b6d8fb';

abstract class _$FormulaLibraryController
    extends $AsyncNotifier<FormulaLibraryState> {
  FutureOr<FormulaLibraryState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<FormulaLibraryState>, FormulaLibraryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<FormulaLibraryState>, FormulaLibraryState>,
              AsyncValue<FormulaLibraryState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
