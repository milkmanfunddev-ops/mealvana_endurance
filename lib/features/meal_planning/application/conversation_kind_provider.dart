import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/vana_chat_repository.dart';
import '../domain/vana_conversation_kind.dart';

part 'conversation_kind_provider.g.dart';

/// The kind of an existing Vana conversation, read from the server, for a
/// link that names the conversation but not its mode (`/vana?c=<id>`).
/// Null when the conversation is not the athlete's or does not exist; the
/// route then falls back to meal planning, as it always did
/// (testing-wave 134, Finding 118-004).
@riverpod
Future<VanaConversationKind?> conversationKind(Ref ref, String id) =>
    ref.watch(vanaChatRepositoryProvider).fetchConversationKind(id);
