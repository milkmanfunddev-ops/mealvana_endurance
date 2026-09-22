/// What a meal photo costs to look at (ai-cost ticket 08, mp-473).
///
/// Every capture asked the picker for `maxWidth: 1000` and nothing else, so the
/// same scene shot in portrait arrived taller — and billed for the extra pixels.
/// Capping both edges fits the photo inside a 1000x1000 box, so the long edge is
/// 1,000 whichever way the phone was held and the two orientations bill alike.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_photo_capture.dart';

void main() {
  test('the cap is 1,000 px', () {
    expect(kPhotoLongEdgeMaxPx, 1000);
  });

  test('a portrait and a landscape shot of the same scene bill alike', () {
    // One 12 MP sensor, held two ways.
    final portrait = billedPixels(3024, 4032);
    final landscape = billedPixels(4032, 3024);
    expect(portrait, landscape);
    final difference = (portrait - landscape).abs() / landscape;
    expect(difference, lessThan(0.10), reason: 'within 10% of each other');
  });

  test('the long edge lands on 1,000 either way round', () {
    final portrait = fitWithinLongEdge(3024, 4032);
    expect(portrait.height, 1000);
    expect(portrait.width, closeTo(750, 1));
    final landscape = fitWithinLongEdge(4032, 3024);
    expect(landscape.width, 1000);
    expect(landscape.height, closeTo(750, 1));
  });

  test('capping the width alone is what made portrait cost more', () {
    // The old rule: scale until the WIDTH is 1000, whatever the height becomes.
    double oldRulePixels(double w, double h) {
      if (w <= kPhotoLongEdgeMaxPx) return w * h;
      final scale = kPhotoLongEdgeMaxPx / w;
      return (w * scale) * (h * scale);
    }

    final portrait = oldRulePixels(3024, 4032);
    final landscape = oldRulePixels(4032, 3024);
    expect(
      portrait / landscape,
      greaterThan(1.10),
      reason: 'the old rule billed portrait more than 10% above landscape',
    );
  });

  test('a photo already inside the box is left alone, never enlarged', () {
    expect(fitWithinLongEdge(800, 600), (width: 800.0, height: 600.0));
    expect(fitWithinLongEdge(1000, 1000), (width: 1000.0, height: 1000.0));
  });

  test('a square photo fits exactly', () {
    expect(fitWithinLongEdge(4000, 4000), (width: 1000.0, height: 1000.0));
  });
}
