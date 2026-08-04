// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_coach_chat_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AiCoachChatController)
const aiCoachChatControllerProvider = AiCoachChatControllerProvider._();

final class AiCoachChatControllerProvider
    extends $AsyncNotifierProvider<AiCoachChatController, AiCoachChatState> {
  const AiCoachChatControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiCoachChatControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiCoachChatControllerHash();

  @$internal
  @override
  AiCoachChatController create() => AiCoachChatController();
}

String _$aiCoachChatControllerHash() =>
    r'6fc851b2a03eb33932cc104cf53b563913e7be9f';

abstract class _$AiCoachChatController
    extends $AsyncNotifier<AiCoachChatState> {
  FutureOr<AiCoachChatState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<AiCoachChatState>, AiCoachChatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AiCoachChatState>, AiCoachChatState>,
              AsyncValue<AiCoachChatState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
