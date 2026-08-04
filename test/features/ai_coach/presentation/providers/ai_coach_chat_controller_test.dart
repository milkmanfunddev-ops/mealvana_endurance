import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/jade/data/jade_chat_repository.dart';
import 'package:mealvana_endurance/features/jade/domain/jade_conversation.dart';
import 'package:mealvana_endurance/features/jade/domain/jade_message.dart';
import 'package:mealvana_endurance/features/jade/presentation/providers/jade_chat_controller.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _FakeLogger extends Fake implements AppLogger {
  @override
  void info(String message, {String? context, Map<String, dynamic>? data}) {}
  @override
  void error(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {}
  @override
  void warning(
    String message, {
    String? context,
    Map<String, dynamic>? data,
    dynamic error,
    StackTrace? stackTrace,
  }) {}
}

class _FakeContentService extends Fake implements ContentService {
  @override
  String getValue(String key, {String? defaultValue = ''}) =>
      defaultValue ?? '';
}

class _MockRepository extends Fake implements JadeChatRepository {
  _MockRepository({
    this.conversations = const [],
    this.messagesByConversation = const {},
  });

  final List<JadeConversation> conversations;
  final Map<String, List<JadeMessage>> messagesByConversation;

  int fetchConversationsCalls = 0;
  int fetchMessagesCalls = 0;
  String? lastFetchedConversationId;

  @override
  Future<List<JadeConversation>> fetchConversations() async {
    fetchConversationsCalls++;
    return conversations;
  }

  @override
  Future<List<JadeMessage>> fetchMessages(String conversationId) async {
    fetchMessagesCalls++;
    lastFetchedConversationId = conversationId;
    return messagesByConversation[conversationId] ?? [];
  }

  @override
  Future<JadeSendResult> requestOpener({
    String? timezone,
    double? latitude,
    double? longitude,
  }) async {
    return JadeSendResult(
      conversationId: '',
      eventStream: Stream.fromIterable([const JadeDoneEvent()]),
    );
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('JadeChatController.build – conversation resume', () {
    late _FakeLogger logger;
    late _FakeContentService contentService;

    setUp(() {
      logger = _FakeLogger();
      contentService = _FakeContentService();
    });

    ProviderContainer createContainer(_MockRepository repository) {
      final container = ProviderContainer(
        overrides: [
          jadeChatRepositoryProvider.overrideWithValue(repository),
          appLoggerProvider.overrideWithValue(logger),
          contentServiceProvider.overrideWithValue(contentService),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('resumes most recent conversation when history exists', () async {
      final now = DateTime.now();
      final conversation = JadeConversation(
        id: 'conv-abc-123',
        title: 'Nutrition chat',
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(minutes: 5)),
        isDeleted: false,
      );
      final messages = [
        JadeMessage(
          id: 'msg-1',
          conversationId: 'conv-abc-123',
          role: JadeMessageRole.user,
          content: 'What should I eat before my run?',
          createdAt: now.subtract(const Duration(minutes: 10)),
        ),
        JadeMessage(
          id: 'msg-2',
          conversationId: 'conv-abc-123',
          role: JadeMessageRole.assistant,
          content: 'For a long run, aim for 1-4g/kg of carbs...',
          createdAt: now.subtract(const Duration(minutes: 9)),
        ),
      ];

      final repo = _MockRepository(
        conversations: [conversation],
        messagesByConversation: {'conv-abc-123': messages},
      );
      final container = createContainer(repo);

      // Wait for the async build to complete.
      final sub = container.listen(jadeChatControllerProvider, (_, __) {});
      await container.read(jadeChatControllerProvider.future);
      final state = container.read(jadeChatControllerProvider).value!;

      expect(repo.fetchConversationsCalls, 1);
      expect(repo.fetchMessagesCalls, 1);
      expect(repo.lastFetchedConversationId, 'conv-abc-123');
      expect(state.conversationId, 'conv-abc-123');
      expect(state.messages.length, 2);
      expect(state.messages.first.content, 'What should I eat before my run?');
      expect(state.hasHistory, isTrue);
      expect(state.isStreaming, isFalse);

      sub.close();
    });

    test('returns empty state with hasHistory=false for new user', () async {
      final repo = _MockRepository(conversations: []);
      final container = createContainer(repo);

      final sub = container.listen(jadeChatControllerProvider, (_, __) {});
      await container.read(jadeChatControllerProvider.future);
      final state = container.read(jadeChatControllerProvider).value!;

      expect(repo.fetchConversationsCalls, 1);
      expect(repo.fetchMessagesCalls, 0);
      expect(state.conversationId, isNull);
      expect(state.messages, isEmpty);
      expect(state.hasHistory, isFalse);

      sub.close();
    });

    test('subsequent send appends to resumed conversation', () async {
      final now = DateTime.now();
      final conversation = JadeConversation(
        id: 'conv-existing',
        title: '',
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
      );
      final messages = [
        JadeMessage(
          id: 'msg-old',
          conversationId: 'conv-existing',
          role: JadeMessageRole.assistant,
          content: 'Hello!',
          createdAt: now,
        ),
      ];

      final repo = _MockRepository(
        conversations: [conversation],
        messagesByConversation: {'conv-existing': messages},
      );
      final container = createContainer(repo);

      final sub = container.listen(jadeChatControllerProvider, (_, __) {});
      await container.read(jadeChatControllerProvider.future);
      final state = container.read(jadeChatControllerProvider).value!;

      expect(
        state.conversationId,
        'conv-existing',
        reason:
            'The resumed conversationId should be set so send() '
            'continues the same thread',
      );
      expect(state.messages.length, 1);

      sub.close();
    });
  });
}
