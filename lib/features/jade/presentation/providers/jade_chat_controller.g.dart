// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jade_chat_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(JadeChatController)
const jadeChatControllerProvider = JadeChatControllerProvider._();

final class JadeChatControllerProvider
    extends $AsyncNotifierProvider<JadeChatController, JadeChatState> {
  const JadeChatControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'jadeChatControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$jadeChatControllerHash();

  @$internal
  @override
  JadeChatController create() => JadeChatController();
}

String _$jadeChatControllerHash() =>
    r'177800912f97cc2b92bc689281d0cb970cf668df';

abstract class _$JadeChatController extends $AsyncNotifier<JadeChatState> {
  FutureOr<JadeChatState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<JadeChatState>, JadeChatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<JadeChatState>, JadeChatState>,
              AsyncValue<JadeChatState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
