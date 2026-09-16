/// MealPhotosController's writes — a Tester's photo through the real notifier
/// (seam 2, meal-imagery tickets 04 and 05).
///
/// Remote-ack only: one request per add, the state moves only once the fake has
/// answered, and a refusal leaves the page showing exactly what athletes still
/// see while the failure reaches the screen.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mealvana_endurance/features/meal_planning/domain/dish_photo_preparation.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_photos_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_photo_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_photo.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_photo_history.dart';

import '../helpers/container.dart';
import '../helpers/exif.dart';
import '../helpers/fakes.dart';

const _mealId = 'AD-001';
const _newUrl = 'https://images.pexels.com/photos/1/salmon-salad.jpeg';

/// A real camera photo: 2400x1800, and carrying the make, model and GPS a
/// phone stamps on. See the fixtures README.
const _gpsPhoto = 'test/features/meal_planning/fixtures/dish_photo_with_gps.jpg';


/// Records every call instead of reaching the edge function. [failWith] makes
/// the next add throw the way a 403, a non-image address or a dropped network
/// would; [gate] holds the answer so a test can look at the state mid-flight.
class _RecordingPhotoRepository implements MealPhotoRepository {
  _RecordingPhotoRepository(this._seed);

  final MealPhotos _seed;
  final List<Map<String, String?>> adds = [];
  /// The bytes that reached the repository, i.e. what would have left the
  /// phone. The seam-2 assertions are all about these.
  final List<Uint8List> uploaded = [];
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

  @override
  Future<MealPhotoHistoryEntry> addUpload({
    required String mealId,
    required Uint8List bytes,
    String? credit,
    String? creditUrl,
  }) async {
    uploaded.add(bytes);
    adds.add({
      'mealId': mealId,
      'url': '<upload>',
      'credit': credit,
      'creditUrl': creditUrl,
    });
    if (gate case final g?) await g.future;
    if (failWith case final error?) throw error;
    return MealPhotoHistoryEntry(
      id: 'history-${++_ids}',
      photo: MealPhoto(
        url: 'https://dev.supabase.co/storage/v1/object/public/meal-images/'
            'photos/AD-001/stored.jpg',
        credit: credit,
        creditUrl: creditUrl,
      ),
      isCurrent: true,
      storagePath: 'photos/AD-001/stored.jpg',
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

  // ────────────────────────── uploads (ticket 05) ──────────────────────────
  //
  // These are about what leaves the phone. Once bytes reach the function they
  // are in a public bucket, so every assertion is on the bytes the repository
  // was handed, not on what the controller says it did.

  group('a photo the Tester took or chose', () {
    late Uint8List original;

    setUpAll(() => original = File(_gpsPhoto).readAsBytesSync());

    test('really carries GPS before we send it, or this proves nothing', () {
      expect(carriesExifSegment(original), isTrue);
      expect(img.decodeImage(original)!.exif.gpsIfd.isEmpty, isFalse);
    });

    test('leaves the phone with no EXIF and no GPS at all', () async {
      final container = containerFor(_seeded());
      await load(container);

      await notifier(container).addUpload(bytes: original);

      expect(repo.uploaded, hasLength(1));
      final sent = repo.uploaded.single;
      // The Tester's home address is gone before the socket opens.
      expect(carriesExifSegment(sent), isFalse);
      final decoded = img.decodeImage(sent)!;
      expect(decoded.exif.isEmpty, isTrue);
      expect(decoded.exif.gpsIfd.isEmpty, isTrue);
    });

    test('leaves the phone cropped to the shape athletes see', () async {
      final container = containerFor(_seeded());
      await load(container);

      await notifier(container).addUpload(bytes: original);

      final decoded = img.decodeImage(repo.uploaded.single)!;
      expect(
        decoded.width / decoded.height,
        closeTo(kDishPhotoAspectRatio, 0.01),
      );
    });

    test('leaves the phone inside the size limit', () async {
      final container = containerFor(_seeded());
      await load(container);

      await notifier(container).addUpload(bytes: original);

      final sent = repo.uploaded.single;
      final decoded = img.decodeImage(sent)!;
      final longEdge = decoded.width > decoded.height
          ? decoded.width
          : decoded.height;
      expect(longEdge, kDishPhotoMaxLongEdge);
      expect(sent.length, lessThan(original.length));
    });

    test('is sent once, with the credit the Tester typed', () async {
      final container = containerFor(_seeded());
      await load(container);

      await notifier(container).addUpload(
        bytes: original,
        credit: 'Photo by Lee',
        creditUrl: 'https://example.com/photos/1',
      );

      expect(repo.adds, hasLength(1));
      expect(repo.adds.single['credit'], 'Photo by Lee');
      expect(repo.adds.single['creditUrl'], 'https://example.com/photos/1');
      expect(repo.historyCalls, 1);
    });

    test('becomes the current photo only after the server acknowledges', () async {
      final container = containerFor(_seeded(photo: _existing));
      await load(container);
      repo.gate = Completer<void>();

      final pending = notifier(container).addUpload(bytes: original);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // In flight: still the photograph athletes can see right now.
      expect(
        container.read(mealPhotosControllerProvider(_mealId)).value?.photo?.url,
        _existing.url,
      );

      repo.gate!.complete();
      await pending;

      final photos = container
          .read(mealPhotosControllerProvider(_mealId))
          .value!;
      expect(photos.photo?.url, contains('meal-images/photos/AD-001/'));
      expect(photos.history.single.storagePath, 'photos/AD-001/stored.jpg');
    });

    test('that the server refuses leaves the state unchanged', () async {
      final container = containerFor(_seeded(photo: _existing));
      await load(container);
      repo.failWith = const MealPhotoException('too_large');

      await expectLater(
        notifier(container).addUpload(bytes: original),
        throwsA(isA<MealPhotoException>()),
      );

      final state = container.read(mealPhotosControllerProvider(_mealId));
      expect(state.hasError, isFalse);
      expect(state.value?.photo?.url, _existing.url);
    });

    test('that is not a photo at all never leaves the phone', () async {
      final container = containerFor(_seeded(photo: _existing));
      await load(container);

      await expectLater(
        notifier(container).addUpload(
          bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
        ),
        throwsA(isA<DishPhotoUnreadable>()),
      );

      // Refused on the device: nothing was sent, and nothing changed.
      expect(repo.uploaded, isEmpty);
      expect(repo.adds, isEmpty);
      expect(
        container.read(mealPhotosControllerProvider(_mealId)).value?.photo?.url,
        _existing.url,
      );
    });
  });
}
