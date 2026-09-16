// A plan's rows show the library Meal's photo, or nothing (ADR 0003, mp-324).
//
// The plan meals come from `plan_meals`-shaped server rows through the real
// repository mapping and a real Drift database, and the photographs from
// `meal_library`-shaped rows through the real photo mapping — the plan row
// itself gains no picture fields, so what is under test is the join.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_plan_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_photo.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/plan_bar.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/plan_list.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/plan_tile.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/review_sheet.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes.dart';
import '../helpers/test_content.dart';

const _user = 'user-1';
const _week = '2026-09-13';
final _now = DateTime.utc(2026, 9, 14, 12);

/// The avocado toast's photo — a Wikimedia file mirrored into our storage.
const _avocado = 'https://upload.wikimedia.org/avocado.jpg';
const _credit = 'Photo by Jami430 on Wikimedia Commons (CC BY-SA 4.0)';

Map<String, dynamic> _planRow() => {
  'id': 'plan-1',
  'user_id': _user,
  'week_start': _week,
  'status': 'draft',
  // Flat, so the review sheet lists the rows in plan order rather than
  // grouping them by cooking session.
  'batch_cooking': false,
  'rules': const <Object>[],
  'shopping': const <Object>[],
  'brief': null,
  'conversation_id': null,
  'days': const <String, Object>{},
  'day_notes': const <String, Object>{},
  'day_notes_stale': false,
  'created_at': _now.toIso8601String(),
  'updated_at': _now.toIso8601String(),
  'is_deleted': false,
};

Map<String, dynamic> _mealRow({
  required String id,
  required String name,
  required int position,
  String source = 'library',
  String? libraryMealId,
  String? savedMealId,
}) => {
  'id': id,
  'plan_id': 'plan-1',
  'user_id': _user,
  'source': source,
  'library_meal_id': libraryMealId,
  'saved_meal_id': savedMealId,
  'name': name,
  'meal_type': 'dinner',
  'session': null,
  'servings': 4,
  'servings_left': 4,
  'kcal': 520,
  'carbs_g': 60.0,
  'protein_g': 30.0,
  'fat_g': 18.0,
  'swaps_applied': const <Object>[],
  'comments': const <Object>[],
  'position': position,
  'icon': 'fish',
  'created_at': _now.toIso8601String(),
  'updated_at': _now.toIso8601String(),
  'is_deleted': false,
};

/// A `meal_library` row as the photo read selects it.
Map<String, dynamic> _libraryRow(
  String id, {
  String? photoUrl,
  String? credit,
  String? creditUrl,
}) => {
  'id': id,
  'photo_url': photoUrl,
  'photo_credit': credit,
  'photo_credit_url': creditUrl,
};

/// Answers the photo read from `meal_library`-shaped rows, through the real
/// mapping, and records what it was asked for.
class _FakeLibraryPhotos extends Fake implements MealLibraryRemoteDataSource {
  _FakeLibraryPhotos(this.rows);

  final List<Map<String, dynamic>> rows;
  final List<List<String>> asked = [];

