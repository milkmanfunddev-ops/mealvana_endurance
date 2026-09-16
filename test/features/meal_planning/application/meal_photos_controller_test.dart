/// MealPhotosController.addAddress — a Tester's photo write through the real
/// notifier (seam 2, meal-imagery ticket 04).
///
/// Remote-ack only: one request per add, the state moves only once the fake has
/// answered, and a refusal leaves the page showing exactly what athletes still
/// see while the failure reaches the screen.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_photos_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_photo_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_photo.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_photo_history.dart';

import '../helpers/container.dart';
import '../helpers/fakes.dart';

const _mealId = 'AD-001';
const _newUrl = 'https://images.pexels.com/photos/1/salmon-salad.jpeg';

/// Records every call instead of reaching the edge function. [failWith] makes
/// the next add throw the way a 403, a non-image address or a dropped network
/// would; [gate] holds the answer so a test can look at the state mid-flight.
class _RecordingPhotoRepository implements MealPhotoRepository {
  _RecordingPhotoRepository(this._seed);

  final MealPhotos _seed;
  final List<Map<String, String?>> adds = [];
  int historyCalls = 0;
  Object? failWith;
  Completer<void>? gate;
  int _ids = 0;

  @override
  Future<MealPhotos> history(String mealId) async {
    historyCalls++;
    return _seed;
  }

  @override
  Future<MealPhotoHistoryEntry> addAddress({
    required String mealId,
    required String url,
    String? credit,
    String? creditUrl,
  }) async {
    adds.add({
      'mealId': mealId,
      'url': url,
      'credit': credit,
      'creditUrl': creditUrl,
    });
    if (gate case final g?) await g.future;
    if (failWith case final error?) throw error;
    return MealPhotoHistoryEntry(
      id: 'history-${++_ids}',
      photo: MealPhoto(url: url, credit: credit, creditUrl: creditUrl),
      isCurrent: true,
      addedBy: 'user-1',
      addedAt: DateTime(2026, 9, 16, 14, 5),
    );
  }
}

MealPhotos _seeded({MealPhoto? photo, List<MealPhotoHistoryEntry> history =
    const []}) => MealPhotos(photo: photo, history: history);

final _existing = MealPhoto(
  url: 'https://upload.wikimedia.org/avocado.jpg',
  credit: 'Photo by Jami430 on Wikimedia Commons (CC BY-SA 4.0)',
  creditUrl: 'https://commons.wikimedia.org/wiki/File:Avocado.jpg',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingPhotoRepository repo;

  ProviderContainer containerFor(MealPhotos seed) {
    repo = _RecordingPhotoRepository(seed);
    return testContainer([
      ...baseOverrides(logger: FakeLogger()),
      mealPhotoRepositoryProvider.overrideWithValue(repo),
    ]);
  }

  /// Open the page: read the photos AND keep watching, the way the screen
  /// does. The controller is not `keepAlive`, so a bare `read` would let it
  /// dispose between assertions and start over.
  Future<MealPhotos> load(ProviderContainer c) {
    c.listen(mealPhotosControllerProvider(_mealId), (_, __) {});
    return c.read(mealPhotosControllerProvider(_mealId).future);
  }

  MealPhotosController notifier(ProviderContainer c) =>
      c.read(mealPhotosControllerProvider(_mealId).notifier);

  test('the page opens on what athletes see now, read from the server', () async {
    final container = containerFor(
      _seeded(
        photo: _existing,
        history: [
          MealPhotoHistoryEntry(
            id: 'history-old',
            photo: _existing,
            isCurrent: true,
          ),
        ],
      ),
    );

    final photos = await load(container);

    expect(repo.historyCalls, 1);
    expect(photos.photo?.url, _existing.url);
    expect(photos.history.single.id, 'history-old');
  });

  test('an add sends exactly one request, carrying what the Tester typed', () async {
    final container = containerFor(_seeded());
    await load(container);

    await notifier(container).addAddress(
      url: _newUrl,
      credit: 'Photo by Lee',
      creditUrl: 'https://example.com/photos/1',
    );

    expect(repo.adds, hasLength(1));
    expect(repo.adds.single, {
      'mealId': _mealId,
      'url': _newUrl,
      'credit': 'Photo by Lee',
      'creditUrl': 'https://example.com/photos/1',
    });
    // Nothing was re-read: the acknowledgement carries the new photo, so a
    // successful publish can never be reported as a failure because a second
    // request happened to fail after it.
    expect(repo.historyCalls, 1);
  });

  test('the state moves only after the server acknowledges', () async {
    final container = containerFor(_seeded(photo: _existing));
    await load(container);
    repo.gate = Completer<void>();

    final pending = notifier(container).addAddress(url: _newUrl);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // In flight: the page still shows the photograph athletes still see.
    expect(
      container.read(mealPhotosControllerProvider(_mealId)).value?.photo?.url,
      _existing.url,
    );

    repo.gate!.complete();
    await pending;

    expect(
      container.read(mealPhotosControllerProvider(_mealId)).value?.photo?.url,
      _newUrl,
    );
  });

  test('a new photo becomes current and the old one stays in History', () async {
    final container = containerFor(
      _seeded(
        photo: _existing,
        history: [
          MealPhotoHistoryEntry(
            id: 'history-old',
            photo: _existing,
            isCurrent: true,
          ),
        ],
      ),
    );
    await load(container);

    await notifier(container).addAddress(url: _newUrl, credit: 'Photo by Lee');

    final photos = container
        .read(mealPhotosControllerProvider(_mealId))
        .value!;
    expect(photos.photo?.url, _newUrl);
    // Newest first, and nothing is lost by trying a new photograph.
    expect(photos.history.map((e) => e.id), ['history-1', 'history-old']);
    expect(photos.history.map((e) => e.isCurrent), [true, false]);
    expect(photos.history.last.photo.url, _existing.url);
  });

  test('a refusal leaves the state unchanged and reaches the screen', () async {
    final container = containerFor(_seeded(photo: _existing));
    await load(container);
    repo.failWith = const MealPhotoException('not_tester');

    await expectLater(
      notifier(container).addAddress(url: _newUrl),
      throwsA(isA<MealPhotoException>()),
    );

    final state = container.read(mealPhotosControllerProvider(_mealId));
    // Still data, still the old photograph: the page keeps showing what
    // athletes really see rather than replacing it with an error.
    expect(state.hasError, isFalse);
    expect(state.value?.photo?.url, _existing.url);
  });

  test('with no signal it fails clearly and queues nothing', () async {
    final container = containerFor(_seeded());
    await load(container);
    repo.failWith = const VanaOfflineException('no route to host');

    await expectLater(
      notifier(container).addAddress(url: _newUrl),
      throwsA(isA<VanaOfflineException>()),
    );

    expect(repo.adds, hasLength(1));
    expect(
      container.read(mealPhotosControllerProvider(_mealId)).value?.photo,
      isNull,
    );
  });
}
