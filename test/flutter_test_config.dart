// Repo-wide golden comparator with a small per-pixel tolerance.
//
// Why: goldens are blessed on a developer machine and verified on the
// self-hosted M1 runner; the two rasterize glyph antialiasing slightly
// differently. tests-selfhosted.yml has carried two macro-dashboard goldens
// red at a 0.12% pixel diff since 2026-08-18 with the note "fix the goldens
// properly (per-host regen or a tolerance comparator)" — this is that
// comparator. The threshold is deliberately tight: 0.5% of pixels may
// differ; a real layout/color regression blows far past it.
//
// This does NOT relax the regeneration rule (a golden regenerates only
// after its design spec changes) — it only absorbs cross-host rendering
// noise on unchanged goldens.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const double _kGoldenDiffTolerance = 0.005; // 0.5% of pixels

class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed) return true;
    if (result.diffPercent <= _kGoldenDiffTolerance) {
      // ignore: avoid_print
      print(
        'golden $golden: within cross-host tolerance '
        '(${(result.diffPercent * 100).toStringAsFixed(3)}% <= '
        '${(_kGoldenDiffTolerance * 100).toStringAsFixed(1)}%)',
      );
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final previous = goldenFileComparator;
  if (previous is LocalFileComparator) {
    goldenFileComparator = _TolerantGoldenFileComparator(
      Uri.parse('${previous.basedir}dummy_test.dart'),
    );
  }
  await testMain();
}
