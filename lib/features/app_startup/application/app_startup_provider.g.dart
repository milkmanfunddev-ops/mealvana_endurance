// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_startup_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appStartupHash() => r'7acd226c4f5450def5e324826ff297d1888e3494';

/// AsyncNotifier for app startup initialization
/// This coordinates the AppStartupService and provides async state management
///
/// Copied from [AppStartup].
@ProviderFor(AppStartup)
final appStartupProvider =
    AsyncNotifierProvider<AppStartup, AppStartupData>.internal(
  AppStartup.new,
  name: r'appStartupProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appStartupHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppStartup = AsyncNotifier<AppStartupData>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
