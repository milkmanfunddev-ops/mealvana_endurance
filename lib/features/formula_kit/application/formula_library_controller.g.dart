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
    r'e1daa5f35be9e4402668b2f9f554bce3abdd008a';

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
