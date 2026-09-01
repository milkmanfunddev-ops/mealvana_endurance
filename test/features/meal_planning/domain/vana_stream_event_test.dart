import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';

void main() {
  group('VanaStreamEvent.fromJsonLine', () {
    test('text', () {
      final e = VanaStreamEvent.fromJsonLine('{"type":"text","delta":"Hi "}');
      expect(e, isA<VanaTextEvent>());
      expect((e as VanaTextEvent).delta, 'Hi ');
      expect(e.isBlockSeparator, isFalse);
      expect(e.toJson(), {'type': 'text', 'delta': 'Hi '});
    });

    test('text block separator', () {
      final e = VanaStreamEvent.fromJsonLine(r'{"type":"text","delta":"\n"}');
      expect((e as VanaTextEvent).isBlockSeparator, isTrue);
    });

    test('ui', () {
      final e = VanaStreamEvent.fromJsonLine(
        '{"type":"ui","part":{"kind":"choices","question":"Batch cook?","options":["Yes","No"]}}',
      );
      expect(e, isA<VanaUiEvent>());
      final part = (e as VanaUiEvent).part;
      expect(part, isA<VanaChoicesPart>());
      expect((part as VanaChoicesPart).options, ['Yes', 'No']);
      expect(e.toJson()['part'], part.toJson());
    });

    test('ui with an unknown part kind is dropped', () {
      expect(
        VanaStreamEvent.fromJsonLine(
          '{"type":"ui","part":{"kind":"hologram"}}',
        ),
        isNull,
      );
    });

    test('ui without a part is dropped', () {
      expect(VanaStreamEvent.fromJsonLine('{"type":"ui"}'), isNull);
    });

    test('status', () {
      final e = VanaStreamEvent.fromJsonLine(
        '{"type":"status","tool":"suggestMeals"}',
      );
      expect((e as VanaStatusEvent).tool, 'suggestMeals');
      expect(e.toJson(), {'type': 'status', 'tool': 'suggestMeals'});
    });

    test('done', () {
      final e = VanaStreamEvent.fromJsonLine(
        '{"type":"done","usage":{"input_tokens":11764,"output_tokens":181}}',
      );
      expect(e, isA<VanaDoneEvent>());
      final done = e as VanaDoneEvent;
      expect(done.inputTokens, 11764);
      expect(done.outputTokens, 181);
      expect(done.toJson(), {
        'type': 'done',
        'usage': {'input_tokens': 11764, 'output_tokens': 181},
      });
    });

    test('done with null usage', () {
      final e = VanaStreamEvent.fromJsonLine(
        '{"type":"done","usage":{"input_tokens":null,"output_tokens":null}}',
      );
      final done = e as VanaDoneEvent;
      expect(done.inputTokens, isNull);
      expect(done.outputTokens, isNull);
    });

    test('done without usage', () {
      final done =
          VanaStreamEvent.fromJsonLine('{"type":"done"}') as VanaDoneEvent;
      expect(done.inputTokens, isNull);
    });

    test('error', () {
      final e = VanaStreamEvent.fromJsonLine(
        '{"type":"error","message":"rate_limited"}',
      );
      expect((e as VanaErrorEvent).message, 'rate_limited');
      expect(e.toJson(), {'type': 'error', 'message': 'rate_limited'});
    });

    test('blank and whitespace lines → null', () {
      expect(VanaStreamEvent.fromJsonLine(''), isNull);
      expect(VanaStreamEvent.fromJsonLine('   \n'), isNull);
    });

    test('non-JSON and non-object lines → null', () {
      expect(VanaStreamEvent.fromJsonLine('not json'), isNull);
      expect(VanaStreamEvent.fromJsonLine('[1,2]'), isNull);
      expect(VanaStreamEvent.fromJsonLine('"text"'), isNull);
    });

    test('unknown type → null', () {
      expect(
        VanaStreamEvent.fromJsonLine('{"type":"reasoning","delta":"…"}'),
        isNull,
      );
      expect(VanaStreamEvent.fromJsonLine('{"delta":"no type"}'), isNull);
    });

    test('tolerates trailing whitespace / CR', () {
      expect(
        VanaStreamEvent.fromJsonLine('{"type":"text","delta":"x"}\r'),
        isA<VanaTextEvent>(),
      );
    });

    test('events are value-equal', () {
      expect(
        VanaStreamEvent.fromJsonLine('{"type":"text","delta":"x"}'),
        equals(const VanaTextEvent('x')),
      );
      expect(
        const VanaDoneEvent(inputTokens: 1, outputTokens: 2),
        isNot(equals(const VanaDoneEvent(inputTokens: 1, outputTokens: 3))),
      );
    });
  });

  group('VanaPart.fromJson', () {
    test('unknown kind → null', () {
      expect(VanaPart.fromJson({'kind': 'nope'}), isNull);
      expect(VanaPart.fromJson({}), isNull);
    });

    test('malformed known kind → null instead of throwing', () {
      expect(VanaPart.fromJson({'kind': 'batch'}), isNull);
      expect(VanaPart.fromJson({'kind': 'batch', 'plan': 'x'}), isNull);
      expect(VanaPart.fromJson({'kind': 'logged'}), isNull);
    });

    test('brief is parsed (legacy) but tagged as such', () {
      final p = VanaPart.fromJson({
        'kind': 'brief',
        'text': 'Rest week.',
        'chips': ['ok'],
        'cites': [],
      });
      expect(p, isA<VanaBriefPart>());
      expect(p!.kind, 'brief');
    });

    test('listFromJson drops unknown entries and non-maps', () {
      final parts = VanaPart.listFromJson([
        {
          'kind': 'choices',
          'options': ['a', 'b'],
        },
        {'kind': 'future'},
        'junk',
        null,
        {
          'kind': 'logged',
          'planMealId': 'pm1',
          'name': 'Chili',
          'servingsLeft': 3,
        },
      ]);
      expect(parts, hasLength(2));
      expect(parts[0], isA<VanaChoicesPart>());
      expect(parts[1], isA<VanaLoggedPart>());
    });

    test('every kind is covered by the sealed switch', () {
      const kinds = [
        'choices',
        'meal_picker',
        'staples',
        'batch',
        'rule',
        'shopping_list',
        'day_guidance',
        'memory_saved',
        'logged',
        'day',
        'brief',
      ];
      // Minimal valid payloads per kind.
      final samples = <String, Map<String, dynamic>>{
        'choices': {
          'options': ['a'],
        },
        'meal_picker': {'title': 't', 'meals': []},
        'staples': {'meals': []},
        'batch': {
          'plan': {'id': 'p', 'weekStart': '2026-08-31', 'status': 'draft'},
        },
        'rule': {
          'rule': {'day': 'mon', 'rule': 'r', 'accepted': false},
        },
        'shopping_list': {'items': [], 'itemCount': 0, 'skipped': []},
        'day_guidance': {'date': '2026-09-01', 'minCarbsG': 1, 'note': ''},
        'memory_saved': {
          'memory': {
            'id': 'm',
            'kind': 'setting',
            'fact': 'f',
            'confidence': 1,
            'lastConfirmedAt': 'x',
          },
        },
        'logged': {'planMealId': 'pm', 'name': 'n', 'servingsLeft': 0},
        'day': {'date': '2026-09-01', 'label': '', 'slots': {}, 'filled': []},
        'brief': {'text': ''},
      };
      for (final kind in kinds) {
        final part = VanaPart.fromJson({'kind': kind, ...samples[kind]!});
        expect(part, isNotNull, reason: kind);
        expect(part!.kind, kind);
        expect(part.toJson()['kind'], kind);
      }
    });

    test('batch without coverage computes it locally', () {
      final part =
          VanaPart.fromJson({
                'kind': 'batch',
                'plan': {
                  'id': 'p',
                  'weekStart': '2026-08-31',
                  'status': 'draft',
                  'meals': [
                    {
                      'id': 'pm',
                      'planId': 'p',
                      'source': 'library',
                      'name': 'Chili',
                      'mealType': 'dinner',
                      'servings': 4,
                      'servingsLeft': 4,
                      'kcal': 700,
                    },
                  ],
                },
              })
              as VanaBatchPart;
      expect(part.plan.coverage.covered, 4);
      expect(part.plan.coverage.perDay.kcal, 400);
    });
  });
}
