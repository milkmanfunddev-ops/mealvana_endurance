// The grid the athlete sees, checked against the description the judge draws
// with — `scripts/meal-images/lib/mosaic-geometry.json`.
//
// Two programs draw this mosaic: this widget, and pass 8's compositor, which
// renders it so a model can rate it. Every verdict in `meal_library` is a
// statement about the picture the compositor drew. If the two drift, those
// verdicts describe a picture nobody has ever seen and the whole measurement
// is worthless — so the geometry lives in one file and both sides answer to it.
//
// Mutation check: swap two cells, change the 3-tile split, drop the hairline or
// let a cell use BoxFit.contain, and either this test or
// `node --test scripts/meal-images/lib/mosaic-geometry.test.mjs` fails.
//
// A change to that JSON invalidates every stored `image_verdict`; the library
// must be re-judged. See docs/meal-images/README.md, "Compositor parity".

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/data/meal_image_mosaic.dart';

/// The one description of the grid, shared with the judging compositor.
const _geometryPath = 'scripts/meal-images/lib/mosaic-geometry.json';
const _compositorPath = 'scripts/meal-images/lib/compose-mosaic.mjs';

/// How far a sampled pixel may differ, per channel, between the two drawings.
/// Non-zero only because they resample with different filters.
const _channelTolerance = 8;

Map<String, dynamic> _geometry() =>
    jsonDecode(File(_geometryPath).readAsStringSync()) as Map<String, dynamic>;

KyleMealImageTile _tile(String url) => KyleMealImageTile(url: url, name: url);

Color _hex(String rrggbb) =>
    Color(0xFF000000 | int.parse(rrggbb.substring(1), radix: 16));

/// One pinned cell, read once out of the JSON so the rest of the file can talk
/// in rectangles rather than in casts.
Rect _cell(Map<String, dynamic> json) => Rect.fromLTWH(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
      (json['w'] as num).toDouble(),
      (json['h'] as num).toDouble(),
    );

List<Rect> _cellsOf(Map<String, dynamic> testCase) =>
    [for (final c in testCase['cells'] as List) _cell(c as Map<String, dynamic>)];