  @override
  Future<Map<String, MealPhoto>> photosForMeals(
    Iterable<String> libraryMealIds,
  ) async {
    final want = libraryMealIds.toSet();
    asked.add(want.toList()..sort());
    final out = <String, MealPhoto>{};
    for (final row in rows) {
      final id = row['id'] as String;
      if (!want.contains(id)) continue;
      if (MealPhoto.fromRow(row) case final photo?) out[id] = photo;
    }
    return out;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MealPlanRepository repo;
  late RecordingMealPlanRemote remote;
  late _FakeLibraryPhotos photos;
  late MealPlan plan;
  late Uint8List imageBytes;

  setUpAll(() async => imageBytes = await _pngBytes());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    remote = RecordingMealPlanRemote();
    repo = MealPlanRepository(
      database: db,
      logger: FakeLogger(),
      remote: remote,
    );

    remote.plans = [_planRow()];
    remote.meals = [
      // AB-001 has a photo; AB-002 is in the library with none; the third row
      // is the athlete's own meal, never matched to a library Meal.
      _mealRow(
        id: 'pm-1',
        name: 'Avocado toast',
        position: 0,
        libraryMealId: 'AB-001',
      ),
      _mealRow(
        id: 'pm-2',
        name: 'Cherry smoothie',
        position: 1,
        libraryMealId: 'AB-002',
      ),
      _mealRow(
        id: 'pm-3',
        name: 'Nanna pasta',
        position: 2,
        source: 'saved',
        savedMealId: 'a1b2c3d4-0000-0000-0000-000000000000',
      ),
    ];
    final synced = await repo.syncFromRemote(_user);
    expect(synced.success, isTrue, reason: synced.error);
    plan = (await repo.getActivePlan(_user, _week))!;
    expect(plan.meals.map((m) => m.id), ['pm-1', 'pm-2', 'pm-3']);

    photos = _FakeLibraryPhotos([
      _libraryRow(
        'AB-001',
        photoUrl: _avocado,
        credit: _credit,
        creditUrl: 'https://commons.wikimedia.org/wiki/File:Avocado.jpg',
      ),
      _libraryRow('AB-002'),
    ]);

    // Serve real bytes: a photograph that fails to load collapses to nothing
    // (ADR 0003), which is the behaviour of a *missing* photo, so an
    // unanswered request would hide the very thing under test.
    debugNetworkImageHttpClientProvider = () => _FixedHttpClient(imageBytes);
  });

  tearDown(() async => db.close());

  Widget host(Widget child) => ProviderScope(
    overrides: [
      contentServiceProvider.overrideWith(testContentService),
      mealLibraryRemoteDataSourceProvider.overrideWithValue(photos),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );

  /// The photo read is async; two frames let it answer and the rows rebuild.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Finder photoOf(String url) => find.byWidgetPredicate(
    (w) =>
        w is Image &&
        w.image is NetworkImage &&
        (w.image as NetworkImage).url == url,
  );

  Finder imagesIn(Finder row) =>
      find.descendant(of: row, matching: find.byType(Image));

  testWidgets('plan tiles: the Meal with a photo shows it, the others none', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        PlanList(
          meals: plan.meals,
          onTapMeal: (_) {},
          onSwap: (_) {},
          onRemove: (_) {},
        ),
      ),
    );
    await settle(tester);

    // Asked once, by meal id, for the two rows that have a library Meal.
    expect(photos.asked, [
      ['AB-001', 'AB-002'],
    ]);

    expect(photoOf(_avocado), findsOneWidget);
    expect(imagesIn(find.byType(PlanTile).at(0)), findsOneWidget);
    // A Meal in the library with no photo, and a saved-only meal with nothing
    // to look up, both draw no picture at all.
    expect(imagesIn(find.byType(PlanTile).at(1)), findsNothing);
    expect(imagesIn(find.byType(PlanTile).at(2)), findsNothing);
    // The rows with no picture start at their name.
    final withoutPhoto = [
      tester.getTopLeft(find.text('Cherry smoothie')).dx,
      tester.getTopLeft(find.text('Nanna pasta')).dx,
    ];
    expect(withoutPhoto.toSet(), hasLength(1));
    expect(
      tester.getTopLeft(find.text('Avocado toast')).dx,
      greaterThan(withoutPhoto.first),
      reason: 'the photo takes its own space; it does not overlap the name',
    );
    _stopServing();
  });

  testWidgets('plan bar tiles: the same photo, from the same lookup', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            PlanBar(
              meals: plan.meals,
              onServings: (_, __) {},
              onRemove: (_) {},
              onSwap: (_, __) {},
              onReview: () {},
            ),
          ],
        ),
      ),
    );
    await settle(tester);
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.plan_bar.minimized')),
    );
    await settle(tester);

    expect(photoOf(_avocado), findsOneWidget);
    expect(
      imagesIn(find.byKey(const ValueKey('meal_planning.plan_bar.tile_pm-1'))),
      findsOneWidget,
    );
    expect(
      imagesIn(find.byKey(const ValueKey('meal_planning.plan_bar.tile_pm-2'))),
      findsNothing,
    );
    _stopServing();
  });

  testWidgets('review sheet rows: the same photo again', (tester) async {
    await tester.pumpWidget(
      host(
        Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showReviewSheet(
              context: context,
              ref: ref,
              plan: plan,
              onTapMeal: (_) {},
              onServings: (_, __) {},
              onRemove: (_) {},
              onConfirm: () async => true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('open'));
    await settle(tester);
    await settle(tester);

    expect(find.text('Avocado toast'), findsOneWidget);
    expect(photoOf(_avocado), findsOneWidget);
    _stopServing();
  });

  testWidgets('a photo added to the Meal later reaches the plan already made', (
    tester,
  ) async {
    // The plan is untouched — the same rows, already synced. Only the library
    // Meal gains a photo, and the plan shows it on the next read.
    photos = _FakeLibraryPhotos([
      _libraryRow('AB-001', photoUrl: _avocado, credit: _credit),
      _libraryRow('AB-002', photoUrl: 'https://example.test/smoothie.jpg'),
    ]);

    await tester.pumpWidget(
      host(
        PlanList(
          meals: plan.meals,
          onTapMeal: (_) {},
          onSwap: (_) {},
          onRemove: (_) {},
        ),
      ),
    );
    await settle(tester);

    expect(imagesIn(find.byType(PlanTile).at(1)), findsOneWidget);
    // Nothing was written to the plan row to make that happen.
    final row = await (db.select(
      db.planMealsTable,
    )..where((t) => t.id.equals('pm-2'))).getSingle();
    expect(row.needsUpload, isFalse);
    _stopServing();
  });

  testWidgets('a photo read that fails leaves a whole plan, drawing nothing', (
    tester,
  ) async {
    // The plan comes from Drift and never waits on the library: an outage
    // costs the pictures, not the plan.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          mealLibraryRemoteDataSourceProvider.overrideWithValue(
            _FailingLibraryPhotos(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PlanList(
              meals: plan.meals,
              onTapMeal: (_) {},
              onSwap: (_) {},
              onRemove: (_) {},
            ),
          ),
        ),
      ),
    );
    await settle(tester);

    expect(find.byType(PlanTile), findsNWidgets(3));
    expect(find.text('Avocado toast'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    _stopServing();
  });
}

