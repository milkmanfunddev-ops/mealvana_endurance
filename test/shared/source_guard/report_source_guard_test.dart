// Seam 2, the source guard (spec: `.scratch/sentry/spec.md` § Enforcement,
// § Testing Decisions; ticket 04). Reads source, not behaviour: walks
// `lib/**.dart` and fails when a catch block neither escapes (rethrow/throw)
// nor reports through `Report` or a legacy alias, when `print`/`debugPrint`
// sits inside a catch, or when the Sentry SDK is imported outside
// `lib/shared/services/report/` and `lib/shared/core/bootstrap/`.
//
// The matching rules, including what counts as reported, are written out at
// the top of `source_guard.dart`. The allow-list beside this file,
// `allow_list.md`, has a `baseline` section (every violation on the day the
// guard landed) and a `reasoned` section (deliberate silence, one reason per
// line). The guard is a ratchet: a new violation anywhere is red, and so is a
// baseline entry that no longer matches a site, so the list can only shrink
// and only by fixing code. A migration ticket deletes its entries as it moves
// each site to `Report`.
//
// Second half of the file: self-tests that prove the matcher on inline
// snippets, so the rules are demonstrated rather than assumed.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_guard.dart';

const _allowListPath = 'test/shared/source_guard/allow_list.md';

