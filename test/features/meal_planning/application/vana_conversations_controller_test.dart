/// `VanaConversationsController` through the real notifier against a
/// stand-in for `vana-action` answering `list_conversations` in the
/// server's own shape (ticket 126: Findings 88-002, 89-007, 88-021).
///
/// - 88-002 / 89-007: each planning row carries the plan the server picked
///   for it, so the list titles a row the way the opened chat's header does
///   ("Sep 13 week · Confirmed"), never "No plan yet" fifteen times over.
/// - 88-021: the list pages by offset; a second page appends without a
///   duplicate, and an under-full page stops the asking.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_conversations_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan_status.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/plan_conversation_title.dart';

import '../helpers/container.dart';
import '../presentation/helpers/test_content.dart';

/// A `vana_conversations` row as `listConversations` in `chat.ts` emits it
/// (`ConversationSummary`, camelCase, `plan` picked server-side).
Map<String, dynamic> row(
  String id, {
  String kind = 'meal_planning',
  Map<String, dynamic>? plan,
  String? title,
}) => {
  'id': id,
  'kind': kind,
  'title': title,
  'summary': null,
  'lastMessageAt': '2026-09-20T09:00:00Z',
  'createdAt': '2026-09-20T08:00:00Z',
  'plan': plan,
};

/// `vana-action` answering `list_conversations` from [all], one page per
/// call, the way `range(offset, offset + limit - 1)` slices it.
class _ListServer extends Fake implements VanaActionClient {
  _ListServer(this.all);

  final List<Map<String, dynamic>> all;
  final List<ListConversationsAction> calls = [];

  @override
  Future<VanaActionResult> run(UiAction action) async {
    if (action is! ListConversationsAction) {
      throw UnimplementedError(action.type);
    }
    calls.add(action);
    final rows = all
        .where((r) => r['kind'] == action.kind.wire)
        .skip(action.offset)
        .take(action.limit)
        .toList();
    return VanaActionResult.fromJson({'parts': [], 'conversations': rows});
  }
}

