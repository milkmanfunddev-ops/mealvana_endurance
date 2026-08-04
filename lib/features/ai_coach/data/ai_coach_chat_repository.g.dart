// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_coach_chat_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiCoachChatRepository)
const aiCoachChatRepositoryProvider = AiCoachChatRepositoryProvider._();

final class AiCoachChatRepositoryProvider
    extends
        $FunctionalProvider<
          AiCoachChatRepository,
          AiCoachChatRepository,
          AiCoachChatRepository
        >
    with $Provider<AiCoachChatRepository> {
  const AiCoachChatRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiCoachChatRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiCoachChatRepositoryHash();

  @$internal
  @override
  $ProviderElement<AiCoachChatRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AiCoachChatRepository create(Ref ref) {
    return aiCoachChatRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiCoachChatRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiCoachChatRepository>(value),
    );
  }
}

String _$aiCoachChatRepositoryHash() =>
    r'cce187cc0aaa09760fb305e65520c156fb0bd119';
