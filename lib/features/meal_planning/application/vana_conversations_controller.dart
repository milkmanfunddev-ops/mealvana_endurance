import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/services/app_external_deps.dart';
import '../data/vana_action_client.dart';
import '../data/vana_chat_repository.dart';
import '../domain/ui_action.dart';
import '../domain/vana_conversation.dart';
import '../domain/vana_conversation_kind.dart';
import 'fail_fast.dart';

part 'vana_conversations_controller.g.dart';

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
@Riverpod(retry: failFast)
class VanaConversationsController extends _$VanaConversationsController {
  /// Rows per page. The old unpaged read stopped at 50 and hid the rest.
  static const pageSize = 50;

  VanaActionClient get _actions => ref.read(vanaActionClientProvider);
  VanaChatRepository get _repo => ref.read(vanaChatRepositoryProvider);

  /// Rows the server has answered so far (its offset for the next page).
  int _offset = 0;
  bool _exhausted = false;
  bool _loadingMore = false;

  /// Bumped by [build] and [refresh]: a page that was asked for before a
  /// restart is dropped, never appended to the new list.
  int _generation = 0;

  /// False once a page came back under [pageSize] rows.
  bool get hasMore => !_exhausted;

  @override
  FutureOr<List<VanaConversationSummary>> build(VanaConversationKind kind) {
    // Riverpod reuses the notifier across invalidations: start the paging
    // over with the list.
    _generation++;
    _offset = 0;
    _exhausted = false;
    _loadingMore = false;
    return _firstPage();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    _generation++;
    _offset = 0;
    _exhausted = false;
    state = await AsyncValue.guard(_firstPage);
  }

  /// Append the next page. A no-op while a page is in flight, when the
  /// list is done, or before the first page is shown. A failed page keeps
  /// the rows on screen and lets the next scroll ask again.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || _exhausted || _loadingMore) return;
    _loadingMore = true;
    final generation = _generation;
    try {
      final next = await AsyncValue.guard(() => _page(_offset, generation));
      if (!ref.mounted || generation != _generation) return;
      switch (next) {
        case AsyncData(:final value):
          // A conversation that gained a message between pages moves to the
          // top of the server's order, so a page can repeat one shown row.
          final known = current.map((c) => c.id).toSet();
          state = AsyncData([
            ...current,
            for (final c in value)
              if (known.add(c.id)) c,
          ]);
        case AsyncError(:final error, :final stackTrace):
          ref
              .read(appExternalDepsProvider)
              .logger
              .warning(
                'loadMore(${kind.wire}) failed at offset $_offset',
                context: 'VANA_CONVERSATIONS',
                error: error,
                stackTrace: stackTrace,
              );
        default:
          break;
      }
    } finally {
      _loadingMore = false;
    }
  }

  /// Create an empty conversation of this kind and return its id (the
  /// screen then opens it and streams the opener).
  Future<String> create() async {
    final id = await _repo.createConversation(kind);
    unawaited(refresh());
    return id;
  }

  Future<List<VanaConversationSummary>> _firstPage() => _page(0, _generation);

  /// One page from [offset]; advances [_offset] and marks the end when the
  /// page came back short, unless the list restarted meanwhile.
  Future<List<VanaConversationSummary>> _page(
    int offset,
    int generation,
  ) async {
    final result = await _actions.run(
      ListConversationsAction(kind: kind, limit: pageSize, offset: offset),
    );
    final rows = result.conversations;
    if (generation != _generation) return rows;
    _offset = offset + rows.length;
    _exhausted = rows.length < pageSize;
    return rows;
  }
}
