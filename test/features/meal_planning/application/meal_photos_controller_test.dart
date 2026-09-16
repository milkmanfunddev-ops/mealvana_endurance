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

  /// What the three ticket-06 actions were asked to do, in order.
  final List<Map<String, String>> actions = [];

  /// What the server says the Meal wears after a delete — null when the
  /// deleted photograph was the one being worn.
  MealPhoto? deleteLeaves;

  /// What the server answers a restore with. Deliberately not the row the test
  /// seeded: a restore must show what the SERVER wrote, not what this device
  /// happened to be holding.
  MealPhoto restoreAnswers = const MealPhoto(
    url: 'https://upload.wikimedia.org/avocado.jpg',
    credit: 'Photo by Jami430 on Wikimedia Commons (CC BY-SA 4.0)',
  );

  @override
  Future<MealPhoto?> remove(String mealId) async {
    actions.add({'action': 'remove', 'mealId': mealId});
    if (gate case final g?) await g.future;
    if (failWith case final error?) throw error;
    return null;
  }

  @override
  Future<MealPhoto> restore({
    required String mealId,
    required String photoId,
  }) async {
    actions.add({'action': 'restore', 'mealId': mealId, 'photoId': photoId});
    if (gate case final g?) await g.future;
    if (failWith case final error?) throw error;
    return restoreAnswers;
  }

  @override
  Future<MealPhoto?> deletePhoto({
    required String mealId,
    required String photoId,
  }) async {
    actions.add({'action': 'delete', 'mealId': mealId, 'photoId': photoId});
    if (gate case final g?) await g.future;
    if (failWith case final error?) throw error;
    return deleteLeaves;
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

  // ─────────────── taking photographs back (ticket 06) ───────────────
  //
  // Remove, restore and delete are remote-ack the same way an add is: one
  // request each, the page moves only once the server has answered, and a
  // refusal leaves the Tester looking at what athletes really see.

  group('a Tester taking a photograph back', () {
    /// The Meal is wearing the newest photograph, with an older one behind it.
    MealPhotos seeded() => _seeded(
      photo: const MealPhoto(url: _newUrl),
      history: [
        const MealPhotoHistoryEntry(
          id: 'history-worn',
          photo: MealPhoto(url: _newUrl),
          isCurrent: true,
        ),
        MealPhotoHistoryEntry(
          id: 'history-old',
          photo: _existing,
          isCurrent: false,
        ),
      ],
    );

    MealPhotos read(ProviderContainer c) =>
        c.read(mealPhotosControllerProvider(_mealId)).value!;

    test('remove sends one request and the Meal then shows nothing', () async {
      final container = containerFor(seeded());
      await load(container);

      await notifier(container).remove();

      expect(repo.actions, [
        {'action': 'remove', 'mealId': _mealId},
      ]);
      expect(read(container).photo, isNull);
      // Nothing was re-read: the page knows what it asked for.
      expect(repo.historyCalls, 1);
    });

    test('remove keeps History and brings no older photograph forward', () async {
      final container = containerFor(seeded());
      await load(container);

      await notifier(container).remove();

      final photos = read(container);
      // Both rows are still there, and neither is worn — "remove" does exactly
      // what it says rather than quietly reverting to the previous photo.
      expect(photos.history.map((e) => e.id), ['history-worn', 'history-old']);
      expect(photos.history.map((e) => e.isCurrent), [false, false]);
    });

    test('remove moves the state only after the server acknowledges', () async {
      final container = containerFor(seeded());
      await load(container);
      repo.gate = Completer<void>();

      final pending = notifier(container).remove();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // In flight: athletes still see it, so the Tester still sees it.
      expect(read(container).photo?.url, _newUrl);

      repo.gate!.complete();
      await pending;
      expect(read(container).photo, isNull);
    });

    test('a refused remove leaves the photograph exactly where it was', () async {
      final container = containerFor(seeded());
      await load(container);
      repo.failWith = const MealPhotoException('not_tester');

      await expectLater(
        notifier(container).remove(),
        throwsA(isA<MealPhotoException>()),
      );

      final state = container.read(mealPhotosControllerProvider(_mealId));
      expect(state.hasError, isFalse);
      expect(state.value?.photo?.url, _newUrl);
      expect(state.value?.history.first.isCurrent, isTrue);
    });

    test('restore names the row and wears the server own answer', () async {
      final container = containerFor(seeded());
      await load(container);

      await notifier(container).restore('history-old');

      expect(repo.actions, [
        {'action': 'restore', 'mealId': _mealId, 'photoId': 'history-old'},
      ]);
      final photos = read(container);
      // The credit shown is the server's, not the one this device was holding:
      // a stale History must not put stale wording in front of athletes.
      expect(photos.photo?.url, repo.restoreAnswers.url);
      expect(photos.photo?.credit, repo.restoreAnswers.credit);
      // And the restored row is the one marked, with the other let go.
      expect(photos.history.map((e) => e.isCurrent), [false, true]);
    });

    test('the restored row itself shows what the server wrote', () async {
      final container = containerFor(seeded());
      await load(container);
      // This device's History is stale: the credit on its row for history-old
      // has since been reworded on the server.
      repo.restoreAnswers = const MealPhoto(
        url: 'https://upload.wikimedia.org/avocado.jpg',
        credit: 'Photo by Jami430 on Wikimedia Commons (CC BY-SA 4.0, 2026)',
      );

      await notifier(container).restore('history-old');

      final row = read(
        container,
      ).history.firstWhere((e) => e.id == 'history-old');
      // The row and the photograph above it must not show different credits
      // until the next reload.
      expect(row.photo.credit, repo.restoreAnswers.credit);
      expect(row.photo.credit, read(container).photo?.credit);
    });

    test('a refused restore leaves the state unchanged', () async {
      final container = containerFor(seeded());
      await load(container);
      repo.failWith = const MealPhotoException('photo_not_found');

      await expectLater(
        notifier(container).restore('history-old'),
        throwsA(isA<MealPhotoException>()),
      );

      expect(read(container).photo?.url, _newUrl);
      expect(read(container).history.first.isCurrent, isTrue);
    });

    test('delete drops the row, and the Meal shows nothing when it was worn', () async {
      final container = containerFor(seeded());
      await load(container);
      repo.deleteLeaves = null; // the server: nothing is worn now

      await notifier(container).delete('history-worn');

      expect(repo.actions, [
        {'action': 'delete', 'mealId': _mealId, 'photoId': 'history-worn'},
      ]);
      final photos = read(container);
      expect(photos.photo, isNull);
      // Gone from History for good, so it can never be restored with a tap.
      expect(photos.history.map((e) => e.id), ['history-old']);
      expect(photos.history.single.isCurrent, isFalse);
    });

    test('deleting a photograph that was not worn leaves the current one on', () async {
      final container = containerFor(seeded());
      await load(container);
      // The server's answer: still wearing what it was wearing.
      repo.deleteLeaves = const MealPhoto(url: _newUrl);

      await notifier(container).delete('history-old');

      final photos = read(container);
      expect(photos.photo?.url, _newUrl);
      expect(photos.history.map((e) => e.id), ['history-worn']);
      expect(photos.history.single.isCurrent, isTrue);
    });

    test('a refused delete loses nothing', () async {
      final container = containerFor(seeded());
      await load(container);
      repo.failWith = const VanaOfflineException('no route to host');

      await expectLater(
        notifier(container).delete('history-old'),
        throwsA(isA<VanaOfflineException>()),
      );

      final photos = read(container);
      expect(photos.photo?.url, _newUrl);
      expect(photos.history, hasLength(2));
    });
  });
}
