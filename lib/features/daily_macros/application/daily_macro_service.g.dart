// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_macro_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(dailyMacroService)
const dailyMacroServiceProvider = DailyMacroServiceProvider._();

final class DailyMacroServiceProvider
    extends
        $FunctionalProvider<
          DailyMacroService,
          DailyMacroService,
          DailyMacroService
        >
    with $Provider<DailyMacroService> {
  const DailyMacroServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dailyMacroServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dailyMacroServiceHash();

  @$internal
  @override
  $ProviderElement<DailyMacroService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DailyMacroService create(Ref ref) {
    return dailyMacroService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DailyMacroService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DailyMacroService>(value),
    );
  }
}

String _$dailyMacroServiceHash() => r'3e00aa419c66dc2b11fdd8cb65dbf2a5284eb814';