/// The default 800x600 surface is smaller than the judging canvas, and a
/// mosaic squeezed by its parent is not the mosaic under test.
void _surface(WidgetTester t, double width, double height) {
  t.view.devicePixelRatio = 1.0;
  t.view.physicalSize = Size(width + 40, height + 40);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

void main() {
  final geometry = _geometry();
  final cases = (geometry['cases'] as List).cast<Map<String, dynamic>>();

  group('the grid matches the shared description', () {
    for (final c in cases) {
      final n = c['tiles'] as int;
      final width = (c['width'] as num).toDouble();
      final height = (c['height'] as num).toDouble();
      final cells = _cellsOf(c);

      testWidgets('$n tiles at ${width.toInt()}x${height.toInt()}', (t) async {
        _surface(t, width, height);
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  height: height,
                  child: MealImageMosaic(
                    mode: KyleMealImageMode.mosaic,
                    tiles: [for (var i = 0; i < n; i++) _tile('t$i')],
                  ),
                ),
              ),
            ),
          ),
        );

        final images = find.byType(Image);
        expect(images, findsNWidgets(n));

        final origin = t.getTopLeft(find.byType(MealImageMosaic));
        for (var i = 0; i < n; i++) {
          // Which tile, as well as where: the rectangles are identical under
          // any permutation of the tiles, so order has to be asserted too or a
          // swapped pair reads as a match.
          expect(
            (t.widget<Image>(images.at(i)).image as NetworkImage).url,
            't$i',
            reason: 'cell $i shows the wrong tile',
          );
          final r = t.getRect(images.at(i)).shift(-origin);
          final want = cells[i];
          expect(r.left, moreOrLessEquals(want.left), reason: 'cell $i left');
          expect(r.top, moreOrLessEquals(want.top), reason: 'cell $i top');
          expect(r.width, moreOrLessEquals(want.width), reason: 'cell $i width');
          expect(r.height, moreOrLessEquals(want.height), reason: 'cell $i height');
        }
      });
    }
  });

  testWidgets('every cell crops the way the description says', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: MealImageMosaic(
              mode: KyleMealImageMode.mosaic,
              tiles: [_tile('a'), _tile('b'), _tile('c'), _tile('d')],
            ),
          ),
        ),
      ),
    );
    final fit = BoxFit.values.byName(geometry['fit'] as String);
    for (final img in t.widgetList<Image>(find.byType(Image))) {
      expect(img.fit, fit);
    }
  });

  testWidgets('the hairline is the width the description says', (t) async {
    // Read off the gap between two cells rather than off the divider widget, so
    // replacing the divider with a border or a padding still fails here.
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: MealImageMosaic(
              mode: KyleMealImageMode.mosaic,
              tiles: [_tile('a'), _tile('b')],
            ),
          ),
        ),
      ),
    );
    final gap = ((geometry['separator'] as Map)['widthPx'] as num).toDouble();
    final left = t.getRect(find.byType(Image).at(0));
    final right = t.getRect(find.byType(Image).at(1));
    expect(right.left - left.right, moreOrLessEquals(gap));
  });

  for (final theme in const [Brightness.light, Brightness.dark]) {
    testWidgets('the hairline is the colour the description says in ${theme.name}',
        (t) async {
      // The compositor draws its canvas in this colour before pasting any cell,
      // so a divergence here is a different picture at every seam — and the
      // pixel sweep below deliberately looks away from seams.
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: theme),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 200,
              child: MealImageMosaic(
                mode: KyleMealImageMode.mosaic,
                tiles: [_tile('a'), _tile('b'), _tile('c'), _tile('d')],
              ),
            ),
          ),
        ),
      );
      final dividers = t.widgetList<Container>(
        find.descendant(
          of: find.byType(MealImageMosaic),
          matching: find.byType(Container),
        ),
      );
      expect(dividers, isNotEmpty);
      final want = _hex((geometry['separator'] as Map)[theme.name] as String);
      for (final d in dividers) {
        expect(d.color, want);
      }
    });
  }

  testWidgets('the grid never holds more tiles than the description allows',
      (t) async {
    final max = geometry['maxTiles'] as int;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            height: 200,
            child: MealImageMosaic(
              mode: KyleMealImageMode.mosaic,
              tiles: [for (var i = 0; i <= max; i++) _tile('t$i')],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsNWidgets(max));
  });

  testWidgets(
    'the composite the judge sees is the picture the widget draws',
    (t) async {
      // The strongest form of the claim: same tiles in, same pixels out. If
      // this passes, a stored verdict really is a verdict on what an athlete
      // would see.
      final dir = Directory.systemTemp.createTempSync('mosaic-parity-');
      addTearDown(() => dir.deleteSync(recursive: true));

      const size = 768.0;
      const n = 4;
      late Uint8List widgetPixels;
      late Uint8List compositePixels;

      _surface(t, size, size);

      await t.runAsync(() async {
        // Four sources, each four flat quadrants, deliberately wider than they
        // are tall: a cell that scaled instead of covering, or cropped from a
        // corner instead of the centre, lands on different colours.
        final files = <String>[];
        for (var i = 0; i < n; i++) {
          final bytes = await _quadrantPng(i);
          final f = File('${dir.path}/tile$i.png')..writeAsBytesSync(bytes);
          files.add(f.path);
        }

        _serveLocally(files);
        // Warm every tile before the widget asks for it, so the capture below
        // is a picture of four decoded photographs rather than of a frame that
        // happened to arrive first.
        for (final f in files) {
          await _resolve(NetworkImage('https://tiles.test$f'));
        }

        await t.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: const ValueKey('parity'),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: MealImageMosaic(
                    mode: KyleMealImageMode.mosaic,
                    tiles: [for (final f in files) _tile('https://tiles.test$f')],
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pump();
        await t.pump();
        expect(t.takeException(), isNull, reason: 'the tiles must all load');
        final boundary = t.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('parity')),
        );
        final shot = await boundary.toImage();
        widgetPixels = (await shot.toByteData(format: ui.ImageByteFormat.rawRgba))!
            .buffer
            .asUint8List();
        _stopServing();

        // The same tiles, through the compositor pass 8 uses.
        final out = '${dir.path}/composite.png';
        final r = await Process.run('node', [_compositorPath, '--out', out, ...files]);
        expect(r.exitCode, 0, reason: 'compositor: ${r.stderr}');
        final composite = await decodeImageFromList(
          File(out).readAsBytesSync(),
        );
        compositePixels =
            (await composite.toByteData(format: ui.ImageByteFormat.rawRgba))!
                .buffer
                .asUint8List();
      });

      final cells = _cellsOf(
        cases.firstWhere((c) => c['tiles'] == n && c['width'] == size.toInt()),
      );

      // Four points per cell, one per quadrant of the cropped source, kept
      // clear of every seam so filtering differences cannot account for a miss.
      for (var i = 0; i < cells.length; i++) {
        final c = cells[i];
        for (final fx in const [0.25, 0.75]) {
          for (final fy in const [0.25, 0.75]) {
            final x = (c.left + c.width * fx).round();
            final y = (c.top + c.height * fy).round();
            final a = _pixel(widgetPixels, x, y, size.toInt());
            final b = _pixel(compositePixels, x, y, size.toInt());
            expect(
              _within(a, b, _channelTolerance),
              isTrue,
              reason: 'cell $i at ($x,$y): widget $a, composite $b',
            );
          }
        }
      }

      // And a sweep of the whole canvas, so a difference outside the sampled
      // quadrants cannot hide either.
      var checked = 0;
      var differing = 0;
      for (var y = 4; y < size.toInt(); y += 8) {
        for (var x = 4; x < size.toInt(); x += 8) {
          if (_nearSeam(x, y, cells)) continue;
          checked++;
          if (!_within(
            _pixel(widgetPixels, x, y, size.toInt()),
            _pixel(compositePixels, x, y, size.toInt()),
            _channelTolerance,
          )) {
            differing++;
          }
        }
      }
      expect(checked, greaterThan(1000));
      expect(differing / checked, lessThan(0.01),
          reason: '$differing of $checked sampled pixels differ');
    },
    // The compositor needs node and python3 with Pillow. Skipped rather than
    // failed where they are absent; the geometry tests above still hold both
    // sides to the same description.
    skip: !_compositorAvailable(),
  );
}

