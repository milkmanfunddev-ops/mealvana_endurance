import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_bubble.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_message_card.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_part_renderer.dart';

import '../helpers/test_content.dart';

/// Plan §5 Phase 6.1 — the "Edit" affordance under an athlete turn: shown
/// with a label + callback, hidden while streaming, never on Vana's turns.
void main() {
  final user = VanaMessage(
    id: 'm-2',
    conversationId: 'c1',
    role: VanaMessageRole.user,
    content: 'Cheaper please',
    createdAt: DateTime(2026, 9, 1),
  );
  final assistant = user.copyWith(
    id: 'm-3',
    role: VanaMessageRole.assistant,
    content: 'On it.',
  );

  const callbacks = VanaPartCallbacks(
    onTapMeal: _noop1,
    onPickMeal: _noop2,
    onChipPick: _noop1,
    onSomethingElse: _noop0,
    onAcceptRule: _noop1,
    onViewShopping: _noop0,
  );

  Future<void> pump(
    WidgetTester tester,
    VanaMessage message, {
    String? editLabel = 'Edit',
    void Function(String, String)? onEdit,
    int index = 4,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Scaffold(
            body: VanaMessageCard(
              message: message,
              callbacks: callbacks,
              index: index,
              editLabel: editLabel,
              onEdit: onEdit,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('athlete turn shows Edit and reports id + text', (tester) async {
    final edits = <(String, String)>[];
    await pump(tester, user, onEdit: (id, text) => edits.add((id, text)));
    expect(find.byType(VanaUserBubble), findsOneWidget);
    final edit = find.byKey(const ValueKey('meal_planning.edit_message_4'));
    expect(edit, findsOneWidget);
    await tester.tap(edit);
    expect(edits, [('m-2', 'Cheaper please')]);
  });

  testWidgets('no Edit without a callback (streaming)', (tester) async {
    await pump(tester, user, onEdit: null);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets("Vana's turns never carry Edit", (tester) async {
    await pump(tester, assistant, onEdit: (_, __) {});
    expect(find.text('On it.'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.byType(VanaUserBubble), findsNothing);
  });
}

void _noop0() {}
void _noop1(dynamic _) {}
void _noop2(dynamic _, dynamic __) {}
