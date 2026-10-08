// Ticket 66 (testing-wave develop-2026-10, Finding 49-003, the retest of
// 31-006): Review & Log keeps the athlete's edits.
//
// A swiped-away item was gone with no undo, and Back dropped the rename,
// swaps and removals without asking. Now a removal shows "Item removed" with
// Undo for 3 s (Undo puts it back where it was), and Back with a changed name
// or items asks "Discard changes?". Changing only the meal type does not ask
// (Lee, 2026-10-08).
//
// On the `review_empty_name_test.dart` harness: the analysis is the JSON
// `describe-meal` answers, parsed by the real [MealAnalysisResult.fromJson];
// the real Review & Log screen pushed with constructor params over a host
// route (as Log a Meal → Describe does), the real [MealLogController] and the
// real [MealLogRepository] on an in-memory Drift. Only the wire
// ([MealLogRepository.sendUpsert]) is recorded.
library;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_analysis_result.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/meal_review_screen.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/test_content.dart';
import '../../helpers/widget_test_harness.dart';

const _user = '607f9dd5-6fa7-48ee-a628-720d4a0506a1';
const _logDate = '2026-10-08';

/// A three-item `describe-meal` answer (`MealAnalysisSchema`).
Map<String, dynamic> _describeMealAnswer() => {
  'name': 'Eggs, toast and a banana',
  'suggested_slot': 'breakfast',
  'confidence': 'medium',
  'items': [
    {
      'name': 'Scrambled eggs',
      'portion': '2 large eggs',
      'calories': 182,
      'carb_g': 1.2,
      'protein_g': 12.6,
      'fat_g': 13.8,
      'sodium_mg': 189,
    },
    {
      'name': 'Whole wheat toast',
      'portion': '1 slice with butter',
      'calories': 150,
      'carb_g': 14.0,
      'protein_g': 4.0,
      'fat_g': 8.0,
      'sodium_mg': 180,
    },
    {
      'name': 'Banana',
      'portion': '1 medium',
      'calories': 105,
      'carb_g': 27.0,
      'protein_g': 1.3,
      'fat_g': 0.4,
      'sodium_mg': 1,
    },
  ],
  'totals': {
    'calories': 437,
    'carb_g': 42.2,
    'protein_g': 17.9,
    'fat_g': 22.2,
    'sodium_mg': 370,
  },
  '_usage': {'input_tokens': 900, 'output_tokens': 200, 'model': 'sonnet'},
};

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockUserRepo extends Mock implements UserRepository {}

class _MockUser extends Mock implements UserProfile {}

/// The real repository; the wire records what it would send.
class _RecordingRepository extends MealLogRepository {
  _RecordingRepository({required super.database})
    : super(supabase: _MockSupabaseClient(), report: const NoopReport());

  final sent = <List<Map<String, dynamic>>>[];

  @override
  Future<void> sendUpsert(
    List<Map<String, dynamic>> rows, {
    bool ignoreDuplicates = false,
  }) async {
    sent.add(rows);
  }
}

/// What the host's `push` future completed with.
class _Popped {
  bool done = false;
  bool? value;
}