/// Load an image provider to completion, failing loudly rather than quietly
/// painting nothing.
Future<void> _resolve(ImageProvider provider) {
  final done = Completer<void>();
  provider.resolve(ImageConfiguration.empty).addListener(
        ImageStreamListener(
          (_, __) {
            if (!done.isCompleted) done.complete();
          },
          onError: (Object e, StackTrace? s) =>
              done.completeError(e, s ?? StackTrace.current),
        ),
      );
  return done.future;
}

bool _compositorAvailable() {
  if (!File(_compositorPath).existsSync()) return false;
  try {
    return Process.runSync('python3', ['-c', 'import PIL']).exitCode == 0 &&
        Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}

List<int> _pixel(Uint8List rgba, int x, int y, int width) {
  final o = (y * width + x) * 4;
  return [rgba[o], rgba[o + 1], rgba[o + 2]];
}

bool _within(List<int> a, List<int> b, int tolerance) {
  for (var i = 0; i < 3; i++) {
    if ((a[i] - b[i]).abs() > tolerance) return false;
  }
  return true;
}

/// Within 3px of any cell edge, where the two renderers' antialiasing of the
/// hairline legitimately differs.
bool _nearSeam(int x, int y, List<Rect> cells) {
  for (final c in cells) {
    if ((x - c.left).abs() < 3 || (x - c.right).abs() < 3) return true;
    if ((y - c.top).abs() < 3 || (y - c.bottom).abs() < 3) return true;
  }
  return false;
}

/// A 400x200 PNG of four flat quadrants, distinct across tiles.
Future<Uint8List> _quadrantPng(int seed) async {
  const w = 400.0, h = 200.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));
  const quadrants = [
    Rect.fromLTWH(0, 0, w / 2, h / 2),
    Rect.fromLTWH(w / 2, 0, w / 2, h / 2),
    Rect.fromLTWH(0, h / 2, w / 2, h / 2),
    Rect.fromLTWH(w / 2, h / 2, w / 2, h / 2),
  ];
  for (var q = 0; q < 4; q++) {
    final colour = HSVColor.fromAHSV(1, ((seed * 4 + q) * 22.5) % 360, 0.85, 0.9)
        .toColor();
    canvas.drawRect(quadrants[q], Paint()..color = colour);
  }
  final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  return (await image.toByteData(format: ui.ImageByteFormat.png))!
      .buffer
      .asUint8List();
}

/// Serve the widget's `Image.network` calls from local files, so the widget and
/// the compositor are given byte-identical sources.
void _serveLocally(List<String> files) {
  final bodies = {for (final f in files) f: File(f).readAsBytesSync()};
  debugNetworkImageHttpClientProvider = () => _FileHttpClient(bodies);
}

/// Put the painting library back as it was; the framework asserts on this
/// before tear-downs run, so it cannot wait for one.
void _stopServing() {
  debugNetworkImageHttpClientProvider = null;
  PaintingBinding.instance.imageCache.clear();
}

class _FileHttpClient implements HttpClient {
  _FileHttpClient(this.bodies);
  final Map<String, Uint8List> bodies;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _FileHttpRequest(bodies[url.path]!);

  @override
  bool autoUncompress = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FileHttpRequest implements HttpClientRequest {
  _FileHttpRequest(this.body);
  final Uint8List body;

  @override
  final HttpHeaders headers = _NullHeaders();

  @override
  Future<HttpClientResponse> close() async => _FileHttpResponse(body);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NullHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FileHttpResponse extends Stream<List<int>> implements HttpClientResponse {
  _FileHttpResponse(this.body);
  final Uint8List body;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => body.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => _NullHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(body).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
