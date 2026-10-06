// Seam: the shape of the app's entry points (spec: `.scratch/sentry/spec.md`
// § Bootstrap). Reads source, not behaviour: the four `main*.dart` files are
// thin calls to `bootstrap(flavor)`; no app code installs its own
// `FlutterError.onError`, `PlatformDispatcher.onError` or `runZonedGuarded`
// (the SDK's integrations own those so crashes arrive unhandled with the
// Flutter mechanism); and no Sentry DSN literal exists anywhere under `lib/`,
// so a build with no DSN can never report into the prod project.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final entryPoints = [
    'lib/main.dart',
    'lib/main_dev.dart',
    'lib/main_prod.dart',
    'lib/main_web.dart',
  ];

  String read(String path) => File(path).readAsStringSync();

  test('every entry point delegates to bootstrap(flavor)', () {
    for (final path in entryPoints) {
      final source = read(path);
      expect(source, contains('bootstrap(AppFlavor.'), reason: path);
      expect(source, isNot(contains('SentryFlutter.init')), reason: path);
      expect(source, isNot(contains('runApp(')), reason: path);
    }
  });

  test('no app code installs its own uncaught-error handlers', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final source = file.readAsStringSync();
      for (final forbidden in [
        'runZonedGuarded(',
        'FlutterError.onError =',
        'PlatformDispatcher.instance.onError =',
      ]) {
        expect(source, isNot(contains(forbidden)), reason: file.path);
      }
    }
  });

  test('no Sentry DSN literal exists under lib/', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    final dsnLiteral = RegExp(r'https://[0-9a-f]{16,}@o\d+\.ingest');
    for (final file in files) {
      expect(
        dsnLiteral.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: file.path,
      );
    }
  });

  test('bootstrap uses the SDK appRunner and no manual handlers', () {
    final source = read('lib/shared/core/bootstrap/bootstrap.dart');
    expect(source, contains('appRunner:'));
    expect(source, contains('sendDefaultPii = false'));
    expect(source, contains('propagateTraceparent = true'));
  });
}
