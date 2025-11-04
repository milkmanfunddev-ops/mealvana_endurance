// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weather_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Weather service provider

@ProviderFor(weatherService)
const weatherServiceProvider = WeatherServiceProvider._();

/// Weather service provider

final class WeatherServiceProvider
    extends $FunctionalProvider<WeatherService, WeatherService, WeatherService>
    with $Provider<WeatherService> {
  /// Weather service provider
  const WeatherServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'weatherServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$weatherServiceHash();

  @$internal
  @override
  $ProviderElement<WeatherService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WeatherService create(Ref ref) {
    return weatherService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WeatherService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WeatherService>(value),
    );
  }
}

String _$weatherServiceHash() => r'37be90d5821d5d413ce5c5cffd636af01f525df0';
