// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_memory_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(userMemoryRepository)
const userMemoryRepositoryProvider = UserMemoryRepositoryProvider._();

final class UserMemoryRepositoryProvider
    extends
        $FunctionalProvider<
          UserMemoryRepository,
          UserMemoryRepository,
          UserMemoryRepository
        >
    with $Provider<UserMemoryRepository> {
  const UserMemoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userMemoryRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userMemoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<UserMemoryRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UserMemoryRepository create(Ref ref) {
    return userMemoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserMemoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserMemoryRepository>(value),
    );
  }
}

String _$userMemoryRepositoryHash() =>
    r'3a4f34f52521377126d070b42cd3e859d0d531a1';
