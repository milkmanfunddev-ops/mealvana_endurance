/// [VanaExchange.oneMessage]: when the sheet may rest at its `auto` height
/// (vana-sheet spec, Three heights — "a sheet that is one message and a
/// dismiss").
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
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

bool _one(
  List<VanaMessage> messages, {
  bool streaming = false,
  bool retired = false,
}) => VanaExchange.of(
  messages,
  isStreaming: streaming,
  repliesRetired: retired,
).oneMessage;

void main() {
  exchangeStartTests();

  final picker = VanaMealPickerPart(
    title: 'Dinners that fit',
    meals: [
      MealRef.fromJson(const {
        'source': 'library',
        'id': 'D-001',
        'name': 'Salmon rice bowl',
        'mealType': 'dinner',
      }),
    ],
  );

  test('one settled message of Vana\'s is one message', () {
    expect(_one([_vana('Run fuelling is set.')]), isTrue);
  });

  test('one message and a single reply (a dismiss) is still one message', () {
    expect(
      _one([
        _vana('Run fuelling is set.', const [
          VanaChoicesPart(options: ['Dismiss']),
        ]),
      ]),
      isTrue,
    );
  });

  test('two replies are replies, not a dismiss', () {
    expect(
      _one([
        _vana('Morning.', const [
          VanaChoicesPart(options: ['Today', 'Tomorrow']),
        ]),
      ]),
      isFalse,
    );
  });

  test('a card is not one message', () {
    expect(
      _one([
        _vana('These fit.', [picker]),
      ]),
      isFalse,
    );
  });

  test('two of Vana\'s turns are not one message', () {
    expect(_one([_vana('Morning.'), _vana('Also, rain later.')]), isFalse);
  });

  test('a thread is not one message, even one that was rolled back', () {
    expect(_one([_vana('Morning.'), _athlete('hi')]), isFalse);
    expect(_one([_vana('Morning.')], retired: true), isFalse);
  });

  test('nothing yet, or a turn in flight, is not one message', () {
    expect(_one(const []), isFalse);
    expect(_one([_vana('Morn')], streaming: true), isFalse);
  });
}

/// A moment starts a new exchange mid-thread (vana-moment spec VM-1): the
/// exchange is read from where it starts, and a raised opening is a to-do.
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

    test('a raised opening is a to-do about what raised it', () {
      final raised = VanaExchange.of(
        [...thread, moment],
        isStreaming: false,
        start: 3,
        raisedFor: VanaExchangeTopic.fuelPlan,
      );
      expect(raised.status, VanaExchangeStatus.toDo);
      expect(raised.topic, VanaExchangeTopic.fuelPlan);

      final asked = VanaExchange.of([moment], isStreaming: false);
      expect(asked.status, VanaExchangeStatus.update);
    });

    test('once the athlete answers, the chip reads Vana\'s latest turn', () {
      final exchange = VanaExchange.of(
        [...thread, moment, _athlete('Walk me through it'), _vana('A bagel.')],
        isStreaming: false,
        start: 3,
        raisedFor: VanaExchangeTopic.fuelPlan,
      );
      expect(exchange.status, VanaExchangeStatus.update);
    });
  });
}
