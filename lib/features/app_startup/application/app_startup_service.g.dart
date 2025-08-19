// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_startup_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appStartupServiceHash() => r'886c1a08b7e460c936ac9600e23acc633681e29d';

/// See also [appStartupService].
@ProviderFor(appStartupService)
final appStartupServiceProvider =
    AutoDisposeProvider<AppStartupService>.internal(
  appStartupService,
  name: r'appStartupServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appStartupServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppStartupServiceRef = AutoDisposeProviderRef<AppStartupService>;
String _$hiveInitializationHash() =>
    r'beed58884774e0e16eb1065889041c2838b2993b';

/// Hive initialization provider - must be initialized first
///
/// Copied from [hiveInitialization].
@ProviderFor(hiveInitialization)
final hiveInitializationProvider = FutureProvider<void>.internal(
  hiveInitialization,
  name: r'hiveInitializationProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$hiveInitializationHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef HiveInitializationRef = FutureProviderRef<void>;
String _$appStartupHash() => r'527eff8bcd540f876fd7890b63e2c8d05cbcb07c';

/// Main app startup provider following Andrea's pattern
///
/// Copied from [appStartup].
@ProviderFor(appStartup)
final appStartupProvider = FutureProvider<AppStartupResult>.internal(
  appStartup,
  name: r'appStartupProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appStartupHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppStartupRef = FutureProviderRef<AppStartupResult>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
