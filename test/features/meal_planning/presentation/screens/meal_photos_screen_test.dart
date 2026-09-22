// The Meal photos page: a Tester pastes an address, or takes or chooses a
// photo, sees a preview, and only then may confirm (ADR 0003, tickets 04, 05).
//
// The page drives the real notifier with a recording fake repository behind it,
// so what is under test is the page's own rule — nothing publishes until the
// address has actually drawn — and not a stubbed controller's say-so.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mealvana_endurance/features/meal_planning/application/dish_photo_capture.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/providers/dish_photo_cropper.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_photo_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/dish_photo_preparation.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_photo.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_photo_history.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/meal_photos_screen.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/buttons/primary_button.dart';

import '../helpers/test_content.dart';
import '../../../../helpers/write_access.dart';

const _mealId = 'AD-001';
const _address = 'https://images.pexels.com/photos/1/salmon-salad.jpeg';

/// Records what reached the edge function, and answers the way it would.
class _RecordingPhotoRepository implements MealPhotoRepository {
  _RecordingPhotoRepository(this.seed);

  MealPhotos seed;
  final List<Map<String, String?>> adds = [];
  Object? failWith;

  @override
  Future<MealPhotos> history(String mealId) async => seed;

  final List<Uint8List> uploaded = [];

  @override
  Future<MealPhotoHistoryEntry> addUpload({
    required String mealId,
    required Uint8List bytes,
    String? credit,
    String? creditUrl,
  }) async {
    uploaded.add(bytes);
    if (failWith case final e?) throw e;
    return MealPhotoHistoryEntry(
      id: 'history-upload',
      photo: MealPhoto(
        url:
            'https://dev.supabase.co/storage/v1/object/public/meal-images/'
            'photos/AD-001/stored.jpg',
        credit: credit,
        creditUrl: creditUrl,
      ),
      isCurrent: true,
      storagePath: 'photos/AD-001/stored.jpg',
      addedAt: DateTime(2026, 9, 16, 14, 5),
    );
  }

  @override
  Future<MealPhotoHistoryEntry> addAddress({
    required String mealId,
    required String url,
    String? credit,
    String? creditUrl,
  }) async {
    adds.add({'url': url, 'credit': credit, 'creditUrl': creditUrl});
    if (failWith case final e?) throw e;
    return MealPhotoHistoryEntry(
      id: 'history-1',
      photo: MealPhoto(url: url, credit: credit, creditUrl: creditUrl),
      isCurrent: true,
      addedAt: DateTime(2026, 9, 16, 14, 5),
    );
  }

  /// Every remove / restore / delete that reached the function, in order.
  final List<Map<String, String>> actions = [];

  @override
  Future<MealPhoto?> remove(String mealId) async {
    actions.add({'action': 'remove'});
    if (failWith case final e?) throw e;
    return null;
  }

  @override
  Future<MealPhoto> restore({
    required String mealId,
    required String photoId,
  }) async {
    actions.add({'action': 'restore', 'photoId': photoId});
    if (failWith case final e?) throw e;
    return const MealPhoto(url: 'https://upload.wikimedia.org/avocado.jpg');
  }

  @override
  Future<MealPhoto?> deletePhoto({
    required String mealId,
    required String photoId,
  }) async {
    actions.add({'action': 'delete', 'photoId': photoId});
    if (failWith case final e?) throw e;
    return null;
  }
}

