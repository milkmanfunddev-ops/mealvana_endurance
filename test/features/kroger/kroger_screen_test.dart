// How Shop with Kroger is drawn: goldens in the shape the meal-planning ones
// use (`test/features/meal_planning/presentation/widget_goldens_test.dart`) —
// each state at iPhone-SE width, light and dark — plus the screen-reader
// sweep, which is not a thing a picture can hold.
//
// What these pin is that the screen is drawn out of the design system — the
// header the other meal-planning detail screens use, Kyle cards and buttons,
// the token type scale — and that Kroger's product photograph is shown whole.
// A golden that moves means the screen moved.
//
// The product is `spoke_product.json` through the same mapping the edge
// function applies (`kroger_fixtures.dart`), so the pack size and the image
// URL here are Kroger's own and cannot drift by being retyped. The image
// bytes are served locally: a golden must not depend on Kroger's CDN.
//
// Fonts: widget tests render with the test font, so these pin LAYOUT, COLOUR
// and STRUCTURE, not glyph shapes.
//
//   flutter test test/features/kroger/kroger_screen_test.dart
//   flutter test test/features/kroger/kroger_screen_test.dart --update-goldens
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/kroger/application/kroger_controller.dart';
import 'package:mealvana_endurance/features/kroger/domain/kroger_models.dart';
import 'package:mealvana_endurance/features/kroger/presentation/kroger_screen.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_theme.dart';

import '../meal_planning/presentation/helpers/test_content.dart';
import 'kroger_fixtures.dart';

/// iPhone SE logical width — the narrowest layout the app supports.
const _seWidth = 320.0;
const _plan = '11111111-1111-4111-8111-111111111111';

KrogerLine _matched({bool approved = true}) => KrogerLine(
  id: 'a',
  name: 'Broccoli',
  requiredQty: '2 heads',
  product: spokeProduct,
  quantity: 2,
  approved: approved,
);

/// Searched for, and Kroger had nothing.
const _unmatched = KrogerLine(
  id: 'b',
  name: 'Sourdough starter',
  requiredQty: '1 jar',
  noMatch: true,
);
const _skipped = KrogerLine(
  id: 'c',
  name: 'Olive oil',
  requiredQty: '500 ml',
  excluded: true,
);

KrogerState _state({
  String? receiptStatus,
  String? unavailableReason,
  String environment = 'production',
  bool connected = true,
  bool approved = true,
  bool located = true,
  bool searched = true,
}) => KrogerState(
  connected: connected,
  environment: environment,
  unavailableReason: unavailableReason,
  area: '35209',
  draft: KrogerDraft(
    planId: _plan,
    store: located ? spokeStore : null,
    environment: environment,
    receiptStatus: receiptStatus,
    lines: searched
        ? [_matched(approved: approved), _unmatched, _skipped]
        // Before any matching run: no product anywhere, and no answer yet.
        : [
            _matched().copyWith(clearProduct: true),
            _unmatched.copyWith(noMatch: false),
            _skipped,
          ],
  ),
);

