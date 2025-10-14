// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_memo_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for voice memo functionality
/// Handles speech-to-text and note saving using proper repository

@ProviderFor(VoiceMemoController)
const voiceMemoControllerProvider = VoiceMemoControllerProvider._();

/// Controller for voice memo functionality
/// Handles speech-to-text and note saving using proper repository
final class VoiceMemoControllerProvider
    extends $AsyncNotifierProvider<VoiceMemoController, VoiceMemoState> {
  /// Controller for voice memo functionality
  /// Handles speech-to-text and note saving using proper repository
  const VoiceMemoControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voiceMemoControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voiceMemoControllerHash();

  @$internal
  @override
  VoiceMemoController create() => VoiceMemoController();
}

String _$voiceMemoControllerHash() =>
    r'674821b66fc7477f0828aca27c20bfaffee37f9e';

/// Controller for voice memo functionality
/// Handles speech-to-text and note saving using proper repository

abstract class _$VoiceMemoController extends $AsyncNotifier<VoiceMemoState> {
  FutureOr<VoiceMemoState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<VoiceMemoState>, VoiceMemoState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VoiceMemoState>, VoiceMemoState>,
              AsyncValue<VoiceMemoState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
