// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vana_conversations_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The conversations list for one [kind] ("Ask Vana" / "Meal plans"), read
/// through `list_conversations` on `vana-action` (ticket 126): each planning
/// row carries the plan the server picked for it, the same pick the opened
/// chat shows, so the list and the header never disagree on a title.
///
/// Paged (88-021): the first page loads in [build]; the screen calls
/// [loadMore] as its list nears the end, and an under-full page marks the
/// end so nothing asks again until [refresh].
///
/// A failed first page is an error at once ([failFast]), so the screen shows
/// its Retry within a moment offline instead of a spinner (88-012).

@ProviderFor(VanaConversationsController)
const vanaConversationsControllerProvider =
    VanaConversationsControllerFamily._();

/// The conversations list for one [kind] ("Ask Vana" / "Meal plans"), read
/// through `list_conversations` on `vana-action` (ticket 126): each planning
/// row carries the plan the server picked for it, the same pick the opened
/// chat shows, so the list and the header never disagree on a title.
///
/// Paged (88-021): the first page loads in [build]; the screen calls
/// [loadMore] as its list nears the end, and an under-full page marks the
/// end so nothing asks again until [refresh].
///
/// A failed first page is an error at once ([failFast]), so the screen shows
/// its Retry within a moment offline instead of a spinner (88-012).
final class VanaConversationsControllerProvider
    extends
        $AsyncNotifierProvider<
          VanaConversationsController,
          List<VanaConversationSummary>
        > {
  /// The conversations list for one [kind] ("Ask Vana" / "Meal plans"), read
  /// through `list_conversations` on `vana-action` (ticket 126): each planning
  /// row carries the plan the server picked for it, the same pick the opened
  /// chat shows, so the list and the header never disagree on a title.
  ///
  /// Paged (88-021): the first page loads in [build]; the screen calls
  /// [loadMore] as its list nears the end, and an under-full page marks the
  /// end so nothing asks again until [refresh].
  ///
  /// A failed first page is an error at once ([failFast]), so the screen shows
  /// its Retry within a moment offline instead of a spinner (88-012).
  const VanaConversationsControllerProvider._({
    required VanaConversationsControllerFamily super.from,
    required VanaConversationKind super.argument,
  }) : super(
         retry: failFast,
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
    r'7c70434666c287861f5b368e949c0bcf9fa867b5';

/// The conversations list for one [kind] ("Ask Vana" / "Meal plans"), read
/// through `list_conversations` on `vana-action` (ticket 126): each planning
/// row carries the plan the server picked for it, the same pick the opened
/// chat shows, so the list and the header never disagree on a title.
///
/// Paged (88-021): the first page loads in [build]; the screen calls
/// [loadMore] as its list nears the end, and an under-full page marks the
/// end so nothing asks again until [refresh].
///
/// A failed first page is an error at once ([failFast]), so the screen shows
/// its Retry within a moment offline instead of a spinner (88-012).

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
        retry: failFast,
        name: r'vanaConversationsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The conversations list for one [kind] ("Ask Vana" / "Meal plans"), read
  /// through `list_conversations` on `vana-action` (ticket 126): each planning
  /// row carries the plan the server picked for it, the same pick the opened
  /// chat shows, so the list and the header never disagree on a title.
  ///
  /// Paged (88-021): the first page loads in [build]; the screen calls
  /// [loadMore] as its list nears the end, and an under-full page marks the
  /// end so nothing asks again until [refresh].
  ///
  /// A failed first page is an error at once ([failFast]), so the screen shows
  /// its Retry within a moment offline instead of a spinner (88-012).

  VanaConversationsControllerProvider call(VanaConversationKind kind) =>
      VanaConversationsControllerProvider._(argument: kind, from: this);

  @override
  String toString() => r'vanaConversationsControllerProvider';
}

/// The conversations list for one [kind] ("Ask Vana" / "Meal plans"), read
/// through `list_conversations` on `vana-action` (ticket 126): each planning
/// row carries the plan the server picked for it, the same pick the opened
/// chat shows, so the list and the header never disagree on a title.
///
/// Paged (88-021): the first page loads in [build]; the screen calls
/// [loadMore] as its list nears the end, and an under-full page marks the
/// end so nothing asks again until [refresh].
///
/// A failed first page is an error at once ([failFast]), so the screen shows
/// its Retry within a moment offline instead of a spinner (88-012).

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
