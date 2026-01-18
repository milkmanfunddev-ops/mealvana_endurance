// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'version_check_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service for checking app version and schema version against remote configuration
///
/// This service queries the app_config table in Supabase to determine if:
/// 1. The app version meets the minimum required version
/// 2. The local schema version matches the remote schema version
///
/// Results are cached in SharedPreferences to handle network failures gracefully.

@ProviderFor(versionCheckService)
const versionCheckServiceProvider = VersionCheckServiceProvider._();

/// Service for checking app version and schema version against remote configuration
///
/// This service queries the app_config table in Supabase to determine if:
/// 1. The app version meets the minimum required version
/// 2. The local schema version matches the remote schema version
///
/// Results are cached in SharedPreferences to handle network failures gracefully.

final class VersionCheckServiceProvider
    extends
        $FunctionalProvider<
          VersionCheckService,
          VersionCheckService,
          VersionCheckService
        >
    with $Provider<VersionCheckService> {
  /// Service for checking app version and schema version against remote configuration
  ///
  /// This service queries the app_config table in Supabase to determine if:
  /// 1. The app version meets the minimum required version
  /// 2. The local schema version matches the remote schema version
  ///
  /// Results are cached in SharedPreferences to handle network failures gracefully.
  const VersionCheckServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'versionCheckServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$versionCheckServiceHash();

  @$internal
  @override
  $ProviderElement<VersionCheckService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  VersionCheckService create(Ref ref) {
    return versionCheckService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VersionCheckService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VersionCheckService>(value),
    );
  }
}

String _$versionCheckServiceHash() =>
    r'0aa7e9b6ff71ce0086a0d69d2947363b9bf43879';
