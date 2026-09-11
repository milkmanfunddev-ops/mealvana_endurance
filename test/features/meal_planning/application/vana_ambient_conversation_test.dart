/// VS-5, the continuity invariant (vana-sheet spec): opening the sheet again
/// later the same day continues the same ambient conversation; the next day
/// opens a new one. One per person. Through the real notifier and the real
/// SharedPreferences-backed store.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_ambient_conversation_controller.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 9, 10, 8, 30);
  });

  ProviderContainer containerFor(String userId) {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        userIdProvider.overrideWith((ref) async => userId),
        vanaClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<String?> open(ProviderContainer c) =>
      c.refresh(vanaAmbientConversationProvider.future);

  test('the first sheet of the day has no conversation yet', () async {
    final c = containerFor('user-1');
    expect(await open(c), isNull);
  });

  test('later the same day, the sheet continues the same conversation', () async {
    final c = containerFor('user-1');
    expect(await open(c), isNull);
    await c.read(vanaAmbientConversationProvider.notifier).adopt('conv-a');
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
    await c.read(vanaAmbientConversationProvider.notifier).adopt('conv-a');

    now = DateTime(2026, 9, 11, 0, 5);
    expect(await open(c), isNull);

    await c.read(vanaAmbientConversationProvider.notifier).adopt('conv-b');
    expect(await open(c), 'conv-b');
  });

  test('each person has their own', () async {
    final a = containerFor('user-1');
    await open(a);
    await a.read(vanaAmbientConversationProvider.notifier).adopt('conv-a');

    final b = containerFor('user-2');
    expect(await open(b), isNull);
    expect(await open(a), 'conv-a');
  });

  test('adopting the same conversation twice is harmless', () async {
    final c = containerFor('user-1');
    await open(c);
    final n = c.read(vanaAmbientConversationProvider.notifier);
    await n.adopt('conv-a');
    await n.adopt('conv-a');
    expect(await open(c), 'conv-a');
  });
}
