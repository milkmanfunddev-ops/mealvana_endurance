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
    expect(_one([_vana('These fit.', [picker])]), isFalse);
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
