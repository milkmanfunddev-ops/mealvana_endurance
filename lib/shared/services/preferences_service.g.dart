// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preferences_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for SharedPreferences instance

@ProviderFor(sharedPreferences)
const sharedPreferencesProvider = SharedPreferencesProvider._();

/// Provider for SharedPreferences instance

final class SharedPreferencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<SharedPreferences>,
          SharedPreferences,
          FutureOr<SharedPreferences>
        >
    with
        $FutureModifier<SharedPreferences>,
        $FutureProvider<SharedPreferences> {
  /// Provider for SharedPreferences instance
  const SharedPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sharedPreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sharedPreferencesHash();

  @$internal
  @override
  $FutureProviderElement<SharedPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SharedPreferences> create(Ref ref) {
    return sharedPreferences(ref);
  }
}

String _$sharedPreferencesHash() => r'd22b545aefe95500327f9dce52c645d746349271';

/// Provider for PreferencesService (async to wait for SharedPreferences)

@ProviderFor(preferencesService)
const preferencesServiceProvider = PreferencesServiceProvider._();

/// Provider for PreferencesService (async to wait for SharedPreferences)

final class PreferencesServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<PreferencesService>,
          PreferencesService,
          FutureOr<PreferencesService>
        >
    with
        $FutureModifier<PreferencesService>,
        $FutureProvider<PreferencesService> {
  /// Provider for PreferencesService (async to wait for SharedPreferences)
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
  $FutureProviderElement<PreferencesService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PreferencesService> create(Ref ref) {
    return preferencesService(ref);
  }
}

String _$preferencesServiceHash() =>
    r'8868af4b9879fd12fdee3da1e44d2f337b9ba05f';
