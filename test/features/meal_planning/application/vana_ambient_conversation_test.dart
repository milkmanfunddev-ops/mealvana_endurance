/// VS-5, the continuity invariant (vana-sheet spec): opening the sheet again
/// later the same day continues the same ambient conversation; the next day
/// opens a new one. One per person. Through the real notifier and the real
/// SharedPreferences-backed store.
///
/// mp-288: the client says when a conversation is idle — the sheet closes, the
/// app goes to the background, or a new conversation starts — fire-and-forget,
/// as a flag on the chat call.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_ambient_conversation_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_chat_repository.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records every idle signal the controller sends. [reply] is what each
/// signal's future does: completes, never completes, or throws.
class _IdleRepo extends Fake implements VanaChatRepository {
  final List<String> idle = [];
  Future<void> Function() reply = () async {};

  @override
  Future<void> signalIdle(String conversationId) {
    idle.add(conversationId);
    return reply();
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late DateTime now;
  late _IdleRepo repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 9, 10, 8, 30);
    repo = _IdleRepo();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  ProviderContainer containerFor(String userId) {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        userIdProvider.overrideWith((ref) async => userId),
        vanaClockProvider.overrideWithValue(() => now),
        vanaChatRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<String?> open(ProviderContainer c) =>
      c.refresh(vanaAmbientConversationProvider.future);

  VanaAmbientConversation notifier(ProviderContainer c) =>
      c.read(vanaAmbientConversationProvider.notifier);

  test('the first sheet of the day has no conversation yet', () async {
    final c = containerFor('user-1');
    expect(await open(c), isNull);
  });

  test('later the same day, the sheet continues the same conversation', () async {
    final c = containerFor('user-1');
    expect(await open(c), isNull);
    await notifier(c).adopt('conv-a');
    expect(c.read(vanaAmbientConversationProvider).value, 'conv-a');

    now = DateTime(2026, 9, 10, 21, 45);
    expect(await open(c), 'conv-a');

    // A cold start later that day reads it back from the device.
    final restarted = containerFor('user-1');
    expect(await open(restarted), 'conv-a');
  });

  test('the next day opens a new one', () async {
    final c = containerFor('user-1');
    await open(c);
    await notifier(c).adopt('conv-a');

    now = DateTime(2026, 9, 11, 0, 5);
    expect(await open(c), isNull);

    await notifier(c).adopt('conv-b');
    expect(await open(c), 'conv-b');
  });

  test('each person has their own', () async {
    final a = containerFor('user-1');
    await open(a);
    await notifier(a).adopt('conv-a');

    final b = containerFor('user-2');
    expect(await open(b), isNull);
    expect(await open(a), 'conv-a');
  });

  test('adopting the same conversation twice is harmless', () async {
    final c = containerFor('user-1');
    await open(c);
    final n = notifier(c);
    await n.adopt('conv-a');
    await n.adopt('conv-a');
    expect(await open(c), 'conv-a');
    expect(repo.idle, isEmpty);
  });

  group('idle (mp-288)', () {
    test('closing the sheet signals its conversation idle', () async {
      final c = containerFor('user-1');
      await open(c);
      await notifier(c).adopt('conv-a');

      notifier(c).sheetClosed();

      expect(repo.idle, ['conv-a']);
    });

    test('closing a sheet whose conversation was never named signals nothing', () async {
      final c = containerFor('user-1');
      await open(c);

      notifier(c).sheetClosed();

      expect(repo.idle, isEmpty);
    });

    test('the app going to the background signals the held conversation idle', () async {
      final c = containerFor('user-1');
      await open(c);
      await notifier(c).adopt('conv-a');

      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      expect(repo.idle, ['conv-a']);
    });

    test('a new day\'s conversation signals the one before it idle', () async {
      final c = containerFor('user-1');
      await open(c);
      await notifier(c).adopt('conv-a');

      now = DateTime(2026, 9, 11, 7);
      expect(await open(c), isNull);
      expect(repo.idle, ['conv-a']);

      await notifier(c).adopt('conv-b');
      expect(repo.idle, ['conv-a'], reason: 'conv-a was already signalled');
    });

    test('the server naming a different conversation signals the held one idle', () async {
      final c = containerFor('user-1');
      await open(c);
      await notifier(c).adopt('conv-a');

      await notifier(c).adopt('conv-b');

      expect(repo.idle, ['conv-a']);
    });

    test('a conversation is signalled once until the sheet opens it again', () async {
      final c = containerFor('user-1');
      await open(c);
      await notifier(c).adopt('conv-a');

      notifier(c).sheetClosed();
      notifier(c).sheetClosed();
      expect(repo.idle, ['conv-a']);

      // Reopened the same day: it may hold new turns, so the next close says so.
      now = DateTime(2026, 9, 10, 20);
      expect(await open(c), 'conv-a');
      notifier(c).sheetClosed();
      expect(repo.idle, ['conv-a', 'conv-a']);
    });

    test('fire-and-forget: a signal that never answers or fails holds nothing up', () async {
      final c = containerFor('user-1');
      await open(c);
      await notifier(c).adopt('conv-a');

      repo.reply = () => Completer<void>().future;
      notifier(c).sheetClosed();
      expect(repo.idle, ['conv-a']);

      repo.reply = () => Future.error(StateError('offline'));
      await notifier(c).adopt('conv-b');
      notifier(c).sheetClosed();
      await pumpEventQueue();
      expect(repo.idle, ['conv-a', 'conv-b']);
    });

    test('another person\'s conversation is never signalled on their behalf', () async {
      final c = containerFor('user-1');
      await open(c);
      await notifier(c).adopt('conv-a');
      notifier(c).sheetClosed();

      final other = containerFor('user-2');
      await open(other);
      notifier(other).sheetClosed();

      expect(repo.idle, ['conv-a']);
    });
  });
}