/// The library unreachable — no signal, or the read refused.
class _FailingLibraryPhotos extends Fake
    implements MealLibraryRemoteDataSource {
  @override
  Future<Map<String, MealPhoto>> photosForMeals(
    Iterable<String> libraryMealIds,
  ) async => throw StateError('no network');
}

/// Put the painting library back as it was. The framework asserts on this
/// between the test body and the tear-downs, so it cannot wait for one.
void _stopServing() {
  debugNetworkImageHttpClientProvider = null;
  PaintingBinding.instance.imageCache.clear();
}

/// A small real PNG, so an `Image.network` under test actually decodes.
Future<Uint8List> _pngBytes() async {
  const w = 40.0, h = 40.0;
  final recorder = ui.PictureRecorder();
  Canvas(recorder, const Rect.fromLTWH(0, 0, w, h)).drawRect(
    const Rect.fromLTWH(0, 0, w, h),
    Paint()..color = const Color(0xFF6F8F4F),
  );
  final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  return (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
}

class _FixedHttpClient implements HttpClient {
  _FixedHttpClient(this.body);
  final Uint8List body;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FixedRequest(body);
  @override
  bool autoUncompress = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FixedRequest implements HttpClientRequest {
  _FixedRequest(this.body);
  final Uint8List body;
  @override
  final HttpHeaders headers = _NullHeaders();
  @override
  Future<HttpClientResponse> close() async => _FixedResponse(body);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NullHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FixedResponse extends Stream<List<int>> implements HttpClientResponse {
  _FixedResponse(this.body);
  final Uint8List body;
  @override
  int get statusCode => HttpStatus.ok;
  @override
  int get contentLength => body.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.fromIterable([body]).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
