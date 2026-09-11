import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/user_id_provider.dart';
import '../data/vana_ambient_store.dart';
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
@riverpod
class VanaAmbientConversation extends _$VanaAmbientConversation {
  @override
  Future<String?> build() async {
    final userId = await ref.watch(userIdProvider.future);
    return ref
        .read(vanaAmbientStoreProvider)
        .read(userId: userId, day: _today());
  }

  /// Hold [conversationId] for the rest of today.
  Future<void> adopt(String conversationId) async {
    if (state.value == conversationId) return;
    state = await AsyncValue.guard(() async {
      final userId = await ref.read(userIdProvider.future);
      await ref
          .read(vanaAmbientStoreProvider)
          .write(userId: userId, day: _today(), conversationId: conversationId);
      return conversationId;
    });
  }

  String _today() => todayIso(ref.read(vanaClockProvider)());
}
