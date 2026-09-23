import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/vana_chat_repository.dart';
import '../domain/vana_conversation.dart';
import '../domain/vana_conversation_kind.dart';

part 'vana_conversations_controller.g.dart';

/// The conversations list for one [kind] ("Ask Vana" / "Meal plans").
@riverpod
class VanaConversationsController extends _$VanaConversationsController {
  VanaChatRepository get _repo => ref.read(vanaChatRepositoryProvider);

  @override
  FutureOr<List<VanaConversationSummary>> build(VanaConversationKind kind) =>
      _repo.fetchConversations(kind);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.fetchConversations(kind));
  }

  /// Create an empty conversation of this kind and return its id (the
  /// screen then opens it and streams the opener).
  Future<String> create() async {
    final id = await _repo.createConversation(kind);
    unawaited(refresh());
    return id;
  }
}
