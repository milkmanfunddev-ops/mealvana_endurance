import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/user_id_provider.dart';
import '../data/vana_ambient_store.dart';
import '../data/vana_chat_repository.dart';
import '../domain/week_start.dart';

part 'vana_ambient_conversation_controller.g.dart';

/// The wall clock the ambient day is read from. Overridden in tests.
@riverpod
DateTime Function() vanaClock(Ref ref) => DateTime.now;

/// The ambient conversation behind the Vana sheet: one general conversation
/// per person per day (vana-sheet spec VS-5).
///
/// The value is today's conversation id, or null before the day's first sheet
/// has one. It is read at open time (`ref.refresh(...future)`), so a sheet
/// opened after midnight starts a new conversation even if the app never
/// restarted. The sheet holds the id it opened with for its whole life and
/// calls [adopt] once the server names a new conversation.
///
/// It also says when that conversation is idle (mp-288): when the sheet
/// closes ([sheetClosed]), when the app goes to the background, and when a
/// new conversation takes its place (a new day, or the server naming a
/// different one). The server writes the conversation's episode once, so the
/// next opener has it without waiting. Kept alive so the background signal
/// fires with no sheet open.
@Riverpod(keepAlive: true)
class VanaAmbientConversation extends _$VanaAmbientConversation {
  /// The conversation last held and whose it is. Survives the rebuild a
  /// sheet's open-time refresh causes, which is how a new day's build knows
  /// the conversation it replaces.
  String? _held;
  String? _heldBy;

  /// Conversations already signalled idle since the sheet last opened them.
  final Set<String> _signalled = {};

  @override
  Future<String?> build() async {
    final lifecycle = AppLifecycleListener(onHide: _signalHeld);
    ref.onDispose(lifecycle.dispose);

    final userId = await ref.watch(userIdProvider.future);
    final id = ref
        .read(vanaAmbientStoreProvider)
        .read(userId: userId, day: _today());
    _hold(id, userId);
    return id;
  }

  /// Hold [conversationId] for the rest of today.
  Future<void> adopt(String conversationId) async {
    if (state.value == conversationId) return;
    state = await AsyncValue.guard(() async {
      final userId = await ref.read(userIdProvider.future);
      await ref
          .read(vanaAmbientStoreProvider)
          .write(userId: userId, day: _today(), conversationId: conversationId);
      _hold(conversationId, userId);
      return conversationId;
    });
  }

  /// The sheet closed on the held conversation: it is idle. A hand-off to the
  /// full-screen chat is not a close; the conversation carries on there.
  void sheetClosed() => _signalHeld();

  /// Records what is held now. Another person's conversation is dropped
  /// unsignalled; one of this person's that a different one replaces is a
  /// new conversation starting, so the replaced one is idle. Holding a
  /// conversation again means it may gain turns, so it can be signalled again.
  void _hold(String? id, String userId) {
    if (_heldBy != userId) {
      _held = null;
      _signalled.clear();
    }
    final replaced = _held;
    if (replaced != null && replaced != id) _signal(replaced);
    _held = id;
    _heldBy = userId;
    if (id != null) _signalled.remove(id);
  }

  void _signalHeld() {
    final id = _held;
    if (id != null) _signal(id);
  }

  /// Fire-and-forget (mp-288 clause 2): nothing waits on the reply, and a
  /// failure is dropped (the repository logs it).
  void _signal(String id) {
    if (!ref.mounted || !_signalled.add(id)) return;
    final repo = ref.read(vanaChatRepositoryProvider);
    unawaited(
      Future.sync(() => repo.signalIdle(id)).catchError((Object _) {}),
    );
  }

  String _today() => todayIso(ref.read(vanaClockProvider)());
}
