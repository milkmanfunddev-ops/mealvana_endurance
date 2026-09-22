/// VS-5, the continuity invariant (vana-sheet spec): opening the sheet again
/// later the same day continues the same ambient conversation; the next day
/// opens a new one. One per person. Through the real notifier and the real
/// SharedPreferences-backed store.
///
/// mp-288: the client says when a conversation is idle — the sheet closes, the
/// app goes to the background, or a new conversation starts — fire-and-forget,
/// as a flag on the chat call.
///
/// mp-275: the launcher, its full-screen button, the Plan tab's note card and
/// a moment tap all open the day's ambient conversation; New meal plan and the
/// chat's plus button start a new one, which never moves the day's pointer.
/// Through the real chat controller, the way the entry points drive it.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_ambient_conversation_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_chat_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_situation_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_chat_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_input_mode.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_moment.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_situation.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../helpers/write_access.dart';

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

  /// The ids the server gives new conversations, in order.
  final List<String> names = [];

  /// What each turn said the athlete was looking at.
  final List<VanaSituation?> situations = [];

  @override
  Future<VanaChatResponse> streamChat({
    String? message,
    String? conversationId,
    required VanaConversationKind kind,
    bool opener = false,
    String? anchorDate,
    String? timezone,
    VanaSituation? situation,
    VanaMoment? moment,
    bool newPlan = false,
    VanaInputMode? inputMode,
  }) async {
    situations.add(situation);
    return VanaChatResponse(
      conversationId: conversationId ?? names.removeAt(0),
      kind: kind,
      events: Stream.fromIterable(const [VanaDoneEvent()]),
    );
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
        writesAllowed(),
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

  test(
    'later the same day, the sheet continues the same conversation',
    () async {
      final c = containerFor('user-1');
      expect(await open(c), isNull);
      await notifier(c).adopt('conv-a');
      expect(c.read(vanaAmbientConversationProvider).value, 'conv-a');

      now = DateTime(2026, 9, 10, 21, 45);
      expect(await open(c), 'conv-a');

      // A cold start later that day reads it back from the device.
      final restarted = containerFor('user-1');
      expect(await open(restarted), 'conv-a');
    },
  );

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

    test(
      'closing a sheet whose conversation was never named signals nothing',
      () async {
        final c = containerFor('user-1');
        await open(c);

        notifier(c).sheetClosed();

        expect(repo.idle, isEmpty);
      },
    );

    test(
      'the app going to the background signals the held conversation idle',
      () async {
        final c = containerFor('user-1');
        await open(c);
        await notifier(c).adopt('conv-a');

        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

        expect(repo.idle, ['conv-a']);
      },
    );

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

    test(
      'the server naming a different conversation signals the held one idle',
      () async {
        final c = containerFor('user-1');
        await open(c);
        await notifier(c).adopt('conv-a');

        await notifier(c).adopt('conv-b');

        expect(repo.idle, ['conv-a']);
      },
    );

    test(
      'a conversation is signalled once until the sheet opens it again',
      () async {
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
      },
    );

    test(
      'fire-and-forget: a signal that never answers or fails holds nothing up',
      () async {
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
      },
    );

    test(
      'another person\'s conversation is never signalled on their behalf',
      () async {
        final c = containerFor('user-1');
        await open(c);
        await notifier(c).adopt('conv-a');
        notifier(c).sheetClosed();

        final other = containerFor('user-2');
        await open(other);
        notifier(other).sheetClosed();

        expect(repo.idle, ['conv-a']);
      },
    );
  });

  group('entry points (mp-275)', () {
    /// The conversation the day's entry points open when the day holds none
    /// yet: the unnamed general one (the launcher's sheet, its full-screen
    /// chat, the note card's chat route).
    VanaChatController dayChat(ProviderContainer c) => c.read(
      vanaChatControllerProvider(kind: VanaConversationKind.general).notifier,
    );

    /// A conversation started new: New meal plan, or the chat's plus button.
    /// Listened to, the way its screen holds it, so it lives to be named.
    // One minted key per kind for the group, the way a screen holds its own.
    final minted = <VanaConversationKind, String>{};
    VanaChatControllerProvider newKey(VanaConversationKind kind) =>
        vanaChatControllerProvider(
          kind: kind,
          conversationId: minted.putIfAbsent(kind, newVanaConversationKey),
        );
    VanaChatController newChat(ProviderContainer c, VanaConversationKind kind) {
      final sub = c.listen(newKey(kind), (_, _) {});
      addTearDown(sub.close);
      return c.read(newKey(kind).notifier);
    }

    String? named(ProviderContainer c, VanaConversationKind kind) =>
        c.read(newKey(kind)).value?.conversationId;

    test('the note card opens the conversation the launcher named, not a '
        'fresh one', () async {
      final c = containerFor('user-1');
      repo.names.add('conv-day');

      // The launcher, first thing in the day: nothing held yet.
      expect(await notifier(c).openToday(), isNull);
      await dayChat(c).loadOpener();

      // The note card, later: the same conversation.
      expect(await notifier(c).openToday(), 'conv-day');
      expect(
        vanaAmbientChatLocation('conv-day'),
        '/vana?mode=general&c=conv-day',
      );
    });

    test('the note card first in the day names the conversation the launcher '
        'then opens', () async {
      final c = containerFor('user-1');
      repo.names.add('conv-day');

      // The note card with nothing held opens the day's unnamed conversation.
      final id = await notifier(c).openToday();
      expect(vanaAmbientChatLocation(id), '/vana?mode=general');
      await dayChat(c).send('what should I eat tonight');

      // The launcher, after: the thread the note card started.
      expect(await notifier(c).openToday(), 'conv-day');
    });

    test('a conversation started new never moves the pointer', () async {
      final c = containerFor('user-1');
      repo.names.addAll(['conv-plan', 'conv-plus', 'conv-day', 'conv-later']);

      // Armed: the day holds nothing, so the next day's conversation named is
      // the day's. A new one named first must not take its place.
      expect(await notifier(c).openToday(), isNull);
      await newChat(c, VanaConversationKind.mealPlanning).loadOpener();
      await newChat(c, VanaConversationKind.general).send('something else');
      await pumpEventQueue();
      expect(named(c, VanaConversationKind.mealPlanning), 'conv-plan');
      expect(named(c, VanaConversationKind.general), 'conv-plus');
      expect(c.read(vanaAmbientConversationProvider).value, isNull);

      await dayChat(c).loadOpener();
      // Adopting writes the device's pointer; nothing waits on it.
      await pumpEventQueue();
      expect(c.read(vanaAmbientConversationProvider).value, 'conv-day');

      // Held: a new conversation later in the day leaves it where it is, and
      // the launcher comes back to the day's.
      c.invalidate(newKey(VanaConversationKind.general));
      await c.read(newKey(VanaConversationKind.general).future);
      await newChat(c, VanaConversationKind.general).send('another thing');
      expect(named(c, VanaConversationKind.general), 'conv-later');
      expect(await notifier(c).openToday(), 'conv-day');
      expect(repo.idle, isEmpty, reason: 'nothing replaced the day\'s');
    });

    test('Ask Vana from the formula editor starts a new conversation that '
        'sees the draft, and leaves the pointer where it is', () async {
      final c = containerFor('user-1');
      repo.names.addAll(['conv-day', 'conv-formula']);

      // The day is under way: the launcher named today's conversation.
      expect(await notifier(c).openToday(), isNull);
      await dayChat(c).loadOpener();
      await pumpEventQueue();
      expect(c.read(vanaAmbientConversationProvider).value, 'conv-day');

      // The editor is on screen with a quantity the athlete just changed and
      // nothing has saved. Ask Vana opens `/vana?c=new&mode=general`, which is
      // the new-conversation key.
      final situation = VanaSituation.formulaEditor(
        formulaId: 'pf-1',
        draft: const VanaFormulaDraft(
          name: 'Long ride bottle',
          phase: 'during',
          activities: ['cycling'],
          components: [VanaFormulaDraftComponent(id: 'tf-banana', qty: 1.5)],
        ),
      );
      c.read(vanaSituationControllerProvider.notifier).report(situation);
      await newChat(
        c,
        VanaConversationKind.general,
      ).send('is that enough carbs?');

      expect(named(c, VanaConversationKind.general), 'conv-formula');
      // The draft travelled with the question, unsaved edit included.
      expect(repo.situations.last?.toJson(), situation.toJson());
      // And the launcher still comes back to the day's conversation (mp-275
      // clause 3).
      expect(c.read(vanaAmbientConversationProvider).value, 'conv-day');
      expect(await notifier(c).openToday(), 'conv-day');
    });
  });
}
