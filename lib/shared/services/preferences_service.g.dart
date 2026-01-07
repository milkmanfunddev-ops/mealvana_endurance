// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preferences_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for PreferencesService (synchronous now that SharedPreferences is pre-initialized)

@ProviderFor(preferencesService)
const preferencesServiceProvider = PreferencesServiceProvider._();

/// Provider for PreferencesService (synchronous now that SharedPreferences is pre-initialized)

final class PreferencesServiceProvider
    extends
        $FunctionalProvider<
          PreferencesService,
          PreferencesService,
          PreferencesService
        >
    with $Provider<PreferencesService> {
  /// Provider for PreferencesService (synchronous now that SharedPreferences is pre-initialized)
  const PreferencesServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'preferencesServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$preferencesServiceHash();

  @$internal
  @override
  $ProviderElement<PreferencesService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PreferencesService create(Ref ref) {
    return preferencesService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PreferencesService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PreferencesService>(value),
    );
  }
}

String _$preferencesServiceHash() =>
    r'e06bd6f5478c65d390b6833eef2f877194b9b0e0';
