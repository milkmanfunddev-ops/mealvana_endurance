// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_startup_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appStartupHash() => r'b4c764e7597cefaeea7a803e59daf0562a9fe425';

/// AsyncNotifier for app startup initialization using Drift
/// This coordinates the AppStartupService and provides async state management
///
/// Copied from [AppStartup].
@ProviderFor(AppStartup)
final appStartupProvider =
    AutoDisposeAsyncNotifierProvider<AppStartup, AppStartupData>.internal(
  AppStartup.new,
  name: r'appStartupProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appStartupHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppStartup = AutoDisposeAsyncNotifier<AppStartupData>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
