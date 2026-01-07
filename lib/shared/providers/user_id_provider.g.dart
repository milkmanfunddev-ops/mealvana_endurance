// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_id_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the user ID (auth UUID) for the current user.
///
/// This provider must stay alive for the entire session so background services
/// (sync, repositories, etc.) can await it safely without hitting autoDispose
/// race conditions.

@ProviderFor(userId)
const userIdProvider = UserIdProvider._();

/// Provides the user ID (auth UUID) for the current user.
///
/// This provider must stay alive for the entire session so background services
/// (sync, repositories, etc.) can await it safely without hitting autoDispose
/// race conditions.

final class UserIdProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// Provides the user ID (auth UUID) for the current user.
  ///
  /// This provider must stay alive for the entire session so background services
  /// (sync, repositories, etc.) can await it safely without hitting autoDispose
  /// race conditions.
  const UserIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userIdHash();

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    return userId(ref);
  }
}

String _$userIdHash() => r'468cfa9f53c8f15ed162b3e9d0be6c5e115ee4ad';
