// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'coach_chat_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for the unified coach-athlete chat screen
/// Supports Supabase Realtime for instant message delivery
/// Works for both coach and athlete perspectives

@ProviderFor(CoachChatController)
const coachChatControllerProvider = CoachChatControllerFamily._();

/// Controller for the unified coach-athlete chat screen
/// Supports Supabase Realtime for instant message delivery
/// Works for both coach and athlete perspectives
final class CoachChatControllerProvider
    extends $AsyncNotifierProvider<CoachChatController, CoachChatState> {
  /// Controller for the unified coach-athlete chat screen
  /// Supports Supabase Realtime for instant message delivery
  /// Works for both coach and athlete perspectives
  const CoachChatControllerProvider._({
    required CoachChatControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'coachChatControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$coachChatControllerHash();

  @override
  String toString() {
    return r'coachChatControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CoachChatController create() => CoachChatController();

  @override
  bool operator ==(Object other) {
    return other is CoachChatControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$coachChatControllerHash() =>
    r'1055085e6f0b6feac1622611f1ada06e4a13d00b';

/// Controller for the unified coach-athlete chat screen
/// Supports Supabase Realtime for instant message delivery
/// Works for both coach and athlete perspectives

final class CoachChatControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          CoachChatController,
          AsyncValue<CoachChatState>,
          CoachChatState,
          FutureOr<CoachChatState>,
          String
        > {
  const CoachChatControllerFamily._()
    : super(
        retry: null,
        name: r'coachChatControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Controller for the unified coach-athlete chat screen
  /// Supports Supabase Realtime for instant message delivery
  /// Works for both coach and athlete perspectives

  CoachChatControllerProvider call(String relationshipId) =>
      CoachChatControllerProvider._(argument: relationshipId, from: this);

  @override
  String toString() => r'coachChatControllerProvider';
}

/// Controller for the unified coach-athlete chat screen
/// Supports Supabase Realtime for instant message delivery
/// Works for both coach and athlete perspectives

abstract class _$CoachChatController extends $AsyncNotifier<CoachChatState> {
  late final _$args = ref.$arg as String;
  String get relationshipId => _$args;

  FutureOr<CoachChatState> build(String relationshipId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<CoachChatState>, CoachChatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<CoachChatState>, CoachChatState>,
              AsyncValue<CoachChatState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
