/// [VanaExchange] read from where an exchange starts (vana-moment spec VM-1).
/// The one-message rule for an `auto` height went with the heights (mp-265).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_exchange.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';

VanaMessage _vana(String text, [List<VanaPart> parts = const []]) =>
    VanaMessage(
      id: 'v-$text',
      conversationId: 'c',
      role: VanaMessageRole.assistant,
      content: text,
      parts: parts,
      createdAt: DateTime(2026, 9, 10, 9),
    );

VanaMessage _athlete(String text) => VanaMessage(
  id: 'a-$text',
  conversationId: 'c',
  role: VanaMessageRole.user,
  content: text,
  createdAt: DateTime(2026, 9, 10, 9),
);

void main() {
  exchangeStartTests();
}

/// A moment starts a new exchange mid-thread (vana-moment spec VM-1): the
/// exchange is read from where it starts.
void exchangeStartTests() {
  const offers = VanaChoicesPart(
    options: ['What should I eat today?', 'Start a meal plan'],
  );
  const momentOffers = VanaChoicesPart(
    options: ['Walk me through it', "I'll handle it"],
  );
  final thread = [
    _vana('Morning.', const [offers]),
    _athlete('What should I eat today?'),
    _vana('Oats and a banana at breakfast.'),
  ];
  final moment = _vana('Your tempo run is at 5:30.', const [momentOffers]);

  group('an exchange that starts mid-thread', () {
    test('its opening offers are the quick replies', () {
      final exchange = VanaExchange.of(
        [...thread, moment],
        isStreaming: false,
        start: 3,
      );
      expect(exchange.quickReplies, ['Walk me through it', "I'll handle it"]);
    });

    test('read from the start, the old thread keeps the replies away', () {
      final exchange = VanaExchange.of([...thread, moment], isStreaming: false);
      expect(exchange.quickReplies, isEmpty);
    });

    test('its opening is drawn as an opening: offers never inline', () {
      final exchange = VanaExchange.of(
        [...thread, moment],
        isStreaming: false,
        start: 3,
      );
      expect(exchange.inlineParts(3, moment), isEmpty);
      // The earlier exchange's opening stays an opening too.
      expect(exchange.inlineParts(0, thread[0]), isEmpty);
    });

    test('the athlete answering retires the replies', () {
      final exchange = VanaExchange.of(
        [...thread, moment, _athlete('Walk me through it')],
        isStreaming: false,
        start: 3,
      );
      expect(exchange.quickReplies, isEmpty);
    });

  });
}