void main() {
  final content = loadDefaultContent();

  late _RecordingPhotoRepository repo;
  late Uint8List imageBytes;

  setUpAll(() async => imageBytes = await _pngBytes());

  /// Serve real bytes so an `Image.network` under test actually decodes;
  /// without this every request answers 400 and nothing ever previews.
  void serveImages() =>
      debugNetworkImageHttpClientProvider = () => _FixedHttpClient(imageBytes);

  /// What the fake picker answers, and what the fake crop editor answers.
  /// Null stands for the Tester backing out of that step.
  Uint8List? picked;
  Uint8List? cropped;
  Object? pickerThrows;
  final pickedFrom = <ImageSource>[];

  Future<void> pump(WidgetTester tester, {MealPhotos? seed}) async {
    // Each test gets its own picker and crop editor. Without this the thrown
    // picker from one case leaks into every case after it, and `pickedFrom`
    // accumulates across tests.
    picked = null;
    cropped = null;
    pickerThrows = null;
    pickedFrom.clear();
    repo = _RecordingPhotoRepository(seed ?? const MealPhotos());
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          writesAllowed(),
          contentServiceProvider.overrideWith(testContentService),
          mealPhotoRepositoryProvider.overrideWithValue(repo),
          // The camera and the crop editor are platform widgets — they are
          // checked on a device. What is under test here is the page's own
          // rule: nothing publishes until the Tester has seen it and confirmed.
          dishPhotoPickerProvider.overrideWithValue((source) async {
            pickedFrom.add(source);
            if (pickerThrows case final e?) throw e;
            return picked;
          }),
          dishPhotoCropperProvider.overrideWithValue((_, __) async => cropped),
          // The very same preparation, run inline: a real isolate never
          // resolves inside `pumpAndSettle`'s fake-async zone. The bytes a
          // photo is published as are asserted in the seam-2 controller test,
          // which does go through the isolate.
          dishPhotoPreparerProvider.overrideWithValue(
            (bytes) async => prepareDishPhoto(bytes),
          ),
        ],
        child: const MaterialApp(
          home: MealPhotosScreen(mealId: _mealId, mealName: 'Salmon salad'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> paste(WidgetTester tester, String url) async {
    await tester.enterText(
      find.byKey(const ValueKey('meal_planning.photos_address_field')),
      url,
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.photos_preview')),
    );
    await tester.pump();
  }

  /// Let the image request answer and the preview settle.
  Future<void> settleImage(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump();
  }

  bool confirmEnabled(WidgetTester tester) =>
      tester
          .widget<KylePrimaryButton>(
            find.byKey(const ValueKey('meal_planning.photos_confirm')),
          )
          .onPressed !=
      null;

  testWidgets('a Meal with no photo says so, and its History is empty', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text(content['meal_planning.photos_none']!), findsOneWidget);
    expect(
      find.text(content['meal_planning.photos_history_empty']!),
      findsOneWidget,
    );
  });

  testWidgets('the Meal photo the athletes see now is shown with its credit', (
    tester,
  ) async {
    serveImages();
    const credit = 'Photo by Jami430 on Wikimedia Commons (CC BY-SA 4.0)';
    await pump(
      tester,
      seed: MealPhotos(
        photo: const MealPhoto(
          url: 'https://upload.wikimedia.org/avocado.jpg',
          credit: credit,
        ),
        history: [
          const MealPhotoHistoryEntry(
            id: 'history-old',
            photo: MealPhoto(url: 'https://upload.wikimedia.org/avocado.jpg'),
            isCurrent: true,
          ),
        ],
      ),
    );

    expect(find.text(credit), findsOneWidget);
    expect(find.text(content['meal_planning.photos_none']!), findsNothing);
    // The row it is wearing is marked, rather than the page asking the reader
    // to compare addresses.
    expect(
      find.text(content['meal_planning.photos_showing_now']!),
      findsOneWidget,
    );
    _stopServing();
  });

  testWidgets('an address that does not load says so, and Confirm stays off', (
    tester,
  ) async {
    // No image server: every request answers 400, exactly as a dead hotlink
    // or a page that is not an image would.
    await pump(tester);
    await paste(tester, 'https://example.com/not-an-image');
    await settleImage(tester);

    expect(
      find.byKey(const ValueKey('meal_planning.photos_preview_failed')),
      findsOneWidget,
    );
    expect(confirmEnabled(tester), isFalse);

    // Tapping it anyway publishes nothing.
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.photos_confirm')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(repo.adds, isEmpty);
  });

  testWidgets('Confirm waits for the preview even on a good address', (
    tester,
  ) async {
    serveImages();
    await pump(tester);
    await paste(tester, _address);

    // Typed and asked for, but not yet drawn: nothing may publish yet.
    expect(confirmEnabled(tester), isFalse);

    await settleImage(tester);
    expect(confirmEnabled(tester), isTrue);
    expect(
      find.byKey(const ValueKey('meal_planning.photos_preview_failed')),
      findsNothing,
    );
    _stopServing();
  });

  testWidgets(
    'confirming sends the address and the credit once, then says so',
    (tester) async {
      serveImages();
      await pump(tester);
      await paste(tester, _address);
      await settleImage(tester);

      await tester.enterText(
        find.byKey(const ValueKey('meal_planning.photos_credit_field')),
        'Photo by Lee',
      );
      await tester.enterText(
        find.byKey(const ValueKey('meal_planning.photos_credit_url_field')),
        'https://example.com/photos/1',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('meal_planning.photos_confirm')),
      );
      await tester.pump();
      await tester.pump();

      expect(repo.adds, hasLength(1));
      expect(repo.adds.single, {
        'url': _address,
        'credit': 'Photo by Lee',
        'creditUrl': 'https://example.com/photos/1',
      });
      // Said only after the server has it.
      expect(find.text(content['meal_planning.photos_added']!), findsOneWidget);
      // And the form is ready for the next one.
      expect(
        find.byKey(const ValueKey('meal_planning.photos_confirm')),
        findsNothing,
      );
      _stopServing();
    },
  );

  testWidgets('Cancel at the preview changes nothing', (tester) async {
    serveImages();
    await pump(tester);
    await paste(tester, _address);
    await settleImage(tester);

    await tester.tap(find.byKey(const ValueKey('meal_planning.photos_cancel')));
    await tester.pump();

    expect(repo.adds, isEmpty);
    // Back to an empty address field, with nothing published.
    expect(
      find.byKey(const ValueKey('meal_planning.photos_confirm')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.photos_preview')),
      findsOneWidget,
    );
    expect(find.text(content['meal_planning.photos_none']!), findsOneWidget);
    _stopServing();
  });

  testWidgets('a refusal from the server is shown, and nothing is claimed', (
    tester,
  ) async {
    serveImages();
    await pump(tester);
    repo.failWith = const MealPhotoException('not_tester');
    await paste(tester, _address);
    await settleImage(tester);

    await tester.tap(
      find.byKey(const ValueKey('meal_planning.photos_confirm')),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text(content['meal_planning.photos_not_tester']!),
      findsOneWidget,
    );
    expect(find.text(content['meal_planning.photos_added']!), findsNothing);
    _stopServing();
  });

  testWidgets('with no signal the Tester is told, and nothing is queued', (
    tester,
  ) async {
    serveImages();
    await pump(tester);
    repo.failWith = const VanaOfflineException('no route to host');
    await paste(tester, _address);
    await settleImage(tester);

    await tester.tap(
      find.byKey(const ValueKey('meal_planning.photos_confirm')),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text(content['meal_planning.needs_connection']!),
      findsOneWidget,
    );
    expect(repo.adds, hasLength(1));
    _stopServing();
  });

  testWidgets('a Tester is offered the camera and the gallery', (tester) async {
    await pump(tester);

    expect(find.text(content['meal_planning.photos_take']!), findsOneWidget);
    expect(find.text(content['meal_planning.photos_choose']!), findsOneWidget);
  });

  testWidgets('a chosen photo is previewed, and nothing is sent yet', (
    tester,
  ) async {
    await pump(tester);
    picked = imageBytes;
    cropped = imageBytes;

    await tester.tap(find.byKey(const ValueKey('meal_planning.photos_choose')));
    await tester.pumpAndSettle();

    expect(pickedFrom, [ImageSource.gallery]);
    expect(
      find.byKey(const ValueKey('meal_planning.photos_upload_preview_image')),
      findsOneWidget,
    );
    // Seen, not sent: publishing waits for Confirm (story 24).
    expect(repo.uploaded, isEmpty);
  });

  testWidgets('Take photo asks the camera', (tester) async {
    await pump(tester);
    picked = imageBytes;
    cropped = imageBytes;

    await tester.tap(find.byKey(const ValueKey('meal_planning.photos_take')));
    await tester.pumpAndSettle();

    expect(pickedFrom, [ImageSource.camera]);
  });

  testWidgets('backing out of the picker changes nothing', (tester) async {
    await pump(tester);
    picked = null;

    await tester.tap(find.byKey(const ValueKey('meal_planning.photos_choose')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('meal_planning.photos_upload_preview_image')),
      findsNothing,
    );
    expect(repo.uploaded, isEmpty);
    expect(find.text(content['meal_planning.photos_none']!), findsOneWidget);
  });

  testWidgets('cancelling at the crop step changes nothing', (tester) async {
    await pump(tester);
    picked = imageBytes;
    cropped = null; // backed out of the crop editor

    await tester.tap(find.byKey(const ValueKey('meal_planning.photos_choose')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('meal_planning.photos_upload_preview_image')),
      findsNothing,
    );
    expect(repo.uploaded, isEmpty);
  });

  testWidgets('a picker that will not open is reported', (tester) async {
    await pump(tester);
    pickerThrows = Exception('camera unavailable');

    await tester.tap(find.byKey(const ValueKey('meal_planning.photos_take')));
    await tester.pumpAndSettle();

    expect(
      find.text(content['meal_planning.photos_pick_failed']!),
      findsOneWidget,
    );
    expect(repo.uploaded, isEmpty);
  });

  testWidgets('confirming an upload sends it once, then says so', (
    tester,
  ) async {
    await pump(tester);
    picked = imageBytes;
    cropped = imageBytes;

    await tester.tap(find.byKey(const ValueKey('meal_planning.photos_choose')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('meal_planning.photos_upload_credit_field')),
      'Photo by Lee',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.photos_upload_confirm')),
    );
    await tester.pumpAndSettle();

    expect(repo.uploaded, hasLength(1));
    // Said only once the server has it.
    expect(find.text(content['meal_planning.photos_added']!), findsOneWidget);
    // And the page is back to offering the next one.
    expect(
      find.byKey(const ValueKey('meal_planning.photos_upload_confirm')),
      findsNothing,
    );
    expect(find.text(content['meal_planning.photos_take']!), findsOneWidget);
  });

  testWidgets('Cancel on a chosen photo publishes nothing', (tester) async {
    await pump(tester);
    picked = imageBytes;
    cropped = imageBytes;

    await tester.tap(find.byKey(const ValueKey('meal_planning.photos_choose')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.photos_upload_cancel')),
    );
    await tester.pumpAndSettle();

    expect(repo.uploaded, isEmpty);
    expect(
      find.byKey(const ValueKey('meal_planning.photos_upload_preview_image')),
      findsNothing,
    );
    expect(find.text(content['meal_planning.photos_take']!), findsOneWidget);
  });

  testWidgets('a refused upload is shown, and nothing is claimed', (
    tester,
  ) async {
    await pump(tester);
    picked = imageBytes;
    cropped = imageBytes;
    repo.failWith = const MealPhotoException('too_large');

    await tester.tap(find.byKey(const ValueKey('meal_planning.photos_choose')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.photos_upload_confirm')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(content['meal_planning.photos_too_large']!),
      findsOneWidget,
    );
    expect(find.text(content['meal_planning.photos_added']!), findsNothing);
  });

  // ───────────── removing, restoring and deleting (ticket 06) ─────────────

  /// A Meal wearing the newest photograph, with an older one behind it.
  MealPhotos worn() => const MealPhotos(
    photo: MealPhoto(url: _address),
    history: [
      MealPhotoHistoryEntry(
        id: 'history-worn',
        photo: MealPhoto(url: _address),
        isCurrent: true,
      ),
      MealPhotoHistoryEntry(
        id: 'history-old',
        photo: MealPhoto(url: 'https://upload.wikimedia.org/avocado.jpg'),
        isCurrent: false,
      ),
    ],
  );

  testWidgets('a Meal showing nothing offers nothing to remove', (
    tester,
  ) async {
    await pump(tester);

    // Remove is drawn beside the photograph, so a Meal without one has no
    // button to press. (That it IS drawn when there is one is what the next
    // test presses.)
    expect(
      find.byKey(const ValueKey('meal_planning.photos_remove')),
      findsNothing,
    );
  });

  testWidgets('Remove takes the photograph down and says so', (tester) async {
    await pump(tester, seed: worn());

    await tester.tap(find.byKey(const ValueKey('meal_planning.photos_remove')));
    await tester.pumpAndSettle();

    expect(repo.actions, [
      {'action': 'remove'},
    ]);
    expect(find.text(content['meal_planning.photos_removed']!), findsOneWidget);
    // The Meal shows nothing now, and there is nothing left to remove.
    expect(find.text(content['meal_planning.photos_none']!), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meal_planning.photos_remove')),
      findsNothing,
    );
  });

  testWidgets('Restore is offered on the older row, not the one being worn', (
    tester,
  ) async {
    await pump(tester, seed: worn());

    expect(
      find.byKey(const ValueKey('meal_planning.photos_restore_history-old')),
      findsOneWidget,
    );
    // Restoring what the Meal already wears would change nothing.
    expect(
      find.byKey(const ValueKey('meal_planning.photos_restore_history-worn')),
      findsNothing,
    );
  });

  testWidgets('restoring sends that row and says so', (tester) async {
    await pump(tester, seed: worn());

    await tester.tap(
      find.byKey(const ValueKey('meal_planning.photos_restore_history-old')),
    );
    await tester.pumpAndSettle();

    expect(repo.actions, [
      {'action': 'restore', 'photoId': 'history-old'},
    ]);
    expect(
      find.text(content['meal_planning.photos_restored']!),
      findsOneWidget,
    );
  });

  testWidgets('Delete asks first, and keeping it sends nothing', (
    tester,
  ) async {
    await pump(tester, seed: worn());

    await tester.tap(
      find.byKey(const ValueKey('meal_planning.photos_delete_history-old')),
    );
    await tester.pumpAndSettle();

    // Nothing is deleted on one tap: it takes the file with it and cannot be
    // undone (story 40).
    expect(
      find.byKey(const ValueKey('meal_planning.photos_delete_dialog')),
      findsOneWidget,
    );
    expect(repo.actions, isEmpty);

    await tester.tap(
      find.byKey(const ValueKey('meal_planning.photos_delete_cancel')),
    );
    await tester.pumpAndSettle();

    expect(repo.actions, isEmpty);
    expect(find.text(content['meal_planning.photos_deleted']!), findsNothing);
    // And the row is still there.
    expect(
      find.byKey(const ValueKey('meal_planning.photos_delete_history-old')),
      findsOneWidget,
    );
  });

  testWidgets('confirming the deletion sends it once and says so', (
    tester,
  ) async {
    await pump(tester, seed: worn());

    await tester.tap(
      find.byKey(const ValueKey('meal_planning.photos_delete_history-worn')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.photos_delete_confirm')),
    );
    await tester.pumpAndSettle();

    expect(repo.actions, [
      {'action': 'delete', 'photoId': 'history-worn'},
    ]);
    expect(find.text(content['meal_planning.photos_deleted']!), findsOneWidget);
    // Gone from History, and the Meal it was worn by shows nothing now.
    expect(
      find.byKey(const ValueKey('meal_planning.photos_delete_history-worn')),
      findsNothing,
    );
    expect(find.text(content['meal_planning.photos_none']!), findsOneWidget);
  });

  testWidgets('a refused removal is shown, and nothing is claimed', (
    tester,
  ) async {
    await pump(tester, seed: worn());
    repo.failWith = const MealPhotoException('not_tester');

    await tester.tap(find.byKey(const ValueKey('meal_planning.photos_remove')));
    await tester.pumpAndSettle();

    expect(
      find.text(content['meal_planning.photos_not_tester']!),
      findsOneWidget,
    );
    expect(find.text(content['meal_planning.photos_removed']!), findsNothing);
    // Still showing what athletes still see.
    expect(find.text(content['meal_planning.photos_none']!), findsNothing);
  });

  testWidgets('a photograph deleted from under the Tester is reported', (
    tester,
  ) async {
    await pump(tester, seed: worn());
    repo.failWith = const MealPhotoException('photo_not_found');

    await tester.tap(
      find.byKey(const ValueKey('meal_planning.photos_restore_history-old')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(content['meal_planning.photos_photo_not_found']!),
      findsOneWidget,
    );
  });
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
