// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_startup_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// AsyncNotifier for app startup initialization using Drift
/// This coordinates the AppStartupService and provides async state management

@ProviderFor(AppStartup)
const appStartupProvider = AppStartupProvider._();

/// AsyncNotifier for app startup initialization using Drift
/// This coordinates the AppStartupService and provides async state management
final class AppStartupProvider
    extends $AsyncNotifierProvider<AppStartup, AppStartupData> {
  /// AsyncNotifier for app startup initialization using Drift
  /// This coordinates the AppStartupService and provides async state management
  const AppStartupProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appStartupProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appStartupHash();

  @$internal
  @override
  AppStartup create() => AppStartup();
}

String _$appStartupHash() => r'95b7a07c55422cc5aa2343a857093da370355c84';

/// AsyncNotifier for app startup initialization using Drift
/// This coordinates the AppStartupService and provides async state management

abstract class _$AppStartup extends $AsyncNotifier<AppStartupData> {
  FutureOr<AppStartupData> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<AppStartupData>, AppStartupData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AppStartupData>, AppStartupData>,
              AsyncValue<AppStartupData>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
