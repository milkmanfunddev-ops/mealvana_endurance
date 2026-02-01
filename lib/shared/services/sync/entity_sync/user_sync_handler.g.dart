// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_sync_handler.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(userSyncHandler)
const userSyncHandlerProvider = UserSyncHandlerProvider._();

final class UserSyncHandlerProvider
    extends
        $FunctionalProvider<UserSyncHandler, UserSyncHandler, UserSyncHandler>
    with $Provider<UserSyncHandler> {
  const UserSyncHandlerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userSyncHandlerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userSyncHandlerHash();

  @$internal
  @override
  $ProviderElement<UserSyncHandler> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserSyncHandler create(Ref ref) {
    return userSyncHandler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserSyncHandler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserSyncHandler>(value),
    );
  }
}

String _$userSyncHandlerHash() => r'd0674412cbf137d8e27cb914cfb6a639fc0005ac';
