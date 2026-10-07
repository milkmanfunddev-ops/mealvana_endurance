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
        $FunctionalProvider<MacroRepository, MacroRepository, MacroRepository>
    with $Provider<MacroRepository> {
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
  $ProviderElement<MacroRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MacroRepository create(Ref ref) {
    return macroRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MacroRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MacroRepository>(value),
    );
  }
}

String _$macroRepositoryHash() => r'25da80d8982f137117472cb3ee5ea5d2cef73d05';
