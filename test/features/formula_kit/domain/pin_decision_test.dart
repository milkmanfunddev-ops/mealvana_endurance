import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/pin_decision.dart';

void main() {
  group('PinDecision', () {
    group('fromJson — edge function shape (snake_case)', () {
      test('parses used_pin=true with template name', () {
        final decision = PinDecision.fromJson({
          'used_pin': true,
          'pinned_template_id': 'tpl-abc',
          'pinned_template_name': 'Bagel + Jam',
          'fallthrough_reason': null,
        });
        expect(decision.usedPin, isTrue);
        expect(decision.pinnedTemplateId, 'tpl-abc');
        expect(decision.pinnedTemplateName, 'Bagel + Jam');
        expect(decision.fallthroughReason, isNull);
      });

      test('parses used_pin=false with no_pin_for_scope', () {
        final decision = PinDecision.fromJson({
          'used_pin': false,
          'pinned_template_id': null,
          'pinned_template_name': null,
          'fallthrough_reason': 'no_pin_for_scope',
        });
        expect(decision.usedPin, isFalse);
        expect(decision.pinnedTemplateId, isNull);
        expect(decision.pinnedTemplateName, isNull);
        expect(
          decision.fallthroughReason,
          PinFallthroughReason.noPinForScope,
        );
      });

      test('legacy payload without pinned_template_name still parses', () {
        // PR 2 substep 9 added pinned_template_name; older persisted plans
        // may not have it. The parser must default to null, not throw.
        final decision = PinDecision.fromJson({
          'used_pin': true,
          'pinned_template_id': 'tpl-abc',
          'fallthrough_reason': null,
        });
        expect(decision.usedPin, isTrue);
        expect(decision.pinnedTemplateId, 'tpl-abc');
        expect(decision.pinnedTemplateName, isNull);
      });

      test('parses pin_set_size from snake_case', () {
        final decision = PinDecision.fromJson({
          'used_pin': true,
          'pinned_template_id': 'tpl-abc',
          'pinned_template_name': 'Bagel + Jam',
          'fallthrough_reason': null,
          'pin_set_size': 3,
        });
        expect(decision.pinSetSize, 3);
      });

      test('legacy payload without pin_set_size defaults to 0', () {
        // Substep 7 added pin_set_size; plans persisted under substep 9 (or
        // earlier) won't have it. Parser must default to 0, not throw.
        final decision = PinDecision.fromJson({
          'used_pin': true,
          'pinned_template_id': 'tpl-abc',
          'pinned_template_name': 'Bagel + Jam',
          'fallthrough_reason': null,
        });
        expect(decision.pinSetSize, 0);
      });
    });

    group('fromJson — persisted shape (camelCase)', () {
      test('parses round-tripped JSON', () {
        final decision = PinDecision.fromJson({
          'usedPin': true,
          'pinnedTemplateId': 'tpl-xyz',
          'pinnedTemplateName': 'Energy Chews',
          'fallthroughReason': null,
        });
        expect(decision.usedPin, isTrue);
        expect(decision.pinnedTemplateId, 'tpl-xyz');
        expect(decision.pinnedTemplateName, 'Energy Chews');
      });
    });

    group('fromJson — forward compatibility', () {
      test('unknown fallthrough_reason silently parses as null', () {
        // Forward-compat invariant: if the server adds a new fall-through
        // reason and an old client reads the plan, we must NOT throw.
        // Behavior degrades to "no detail" instead of crashing the screen.
        final decision = PinDecision.fromJson({
          'used_pin': false,
          'pinned_template_id': null,
          'pinned_template_name': null,
          'fallthrough_reason': 'some_future_reason_we_dont_know',
        });
        expect(decision.usedPin, isFalse);
        expect(decision.fallthroughReason, isNull);
      });

      test('missing used_pin defaults to false', () {
        final decision = PinDecision.fromJson(<String, dynamic>{});
        expect(decision.usedPin, isFalse);
        expect(decision.pinnedTemplateId, isNull);
        expect(decision.pinnedTemplateName, isNull);
        expect(decision.fallthroughReason, isNull);
      });
    });

    group('toJson', () {
      test('emits snake_case keys matching edge function shape', () {
        const decision = PinDecision(
          usedPin: true,
          pinnedTemplateId: 'tpl-abc',
          pinnedTemplateName: 'Bagel + Jam',
          fallthroughReason: null,
          pinSetSize: 2,
        );
        final json = decision.toJson();
        expect(json['used_pin'], isTrue);
        expect(json['pinned_template_id'], 'tpl-abc');
        expect(json['pinned_template_name'], 'Bagel + Jam');
        expect(json['fallthrough_reason'], isNull);
        expect(json['pin_set_size'], 2);
      });

      test('fallthrough_reason serializes wire value, not enum name', () {
        const decision = PinDecision(
          usedPin: false,
          pinnedTemplateId: null,
          pinnedTemplateName: null,
          fallthroughReason: PinFallthroughReason.noPinForScope,
        );
        final json = decision.toJson();
        expect(json['fallthrough_reason'], 'no_pin_for_scope');
      });
    });

    test('toJson → fromJson round-trip preserves all fields', () {
      const original = PinDecision(
        usedPin: false,
        pinnedTemplateId: null,
        pinnedTemplateName: null,
        fallthroughReason: PinFallthroughReason.noPinForScope,
      );
      final round = PinDecision.fromJson(original.toJson());
      expect(round.usedPin, original.usedPin);
      expect(round.pinnedTemplateId, original.pinnedTemplateId);
      expect(round.pinnedTemplateName, original.pinnedTemplateName);
      expect(round.fallthroughReason, original.fallthroughReason);
    });
  });

  group('PinFallthroughReason.fromWireValue', () {
    test('returns enum for known wire value', () {
      expect(
        PinFallthroughReason.fromWireValue('no_pin_for_scope'),
        PinFallthroughReason.noPinForScope,
      );
    });

    test('returns null for unknown wire value (forward-compat)', () {
      expect(PinFallthroughReason.fromWireValue('totally_new_reason'),
          isNull);
    });

    test('returns null for null input', () {
      expect(PinFallthroughReason.fromWireValue(null), isNull);
    });
  });
}
