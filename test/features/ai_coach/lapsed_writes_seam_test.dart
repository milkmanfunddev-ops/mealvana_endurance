/// A lapsed account cannot call the AI coach (mp-457 §4, mp-491, ticket 12).
///
/// Through the real AiCoachChatController: sending and the opener ask the
/// write guard first; refused, they open the paywall once and never
/// construct the chat repository, so no turn is sent.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_coach/data/ai_coach_chat_repository.dart';
import 'package:mealvana_endurance/features/ai_coach/presentation/providers/ai_coach_chat_controller.dart';

import '../../helpers/write_access.dart';

class _FakeState extends Fake implements AiCoachChatState {}

class _Seeded extends AiCoachChatController {
  @override
  FutureOr<AiCoachChatState> build() => _FakeState();
}

void main() {
  late PaywallOpens opens;
  late ProviderContainer container;

  setUp(() {
    opens = PaywallOpens();
    container = ProviderContainer(
      overrides: [
        writesRefused(),
        opens.override,
        aiCoachChatRepositoryProvider.overrideWith(
          untouched('aiCoachChatRepository'),
        ),
        aiCoachChatControllerProvider.overrideWith(_Seeded.new),
      ],
    );
    addTearDown(container.dispose);
  });

  AiCoachChatController ctrl() =>
      container.read(aiCoachChatControllerProvider.notifier);
  final paths = <String, Future<Object?> Function()>{
    'send': () => ctrl().send('what should I eat before a long run?'),
    'loadOpener': () => ctrl().loadOpener(),
  };
  for (final entry in paths.entries) {
    test('lapsed: ${entry.key} opens the paywall and sends nothing', () async {
      await container.read(aiCoachChatControllerProvider.future);
      await expectWriteRefused(opens, entry.value);
    });
  }
}
