// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vana_conversations_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The conversations list for one [kind] ("Ask Vana" / "Meal plans").

@ProviderFor(VanaConversationsController)
const vanaConversationsControllerProvider =
    VanaConversationsControllerFamily._();

/// The conversations list for one [kind] ("Ask Vana" / "Meal plans").
final class VanaConversationsControllerProvider
    extends
        $AsyncNotifierProvider<
          VanaConversationsController,
          List<VanaConversationSummary>
        > {
  /// The conversations list for one [kind] ("Ask Vana" / "Meal plans").
  const VanaConversationsControllerProvider._({
    required VanaConversationsControllerFamily super.from,
    required VanaConversationKind super.argument,
  }) : super(
         retry: null,
         name: r'vanaConversationsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$vanaConversationsControllerHash();

  @override
  String toString() {
    return r'vanaConversationsControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  VanaConversationsController create() => VanaConversationsController();

  @override
  bool operator ==(Object other) {
    return other is VanaConversationsControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$vanaConversationsControllerHash() =>
    r'2ac53a794eec10a827aaf191d791d6432501109b';

/// The conversations list for one [kind] ("Ask Vana" / "Meal plans").

final class VanaConversationsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          VanaConversationsController,
          AsyncValue<List<VanaConversationSummary>>,
          List<VanaConversationSummary>,
          FutureOr<List<VanaConversationSummary>>,
          VanaConversationKind
        > {
  const VanaConversationsControllerFamily._()
    : super(
        retry: null,
        name: r'vanaConversationsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The conversations list for one [kind] ("Ask Vana" / "Meal plans").

  VanaConversationsControllerProvider call(VanaConversationKind kind) =>
      VanaConversationsControllerProvider._(argument: kind, from: this);

  @override
  String toString() => r'vanaConversationsControllerProvider';
}

/// The conversations list for one [kind] ("Ask Vana" / "Meal plans").

abstract class _$VanaConversationsController
    extends $AsyncNotifier<List<VanaConversationSummary>> {
  late final _$args = ref.$arg as VanaConversationKind;
  VanaConversationKind get kind => _$args;

  FutureOr<List<VanaConversationSummary>> build(VanaConversationKind kind);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<VanaConversationSummary>>,
              List<VanaConversationSummary>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<VanaConversationSummary>>,
                List<VanaConversationSummary>
              >,
              AsyncValue<List<VanaConversationSummary>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