void main() {
  const pageSize = VanaConversationsController.pageSize;

  ProviderContainer makeContainer(_ListServer server) => testContainer([
    ...baseOverrides(),
    vanaActionClientProvider.overrideWithValue(server),
    contentServiceProvider.overrideWith(testContentService),
  ]);

  test(
    'each row is titled by the plan the server picked, as the chat header titles it',
    () async {
      final server = _ListServer([
        row(
          'conv-confirmed',
          plan: {
            'weekStart': '2026-09-13',
            'status': 'confirmed',
            'mealCount': 4,
          },
        ),
        row(
          'conv-archived',
          plan: {
            'weekStart': '2026-09-06',
            'status': 'archived',
            'mealCount': 1,
          },
        ),
        row(
          'conv-draft',
          plan: {'weekStart': '2026-09-20', 'status': 'draft', 'mealCount': 2},
        ),
        row(
          'conv-empty-draft',
          plan: {'weekStart': '2026-09-20', 'status': 'draft', 'mealCount': 0},
        ),
        row('conv-none'),
        row('conv-general', kind: 'general', title: 'Quick question'),
      ]);
      final c = makeContainer(server);
      final content = c.read(contentServiceProvider);

      final rows = await c.read(
        vanaConversationsControllerProvider(
          VanaConversationKind.mealPlanning,
        ).future,
      );

      expect(server.calls.single.toJson(), {
        'type': 'list_conversations',
        'payload': {'kind': 'meal_planning', 'limit': pageSize, 'offset': 0},
      });
      expect(rows.map((r) => r.id), [
        'conv-confirmed',
        'conv-archived',
        'conv-draft',
        'conv-empty-draft',
        'conv-none',
      ]);
      expect(rows.map((r) => planConversationTitle(content, r)), [
        'Sep 13 week · Confirmed',
        'Sep 6 week · Archived',
        'Sep 20 week · Draft',
        'No plan yet',
        'No plan yet',
      ]);
      // The header's own title, from the plan's fields, agrees row by row.
      expect(
        planTitle(
          content,
          weekStart: '2026-09-13',
          status: MealPlanStatus.confirmed,
          mealCount: 4,
        ),
        planConversationTitle(content, rows[0]),
      );
      expect(rows[1].plan?.status, MealPlanStatus.archived);
      expect(rows[4].plan, isNull);
    },
  );

  test('the general list asks for its own kind', () async {
    final server = _ListServer([
      row('conv-plan'),
      row('conv-general', kind: 'general', title: 'Quick question'),
    ]);
    final c = makeContainer(server);

    final rows = await c.read(
      vanaConversationsControllerProvider(VanaConversationKind.general).future,
    );

    expect(rows.single.id, 'conv-general');
    expect(rows.single.title, 'Quick question');
    expect(server.calls.single.kind, VanaConversationKind.general);
  });

  group('paging (88-021)', () {
    List<Map<String, dynamic>> many(int n) => [
      for (var i = 0; i < n; i++) row('conv-${i.toString().padLeft(3, '0')}'),
    ];

    test(
      'a full first page asks again on loadMore; the second page appends without a duplicate',
      () async {
        // 80 rows, like test@test.com's account: 50 + 30.
        final server = _ListServer(many(80));
        final c = makeContainer(server);
        final provider = vanaConversationsControllerProvider(
          VanaConversationKind.mealPlanning,
        );

        final first = await c.read(provider.future);
        expect(first.length, pageSize);
        expect(c.read(provider.notifier).hasMore, isTrue);

        // A conversation that gained a message between the pages moves to
        // the top of the server's order, so the second page repeats one
        // the list already shows.
        server.all.insert(0, server.all.removeAt(60));
        await c.read(provider.notifier).loadMore();

        final second = c.read(provider).requireValue;
        expect(server.calls.map((a) => a.offset), [0, pageSize]);
        expect(second.length, 80 - 1);
        expect(second.map((r) => r.id).toSet().length, second.length);
        expect(second.first.id, 'conv-000');
        expect(second.last.id, 'conv-079');
        // 30 rows came back: under a full page, so the list is done.
        expect(c.read(provider.notifier).hasMore, isFalse);
      },
    );

    test('an under-full page is the end: loadMore asks for nothing', () async {
      final server = _ListServer(many(3));
      final c = makeContainer(server);
      final provider = vanaConversationsControllerProvider(
        VanaConversationKind.mealPlanning,
      );

      await c.read(provider.future);
      expect(c.read(provider.notifier).hasMore, isFalse);

      await c.read(provider.notifier).loadMore();
      expect(server.calls.length, 1);
      expect(c.read(provider).requireValue.length, 3);
    });

    test(
      'an exactly full list asks once more and gets an empty page',
      () async {
        final server = _ListServer(many(pageSize));
        final c = makeContainer(server);
        final provider = vanaConversationsControllerProvider(
          VanaConversationKind.mealPlanning,
        );

        await c.read(provider.future);
        expect(c.read(provider.notifier).hasMore, isTrue);

        await c.read(provider.notifier).loadMore();
        expect(server.calls.map((a) => a.offset), [0, pageSize]);
        expect(c.read(provider).requireValue.length, pageSize);
        expect(c.read(provider.notifier).hasMore, isFalse);

        await c.read(provider.notifier).loadMore();
        expect(server.calls.length, 2);
      },
    );

    test('refresh starts over from the first page', () async {
      final server = _ListServer(many(60));
      final c = makeContainer(server);
      final provider = vanaConversationsControllerProvider(
        VanaConversationKind.mealPlanning,
      );

      await c.read(provider.future);
      await c.read(provider.notifier).loadMore();
      expect(c.read(provider).requireValue.length, 60);
      expect(c.read(provider.notifier).hasMore, isFalse);

      await c.read(provider.notifier).refresh();
      expect(server.calls.last.offset, 0);
      expect(c.read(provider).requireValue.length, pageSize);
      expect(c.read(provider.notifier).hasMore, isTrue);
    });
  });
}
