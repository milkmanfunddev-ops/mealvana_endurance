// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_migration_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Riverpod provider for AuthMigrationService
/// Uses a simple async function provider (NOT AsyncNotifier) to prevent disposal during auth flows

@ProviderFor(authMigrationService)
const authMigrationServiceProvider = AuthMigrationServiceProvider._();

/// Riverpod provider for AuthMigrationService
/// Uses a simple async function provider (NOT AsyncNotifier) to prevent disposal during auth flows

final class AuthMigrationServiceProvider
    extends
        $FunctionalProvider<
          AsyncValue<AuthMigrationService>,
          AuthMigrationService,
          FutureOr<AuthMigrationService>
        >
    with
        $FutureModifier<AuthMigrationService>,
        $FutureProvider<AuthMigrationService> {
  /// Riverpod provider for AuthMigrationService
  /// Uses a simple async function provider (NOT AsyncNotifier) to prevent disposal during auth flows
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
  $FutureProviderElement<AuthMigrationService> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AuthMigrationService> create(Ref ref) {
    return authMigrationService(ref);
  }
}

String _$authMigrationServiceHash() =>
    r'99e8c20653f4d1ad33d58f49c2333493290fd842';