void main() {
  Future<void> goldenTest(
    WidgetTester tester,
    String name,
    Brightness brightness,
    KrogerState state, {
    double height = 1800,
  }) async {
    tester.view.physicalSize = Size(_seWidth, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // The framework asserts the painting debug variables are unset before
    // tear-downs run, so this is served and put back inside the body.
    await tester.runAsync(() async {
      _serveOneImage(await _swatchPng());
      // Warm the photograph before the screen asks for it, so the golden is a
      // picture of a loaded image rather than of whichever frame arrived first.
      await _resolve(NetworkImage(spokeProduct.image!));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          krogerControllerProvider(
            _plan,
          ).overrideWith(() => _SeededController(state)),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.dark
              ? AppTheme.darkTheme
              : AppTheme.lightTheme,
          home: RepaintBoundary(
            key: const Key('golden'),
            child: const KrogerScreen(planId: _plan),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await expectLater(
      find.byKey(const Key('golden')),
      matchesGoldenFile(
        'goldens/kroger_${name}_${brightness == Brightness.dark ? 'dark' : 'light'}.png',
      ),
    );
    _stopServing();
  }

  void bothThemes(String name, KrogerState Function() build) {
    for (final brightness in Brightness.values) {
      testWidgets('golden: kroger $name (${brightness.name})', (tester) async {
        await goldenTest(tester, name, brightness, build());
      });
    }
  }

  // The review: all three parts of the list, the delivery area, the quantity
  // control and the send action.
  bothThemes('review', () => _state());

  // Before the review is done: nothing approved yet, and no delivery area
  // resolved — so the Approve and Set-delivery-area actions are both drawn,
  // and the send action is not.
  bothThemes('to_review', () => _state(approved: false, located: false));

  // Before any matching run: every line waits under "Not matched yet", and
  // nothing is said to have no match on Kroger.
  bothThemes('not_matched_yet', () => _state(searched: false));

  // After the hand-off: the receipt, the cart action, and a list that can no
  // longer be edited.
  bothThemes('sent', () => _state(receiptStatus: 'sent'));

  // Nothing to offer: the cause is named, and no control is drawn that
  // cannot act.
  bothThemes(
    'unavailable',
    () => _state(unavailableReason: 'pro_required', connected: false),
  );

  testWidgets('every control on the screen announces itself', (tester) async {
    // A control a screen reader reaches with nothing to say is unusable, and
    // an icon-only one — the back arrow, the refresh, the two steppers — has
    // no text of its own for the reader to fall back on.
    final handle = tester.ensureSemantics();

    tester.view.physicalSize = const Size(_seWidth, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          krogerControllerProvider(
            _plan,
          ).overrideWith(() => _SeededController(_state())),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const KrogerScreen(planId: _plan),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tappable = find.byWidgetPredicate(
      (w) =>
          (w is ButtonStyleButton && w.enabled) ||
          (w is InkWell && w.onTap != null) ||
          (w is GestureDetector && w.onTap != null),
    );
    expect(tappable, findsWidgets);
    for (final element in tappable.evaluate()) {
      final node = tester.getSemantics(
        find.byElementPredicate((e) => e == element),
      );
      expect(
        _announces(node),
        isTrue,
        reason: 'a control with nothing to announce: ${element.widget}',
      );
    }
    handle.dispose();
  });
}

/// Whether a control's semantics say anything. The text can sit on the node
/// itself or on one below it — a Material button keeps its label in a child
/// node — so this asks the subtree, not just the root.
bool _announces(SemanticsNode node) {
  if ([node.label, node.tooltip, node.value].any((s) => s.trim().isNotEmpty)) {
    return true;
  }
  var found = false;
  node.visitChildren((child) {
    found = found || _announces(child);
    return !found;
  });
  return found;
}

class _SeededController extends KrogerController {
  _SeededController(this.seed);
  final KrogerState seed;
  @override
  Future<KrogerState> build(String planId) async => seed;
}

/// A flat swatch stands in for Kroger's photograph: the golden is here to pin
/// the slot the image occupies — uncropped, nothing drawn over it — and a real
/// product photo would only make the diff noisier.
Future<Uint8List> _swatchPng() async {
  const w = 200.0, h = 200.0;
  final recorder = ui.PictureRecorder();
  Canvas(recorder, const Rect.fromLTWH(0, 0, w, h))
    ..drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..color = AppColors.electrolyte,
    )
    ..drawRect(
      const Rect.fromLTWH(0, 0, w, h / 2),
      Paint()..color = AppColors.orange,
    );
  final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  return (await image.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
}

Future<void> _resolve(ImageProvider<Object> provider) {
  final done = Completer<void>();
  provider
      .resolve(ImageConfiguration.empty)
      .addListener(
        ImageStreamListener(
          (_, _) {
            if (!done.isCompleted) done.complete();
          },
          onError: (Object e, StackTrace? s) =>
              done.completeError(e, s ?? StackTrace.current),
        ),
      );
  return done.future;
}

void _serveOneImage(Uint8List body) =>
    debugNetworkImageHttpClientProvider = () => _FixedHttpClient(body);

/// Put the painting library back as it was; the framework asserts on this
/// before tear-downs run, so it cannot wait for one.
void _stopServing() {
  debugNetworkImageHttpClientProvider = null;
  PaintingBinding.instance.imageCache.clear();
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
