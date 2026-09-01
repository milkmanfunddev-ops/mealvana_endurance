/// VanaChatRepository / VanaTransport against a fake HTTP client, using the
/// contract fixtures' NDJSON lines (contract-v1). Also the history row
/// parser (`parts` first, `content + metadata.ui_parts` fallback).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/insufficient_credits_exception.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_chat_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';

import '../domain/fixture_helpers.dart';
import '../helpers/fakes.dart';

VanaChatRepository _repo(TransportHarness h, {String fn = 'vana-chat'}) =>
    VanaChatRepository(
      transport: h.transport,
      supabase: h.supabase,
      logger: h.logger,
      functionName: fn,
    );

void main() {
  group('streamChat', () {
    test(
      'opener fixture: every line type parses in order, header captured',
      () async {
        final fixture = loadFixture('opener');
        final h = TransportHarness(
          status: 200,
          body: ndjsonFromFixture(fixture),
          headers: Map<String, String>.from(fixture['headers'] as Map),
        );

        final response = await _repo(h).streamChat(
          kind: VanaConversationKind.mealPlanning,
          opener: true,
          anchorDate: '2026-09-01',
          timezone: 'America/Chicago',
        );

        expect(
          response.conversationId,
          fixture['headers']['x-conversation-id'],
        );
        expect(response.kind, VanaConversationKind.mealPlanning);

        final events = await response.events.toList();
        final expectedLines = fixture['lines'] as List;
        expect(events.length, expectedLines.length);
        expect(events.first, isA<VanaStatusEvent>());
        expect((events.first as VanaStatusEvent).tool, 'suggestMeals');
        final picker = events.whereType<VanaUiEvent>().first.part;
        expect(picker, isA<VanaMealPickerPart>());
        expect((picker as VanaMealPickerPart).meals.length, 3);
        expect(events.last, isA<VanaDoneEvent>());
        expect((events.last as VanaDoneEvent).inputTokens, isNotNull);

        // Request body is the contract's wire shape.
        final req = h.requests.single;
        expect(req.path, '/functions/v1/vana-chat');
        expect(req.request.headers['Authorization'], 'Bearer test-token');
        expect(req.body, {
          'kind': 'meal_planning',
          'opener': true,
          'anchor_date': '2026-09-01',
          'timezone': 'America/Chicago',
        });
      },
    );

    test(
      'general_turn fixture: text deltas + block separator + status',
      () async {
        final fixture = loadFixture('general_turn');
        final h = TransportHarness(
          status: 200,
          body: ndjsonFromFixture(fixture),
          headers: Map<String, String>.from(fixture['headers'] as Map),
        );
        final response = await _repo(h).streamChat(
          message: 'What should I eat before tomorrow?',
          conversationId: 'conv-1',
          kind: VanaConversationKind.general,
        );
        expect(response.kind, VanaConversationKind.general);
        final events = await response.events.toList();
        final text = events
            .whereType<VanaTextEvent>()
            .map((e) => e.delta)
            .join();
        expect(text, contains("I'll pull"));
        expect(text, contains('\n'));
        expect(events.whereType<VanaStatusEvent>().map((e) => e.tool), [
          'getProfile',
          'getWorkouts',
          'getMacroTargets',
        ]);
        expect(h.requests.single.body['conversation_id'], 'conv-1');
        expect(
          h.requests.single.body['message'],
          'What should I eat before tomorrow?',
        );
      },
    );

    test('unknown line types and unknown part kinds are dropped', () async {
      final body = [
        '{"type":"text","delta":"Hi"}',
        '{"type":"hologram","x":1}',
        '{"type":"ui","part":{"kind":"unknown_kind"}}',
        'not json at all',
        '{"type":"done"}',
      ].join('\n');
      final h = TransportHarness(status: 200, body: body);
      final response = await _repo(
        h,
      ).streamChat(message: 'hi', kind: VanaConversationKind.general);
      final events = await response.events.toList();
      expect(events.map((e) => e.type), ['text', 'done']);
    });

    test('403 pro_required → ProRequiredException', () async {
      final h = TransportHarness(status: 403, body: '{"error":"pro_required"}');
      expect(
        () => _repo(
          h,
        ).streamChat(message: 'hi', kind: VanaConversationKind.general),
        throwsA(
          isA<ProRequiredException>().having(
            (e) => e.reason,
            'reason',
            'pro_required',
          ),
        ),
      );
    });

    test(
      '429 rate_limited → VanaRateLimitedException with retry_after_seconds',
      () async {
        final h = TransportHarness(
          status: 429,
          body: '{"error":"rate_limited","retry_after_seconds":7}',
        );
        expect(
          () => _repo(
            h,
          ).streamChat(message: 'hi', kind: VanaConversationKind.general),
          throwsA(
            isA<VanaRateLimitedException>().having(
              (e) => e.retryAfterSeconds,
              'retry',
              7,
            ),
          ),
        );
      },
    );

    test(
      '401 → VanaUnauthenticatedException; no session → same, without a request',
      () async {
        final h = TransportHarness(
          status: 401,
          body: '{"error":"unauthenticated"}',
        );
        expect(
          () => _repo(
            h,
          ).streamChat(message: 'hi', kind: VanaConversationKind.general),
          throwsA(isA<VanaUnauthenticatedException>()),
        );
        final signedOut = TransportHarness(
          status: 200,
          body: '',
          signedIn: false,
        );
        await expectLater(
          () => _repo(
            signedOut,
          ).streamChat(message: 'hi', kind: VanaConversationKind.general),
          throwsA(isA<VanaUnauthenticatedException>()),
        );
        expect(signedOut.requests, isEmpty);
      },
    );

    test('402 → InsufficientCreditsException (jade-chat)', () async {
      final h = TransportHarness(
        status: 402,
        body:
            '{"error":"insufficient_credits","message":"Out","balance":1,"cost":3}',
      );
      expect(
        () => _repo(
          h,
          fn: 'jade-chat',
        ).streamChat(message: 'hi', kind: VanaConversationKind.general),
        throwsA(
          isA<InsufficientCreditsException>().having(
            (e) => e.balance,
            'balance',
            1,
          ),
        ),
      );
    });

    test(
      '500 → VanaServerException; socket failure → VanaOfflineException',
      () async {
        final h = TransportHarness(status: 500, body: 'oops');
        expect(
          () => _repo(
            h,
          ).streamChat(message: 'hi', kind: VanaConversationKind.general),
          throwsA(
            isA<VanaServerException>().having(
              (e) => e.statusCode,
              'status',
              500,
            ),
          ),
        );
        final offline = TransportHarness(
          status: 200,
          body: '',
          throwOnSend: Exception('no route'),
        );
        expect(
          () => _repo(
            offline,
          ).streamChat(message: 'hi', kind: VanaConversationKind.general),
          throwsA(isA<VanaOfflineException>()),
        );
      },
    );
  });

  group('messageFromRow', () {
    test(
      'prefers parts: text blocks joined, tool outputs become VanaParts',
      () {
        final picker = loadFixture('meal_picker'); // the part itself
        final row = {
          'id': 'm-1',
          'conversation_id': 'c-1',
          'role': 'assistant',
          'content': 'legacy content',
          'metadata': {
            'ui_parts': [
              {
                'kind': 'choices',
                'options': ['A', 'B'],
              },
            ],
          },
          'parts': [
            {'type': 'text', 'text': 'Three dinners to start.'},
            {
              'type': 'tool-suggestMeals',
              'state': 'output-available',
              'input': {},
              'output': picker,
            },
            {'type': 'text', 'text': 'Pick what you like.'},
          ],
          'created_at': '2026-09-01T12:00:00Z',
        };
        final m = VanaChatRepository.messageFromRow(row)!;
        expect(m.role, VanaMessageRole.assistant);
        expect(m.content, 'Three dinners to start.\nPick what you like.');
        expect(m.parts.single, isA<VanaMealPickerPart>());
        expect(m.createdAt.toUtc().hour, 12);
      },
    );

    test('falls back to content + metadata.ui_parts', () {
      final row = {
        'id': 'm-2',
        'conversation_id': 'c-1',
        'role': 'assistant',
        'content': 'Hello',
        'metadata': {
          'ui_parts': [
            {
              'kind': 'choices',
              'options': ['Start a meal plan', 'Not now'],
            },
          ],
        },
        'parts': null,
        'created_at': '2026-09-01T12:00:00Z',
      };
      final m = VanaChatRepository.messageFromRow(row)!;
      expect(m.content, 'Hello');
      expect((m.parts.single as VanaChoicesPart).options, [
        'Start a meal plan',
        'Not now',
      ]);
    });

    test('user rows carry only content', () {
      final m = VanaChatRepository.messageFromRow({
        'id': 'u-1',
        'conversation_id': 'c-1',
        'role': 'user',
        'content': 'Plan my week',
        'parts': [
          {'type': 'text', 'text': 'Plan my week'},
        ],
        'created_at': '2026-09-01T12:00:00Z',
      })!;
      expect(m.isUser, isTrue);
      expect(m.content, 'Plan my week');
      expect(m.parts, isEmpty);
    });

    test('rows without id/role are skipped', () {
      expect(VanaChatRepository.messageFromRow({'content': 'x'}), isNull);
    });
  });

  test('resolveTimezone returns IANA names as-is and Etc/GMT otherwise', () {
    final tz = VanaChatRepository.resolveTimezone();
    expect(tz, anyOf(contains('/'), equals('UTC')));
    expect(jsonEncode(tz), isNotEmpty);
  });
}