List<File> _appSources() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where(
      (f) => !f.path.endsWith('.g.dart') && !f.path.endsWith('.freezed.dart'),
    )
    .where((f) => !f.path.startsWith('lib/features/_archived/'))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  group('report source guard', () {
    late AllowList allowList;
    late List<Finding> findings;
    late int catchCount;

    setUpAll(() {
      allowList = AllowList.parse(File(_allowListPath).readAsStringSync());
      findings = <Finding>[];
      catchCount = 0;
      for (final file in _appSources()) {
        final source = file.readAsStringSync();
        catchCount += findCatchBlocks(source).length;
        findings.addAll(scanSource(file.path, source));
      }
    });

    test('allow-list parses with no malformed lines', () {
      expect(allowList.errors, isEmpty, reason: allowList.errors.join('\n'));
    });

    test('the scan sees the app (sanity floor)', () {
      // Guards against a silent pass if the walk ever returns nothing.
      expect(catchCount, greaterThan(100));
    });

    test('every unreported catch, print-in-catch and SDK import is listed', () {
      final result = reconcile(findings, allowList);
      final byKind = <FindingKind, List<Finding>>{};
      for (final f in result.unlisted) {
        byKind.putIfAbsent(f.kind, () => []).add(f);
      }
      final report = StringBuffer();
      byKind.forEach((kind, list) {
        report.writeln('${list.length} new ${kind.name}:');
        for (final f in list) {
          report.writeln('  $f');
        }
      });
      expect(
        result.unlisted,
        isEmpty,
        reason:
            'New violations. Fix the site (report through Report, rethrow, '
            'drop the print, move the import) or, for deliberate silence, add '
            'a `reasoned` entry with a reason in $_allowListPath.\n$report',
      );
    });

    test('no allow-list entry is stale (the list only ratchets down)', () {
      final result = reconcile(findings, allowList);
      final report = result.stale.entries
          .map((e) => '  ${e.key}  (x${e.value})')
          .join('\n');
      expect(
        result.stale,
        isEmpty,
        reason:
            'These allow-list entries match no site any more; delete them '
            'from $_allowListPath so the baseline keeps shrinking:\n$report',
      );
    });
  });

  group('matcher self-test', () {
    const path = 'lib/x.dart';

    List<Finding> scan(String body) => scanSource(path, body);

    test('an empty catch is unreported', () {
      final findings = scan('''
void f() {
  try {
    g();
  } catch (_) {}
}
''');
      expect(findings.map((f) => f.kind), [FindingKind.unreportedCatch]);
      expect(findings.single.signature, '} catch (_) {}');
      expect(findings.single.line, 4);
    });

    test('a rethrow is an escape, not a violation', () {
      final findings = scan('''
void f() {
  try {
    g();
  } catch (e) {
    cleanUp();
    rethrow;
  }
}
''');
      expect(findings, isEmpty);
    });

    test('throwing a new error is also an escape', () {
      final findings = scan('''
void f() {
  try {
    g();
  } on FormatException catch (e) {
    throw StateError('bad: \$e');
  }
}
''');
      expect(findings, isEmpty);
    });

    test('a Report call is reported', () {
      for (final call in [
        'ref.read(reportProvider).fault(e, stackTrace: st);',
        '_report.degraded(e);',
        'report.note("skipped");',
        'SentryReport.global.note("skipped");',
      ]) {
        final findings = scan('''
void f() {
  try {
    g();
  } catch (e, st) {
    $call
  }
}
''');
        expect(findings, isEmpty, reason: call);
      }
    });

    test('a legacy alias is reported until ticket 10', () {
      for (final call in [
        '_logger.error("x", error: e);',
        'logger.warning("x");',
        'DebugLogger.error("x", error: e);',
        'DebugLogger.warning("x");',
        '_sentry.reportCriticalError(e);',
        'await sentry.captureMessage("x");',
        'Sentry.captureException(e);',
      ]) {
        final findings = scan('''
void f() {
  try {
    g();
  } catch (e) {
    $call
  }
}
''');
        expect(findings, isEmpty, reason: call);
      }
    });

    test('info and debug logging alone is still unreported', () {
      for (final call in [
        '_logger.info("x");',
        'DebugLogger.info("x");',
        'logger.debug("x");',
      ]) {
        final findings = scan('''
void f() {
  try {
    g();
  } catch (e) {
    $call
  }
}
''');
        expect(
          findings.map((f) => f.kind),
          [FindingKind.unreportedCatch],
          reason: call,
        );
      }
    });

    test('a print inside a catch is its own finding', () {
      final findings = scan('''
void f() {
  try {
    g();
  } catch (e) {
    print('failed: \$e');
    _report.fault(e);
  }
}
''');
      // Reported, so no unreportedCatch; the print still counts.
      expect(findings.map((f) => f.kind), [FindingKind.printInCatch]);
    });

    test('a debugPrint in an unreported catch gives both findings', () {
      final findings = scan('''
void f() {
  try {
    g();
  } catch (e) {
    debugPrint('failed');
  }
}
''');
      expect(
        findings.map((f) => f.kind),
        [FindingKind.unreportedCatch, FindingKind.printInCatch],
      );
    });

    test('a bare `on X {` clause after a try block is a catch', () {
      final findings = scan('''
void f() {
  try {
    g();
  } on TimeoutException {
    retry();
  }
}
''');
      expect(findings.map((f) => f.kind), [FindingKind.unreportedCatch]);
      expect(findings.single.signature, '} on TimeoutException {');
    });

    test('a mixin `on` clause is not a catch', () {
      final findings = scan('''
class A {}

mixin B on A {
  void g() {}
}

extension on String {
  int get n => length;
}
''');
      expect(findings, isEmpty);
    });

    test('catch and print inside comments and strings do not count', () {
      final findings = scan('''
/// } catch (e) { print('x'); }
void f() {
  final s = '} catch (e) {';
  try {
    g();
  } catch (e) {
    final msg = 'print(\$e) and a } brace';
    _report.fault(e, message: msg);
  }
}
''');
      expect(findings, isEmpty);
    });

    test('braces in strings do not break the block boundary', () {
      // If the `}` in the string closed the block early, the report call
      // would fall outside it and the catch would read as unreported.
      final findings = scan('''
void f() {
  try {
    g();
  } catch (e) {
    final a = "}";
    final b = '\${e.toString()} }';
    _report.fault(e);
  }
}
''');
      expect(findings, isEmpty);
    });

    test('an inner reported catch counts for its outer block', () {
      final findings = scan('''
void f() {
  try {
    g();
  } catch (e) {
    try {
      h();
    } catch (inner) {
      _report.fault(inner);
    }
  }
}
''');
      expect(findings, isEmpty);
    });

    test('a Sentry SDK import outside the two permitted dirs is a finding', () {
      const src = "import 'package:sentry_flutter/sentry_flutter.dart';\n";
      expect(
        scanSource('lib/features/x/y.dart', src).map((f) => f.kind),
        [FindingKind.sentryImport],
      );
      expect(scanSource('lib/shared/services/report/report.dart', src),
          isEmpty);
      expect(scanSource('lib/shared/core/bootstrap/bootstrap.dart', src),
          isEmpty);
    });

    test('the allow-list ratchets: unlisted is red, stale is red', () {
      final f = Finding(
        kind: FindingKind.unreportedCatch,
        path: path,
        line: 9,
        signature: '} catch (_) {}',
      );
      final listed = AllowList.parse('''
## baseline
unreportedCatch $path :: } catch (_) {}
''');
      expect(reconcile([f], listed).clean, isTrue);
      // Two sites, one entry: the second is a new violation.
      expect(reconcile([f, f], listed).unlisted, hasLength(1));
      // Entry kept, site fixed: stale.
      expect(reconcile([], listed).stale, {f.key: 1});
      // Reasoned entries need a reason; baseline entries must not have one.
      final bad = AllowList.parse('''
## reasoned
unreportedCatch $path :: } catch (_) {}
## baseline
unreportedCatch $path :: } catch (_) {} :: not allowed here
''');
      expect(bad.errors, hasLength(2));
    });
  });
}
