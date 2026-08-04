// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jade_chat_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(jadeChatRepository)
const jadeChatRepositoryProvider = JadeChatRepositoryProvider._();

final class JadeChatRepositoryProvider
    extends
        $FunctionalProvider<
          JadeChatRepository,
          JadeChatRepository,
          JadeChatRepository
        >
    with $Provider<JadeChatRepository> {
  const JadeChatRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jadeChatRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$jadeChatRepositoryHash();

  @$internal
  @override
  $ProviderElement<JadeChatRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  JadeChatRepository create(Ref ref) {
    return jadeChatRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(JadeChatRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<JadeChatRepository>(value),
    );
  }
}

String _$jadeChatRepositoryHash() =>
    r'7b2bafea99809077de48aaf182f6812506056274';
