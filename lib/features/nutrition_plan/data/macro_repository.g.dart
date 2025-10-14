// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'macro_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(macroRepository)
const macroRepositoryProvider = MacroRepositoryProvider._();

final class MacroRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<MacroRepository>,
          MacroRepository,
          FutureOr<MacroRepository>
        >
    with $FutureModifier<MacroRepository>, $FutureProvider<MacroRepository> {
  const MacroRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'macroRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$macroRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<MacroRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<MacroRepository> create(Ref ref) {
    return macroRepository(ref);
  }
}

String _$macroRepositoryHash() => r'5c5c34ddca47ab4be53852055020e39ed82332ae';
