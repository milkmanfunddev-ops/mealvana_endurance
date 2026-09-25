// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vana_chat_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One Vana conversation (planning or general), keyed by kind + id.
///
/// Streams turns from [VanaChatRepository], accumulates text and parts into
/// the last message, folds `batch` parts into [MealPlanController] (they
/// are never rendered inline) and `memory_saved` parts into the memory
/// repository, and maps transport errors to [VanaChatErrorKind]. A chip tap
/// is a plain user message ([tapChip]), except a fixed-label chip, which
/// acts at once on the no-model endpoint ([actAtOnce], mp-464).

@ProviderFor(VanaChatController)
const vanaChatControllerProvider = VanaChatControllerFamily._();

/// One Vana conversation (planning or general), keyed by kind + id.
///
/// Streams turns from [VanaChatRepository], accumulates text and parts into
/// the last message, folds `batch` parts into [MealPlanController] (they
/// are never rendered inline) and `memory_saved` parts into the memory
/// repository, and maps transport errors to [VanaChatErrorKind]. A chip tap
/// is a plain user message ([tapChip]), except a fixed-label chip, which
/// acts at once on the no-model endpoint ([actAtOnce], mp-464).
final class VanaChatControllerProvider
    extends $AsyncNotifierProvider<VanaChatController, VanaChatState> {
  /// One Vana conversation (planning or general), keyed by kind + id.
  ///
  /// Streams turns from [VanaChatRepository], accumulates text and parts into
  /// the last message, folds `batch` parts into [MealPlanController] (they
  /// are never rendered inline) and `memory_saved` parts into the memory
  /// repository, and maps transport errors to [VanaChatErrorKind]. A chip tap
  /// is a plain user message ([tapChip]), except a fixed-label chip, which
  /// acts at once on the no-model endpoint ([actAtOnce], mp-464).
  const VanaChatControllerProvider._({
    required VanaChatControllerFamily super.from,
    required ({VanaConversationKind kind, String? conversationId})
    super.argument,
  }) : super(
         retry: null,
         name: r'vanaChatControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$vanaChatControllerHash();

  @override
  String toString() {
    return r'vanaChatControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  VanaChatController create() => VanaChatController();

  @override
  bool operator ==(Object other) {
    return other is VanaChatControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$vanaChatControllerHash() =>
    r'dc66adbfdbe120020407032f4b47632d028699f7';

/// One Vana conversation (planning or general), keyed by kind + id.
///
/// Streams turns from [VanaChatRepository], accumulates text and parts into
/// the last message, folds `batch` parts into [MealPlanController] (they
/// are never rendered inline) and `memory_saved` parts into the memory
/// repository, and maps transport errors to [VanaChatErrorKind]. A chip tap
/// is a plain user message ([tapChip]), except a fixed-label chip, which
/// acts at once on the no-model endpoint ([actAtOnce], mp-464).

final class VanaChatControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          VanaChatController,
          AsyncValue<VanaChatState>,
          VanaChatState,
          FutureOr<VanaChatState>,
          ({VanaConversationKind kind, String? conversationId})
        > {
  const VanaChatControllerFamily._()
    : super(
        retry: null,
        name: r'vanaChatControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// One Vana conversation (planning or general), keyed by kind + id.
  ///
  /// Streams turns from [VanaChatRepository], accumulates text and parts into
  /// the last message, folds `batch` parts into [MealPlanController] (they
  /// are never rendered inline) and `memory_saved` parts into the memory
  /// repository, and maps transport errors to [VanaChatErrorKind]. A chip tap
  /// is a plain user message ([tapChip]), except a fixed-label chip, which
  /// acts at once on the no-model endpoint ([actAtOnce], mp-464).

  VanaChatControllerProvider call({
    required VanaConversationKind kind,
    String? conversationId,
  }) => VanaChatControllerProvider._(
    argument: (kind: kind, conversationId: conversationId),
    from: this,
  );

  @override
  String toString() => r'vanaChatControllerProvider';
}

/// One Vana conversation (planning or general), keyed by kind + id.
///
/// Streams turns from [VanaChatRepository], accumulates text and parts into
/// the last message, folds `batch` parts into [MealPlanController] (they
/// are never rendered inline) and `memory_saved` parts into the memory
/// repository, and maps transport errors to [VanaChatErrorKind]. A chip tap
/// is a plain user message ([tapChip]), except a fixed-label chip, which
/// acts at once on the no-model endpoint ([actAtOnce], mp-464).

abstract class _$VanaChatController extends $AsyncNotifier<VanaChatState> {
  late final _$args =
      ref.$arg as ({VanaConversationKind kind, String? conversationId});
  VanaConversationKind get kind => _$args.kind;
  String? get conversationId => _$args.conversationId;

  FutureOr<VanaChatState> build({
    required VanaConversationKind kind,
    String? conversationId,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      kind: _$args.kind,
      conversationId: _$args.conversationId,
    );
    final ref = this.ref as $Ref<AsyncValue<VanaChatState>, VanaChatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VanaChatState>, VanaChatState>,
              AsyncValue<VanaChatState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
