// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_version_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The running build as `version+build` ("1.27.1+4"), the way Sentry's user
/// context reads it (`AppStartupService.setSentryUserContext`). Read once
/// per session; `null` when the platform cannot say, so a row that carries
/// it is never refused for it.

@ProviderFor(appVersion)
const appVersionProvider = AppVersionProvider._();

/// The running build as `version+build` ("1.27.1+4"), the way Sentry's user
/// context reads it (`AppStartupService.setSentryUserContext`). Read once
/// per session; `null` when the platform cannot say, so a row that carries
/// it is never refused for it.

final class AppVersionProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// The running build as `version+build` ("1.27.1+4"), the way Sentry's user
  /// context reads it (`AppStartupService.setSentryUserContext`). Read once
  /// per session; `null` when the platform cannot say, so a row that carries
  /// it is never refused for it.
  const AppVersionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appVersionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appVersionHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return appVersion(ref);
  }
}

String _$appVersionHash() => r'0b78e26eec8bb7af51fc541a4e6f7643637970c3';
