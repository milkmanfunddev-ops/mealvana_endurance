// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_migration_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service for handling OAuth migration logic from anonymous profiles
/// Extracted from UserRepository to follow FOA pattern

@ProviderFor(AuthMigrationService)
const authMigrationServiceProvider = AuthMigrationServiceProvider._();

/// Service for handling OAuth migration logic from anonymous profiles
/// Extracted from UserRepository to follow FOA pattern
final class AuthMigrationServiceProvider
    extends $NotifierProvider<AuthMigrationService, void> {
  /// Service for handling OAuth migration logic from anonymous profiles
  /// Extracted from UserRepository to follow FOA pattern
  const AuthMigrationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authMigrationServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authMigrationServiceHash();

  @$internal
  @override
  AuthMigrationService create() => AuthMigrationService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$authMigrationServiceHash() =>
    r'7f0dd9d4e5c9e3d362a1aa690df113453366bb32';

/// Service for handling OAuth migration logic from anonymous profiles
/// Extracted from UserRepository to follow FOA pattern

abstract class _$AuthMigrationService extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
