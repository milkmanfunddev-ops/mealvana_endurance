// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_foods_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Repository provider following Andrea's pattern

@ProviderFor(userFoodsRepository)
const userFoodsRepositoryProvider = UserFoodsRepositoryProvider._();

/// Repository provider following Andrea's pattern

final class UserFoodsRepositoryProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserFoodsRepository>,
          UserFoodsRepository,
          FutureOr<UserFoodsRepository>
        >
    with
        $FutureModifier<UserFoodsRepository>,
        $FutureProvider<UserFoodsRepository> {
  /// Repository provider following Andrea's pattern
  const UserFoodsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userFoodsRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userFoodsRepositoryHash();

  @$internal
  @override
  $FutureProviderElement<UserFoodsRepository> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UserFoodsRepository> create(Ref ref) {
    return userFoodsRepository(ref);
  }
}

String _$userFoodsRepositoryHash() =>
    r'b39c047973275d4d4d10b7ade4282783d31fa929';