void main() {
  late AppDatabase db;
  late _RecordingRepository repo;

  final content = loadDefaultContent();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = _RecordingRepository(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Pumps the host and opens Review over it, as Describe does.
  Future<_Popped> openReview(WidgetTester tester) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final user = _MockUser();
    when(() => user.id).thenReturn(_user);
    final users = _MockUserRepo();
    when(() => users.getCurrentUser()).thenAnswer((_) async => user);

    final result = MealAnalysisResult.fromJson(_describeMealAnswer());
    final popped = _Popped();
    final router = GoRouter(
      initialLocation: '/main',
      routes: [
        GoRoute(
          path: '/main',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final value = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/meal-log/review'),
                    builder: (_) => MealReviewScreen(
                      result: result,
                      source: 'describe',
                      logDate: _logDate,
                    ),
                  ),
                );
                popped
                  ..done = true
                  ..value = value;
              },
              child: const Text('open review'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          contentServiceProvider.overrideWith(testContentService),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          mealLogRepositoryProvider.overrideWithValue(repo),
          savedMealsRepositoryProvider.overrideWithValue(
            SavedMealsRepository(
              supabase: _MockSupabaseClient(),
              database: db,
              report: const NoopReport(),
            ),
          ),
          userRepositoryProvider.overrideWith((ref) async => users),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('open review'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(MealReviewScreen), findsOneWidget);
    return popped;
  }

  Finder total(int kcal) => find.textContaining('$kcal kcal  C');

  Future<void> swipeRemove(WidgetTester tester, String name) async {
    await tester.drag(find.text(name), const Offset(500, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Lets a 3 s Undo bar time out and leave, so no timer outlives the test.
  Future<void> letBarTimeOut(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> tapAppBarBack(WidgetTester tester) async {
    await tester.tap(find.byType(CustomAppBarBackButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  final removed = content['meal_log.review.item_removed']!;
  final undo = content['meal_log_actions.undo']!;
  final discardTitle = content['meal_log.review.discard_title']!;
  final keepEditing = content['meal_log.review.keep_editing']!;
  final discard = content['meal_log.review.discard']!;

  testWidgets('a removed item shows Undo; Undo puts it back second and the '
      'total returns; a bar left alone times out and the item stays gone', (
    tester,
  ) async {
    expect(removed, 'Item removed');
    expect(undo, 'Undo');
    await openReview(tester);
    expect(total(437), findsOneWidget);

    await swipeRemove(tester, 'Whole wheat toast');
    expect(find.text('Whole wheat toast'), findsNothing);
    expect(total(287), findsOneWidget);
    expect(find.text(removed), findsOneWidget);
    expect(find.text(undo), findsOneWidget);

    await tester.tap(find.text(undo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(total(437), findsOneWidget);
    final eggsY = tester.getTopLeft(find.text('Scrambled eggs')).dy;
    final toastY = tester.getTopLeft(find.text('Whole wheat toast')).dy;
    final bananaY = tester.getTopLeft(find.text('Banana')).dy;
    expect(eggsY < toastY && toastY < bananaY, isTrue, reason: 'back second');

    // Swipe again and leave the bar: after 3 s it is gone, the item too.
    await swipeRemove(tester, 'Whole wheat toast');
    expect(find.text(removed), findsOneWidget);
    await letBarTimeOut(tester);
    expect(find.text(removed), findsNothing);
    expect(find.text('Whole wheat toast'), findsNothing);
    expect(total(287), findsOneWidget);
  });

  testWidgets('Back after a rename asks; Keep editing stays with the name; '
      'Discard pops with null', (tester) async {
    final popped = await openReview(tester);
    expect(discardTitle, 'Discard changes?');

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Meal name'),
      'Breakfast plate',
    );
    await tester.pump();

    await tapAppBarBack(tester);
    expect(find.text(discardTitle), findsOneWidget);
    expect(find.text(content['meal_log.review.discard_body']!), findsOneWidget);
    expect(find.text(keepEditing), findsOneWidget);
    expect(find.text(discard), findsOneWidget);

    await tester.tap(find.text(keepEditing));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(discardTitle), findsNothing);
    expect(find.byType(MealReviewScreen), findsOneWidget);
    expect(find.text('Breakfast plate'), findsOneWidget);
    expect(popped.done, isFalse);

    await tapAppBarBack(tester);
    await tester.tap(find.text(discard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MealReviewScreen), findsNothing);
    expect(popped.done, isTrue);
    expect(popped.value, isNull);
  });

  testWidgets('Back with no edits pops at once with no dialog', (tester) async {
    final popped = await openReview(tester);

    await tapAppBarBack(tester);
    expect(find.text(discardTitle), findsNothing);
    expect(find.byType(MealReviewScreen), findsNothing);
    expect(popped.done, isTrue);
    expect(popped.value, isNull);
  });

  testWidgets('remove then Undo, then Back: no dialog', (tester) async {
    final popped = await openReview(tester);

    await swipeRemove(tester, 'Banana');
    await tester.tap(find.text(undo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(total(437), findsOneWidget);

    await tapAppBarBack(tester);
    expect(find.text(discardTitle), findsNothing);
    expect(popped.done, isTrue);
    expect(popped.value, isNull);
  });

  testWidgets('a removal alone asks on Back; Discard also takes the Undo bar '
      'away, so it cannot act on a gone screen', (tester) async {
    final popped = await openReview(tester);

    await swipeRemove(tester, 'Banana');
    expect(find.text(removed), findsOneWidget);

    await tapAppBarBack(tester);
    expect(find.text(discardTitle), findsOneWidget);
    expect(popped.done, isFalse);
    await tester.tap(find.text(discard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(popped.done, isTrue);
    expect(popped.value, isNull);
    expect(find.byType(MealReviewScreen), findsNothing);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(removed), findsNothing);
    expect(find.text(undo), findsNothing);
  });

  testWidgets('changing only the meal type does not ask (Lee, 2026-10-08)', (
    tester,
  ) async {
    final popped = await openReview(tester);

    // The AI suggested breakfast; pick another slot.
    await tester.tap(find.text('Lunch'));
    await tester.pump();

    await tapAppBarBack(tester);
    expect(find.text(discardTitle), findsNothing);
    expect(popped.done, isTrue);
  });

  testWidgets('Log this meal after edits pops true with no dialog and writes '
      'a meal_logs row', (tester) async {
    final popped = await openReview(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Meal name'),
      'Breakfast plate',
    );
    await tester.pump();
    await swipeRemove(tester, 'Banana');
    // The floating bar sits over the button; let it go first.
    await letBarTimeOut(tester);

    await tester.ensureVisible(find.text('Log this meal'));
    await tester.tap(find.text('Log this meal'));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(discardTitle), findsNothing);
    expect(find.byType(MealReviewScreen), findsNothing);
    expect(popped.done, isTrue);
    expect(popped.value, isTrue);

    final rows = await tester.runAsync(() => repo.getRecentLogs(_user));
    expect(rows, hasLength(1));
    expect(rows!.single.name, 'Breakfast plate');
    expect(rows.single.components, hasLength(2));
  });
}
