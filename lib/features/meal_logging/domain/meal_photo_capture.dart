/// What a photo costs to look at (ai-cost ticket 08, mp-473).
///
/// A vision model is billed by the pixels it is given. Every capture in the app
/// asked the platform picker for `maxWidth: 1000` and nothing else, which caps
/// one edge and lets the other run: the same scene shot in portrait arrived as
/// 1000x1333 where landscape arrived as 1000x750 — three quarters again as many
/// pixels for no more information. Capping both edges makes the picker fit the
/// photo inside a 1000x1000 box, keeping its aspect ratio, so the long edge is
/// 1000 whichever way the phone was held.
library;

/// The longest edge, in pixels, of any photo sent to a model.
///
/// 1,000 keeps enough detail for food and ingredient recognition. It is passed
/// as both `maxWidth` and `maxHeight`; the picker fits the image inside that
/// box rather than stretching it.
const double kPhotoLongEdgeMaxPx = 1000;

/// The size a photo of [width] x [height] is captured at under
/// [kPhotoLongEdgeMaxPx] — the picker's own rule, written down so it can be
/// tested without a camera.
///
/// A photo already inside the box is left alone; nothing is ever enlarged.
({double width, double height}) fitWithinLongEdge(
  double width,
  double height, {
  double maxEdge = kPhotoLongEdgeMaxPx,
}) {
  if (width <= 0 || height <= 0) return (width: width, height: height);
  final longest = width > height ? width : height;
  if (longest <= maxEdge) return (width: width, height: height);
  final scale = maxEdge / longest;
  return (width: width * scale, height: height * scale);
}

/// The pixels a model is billed for after [fitWithinLongEdge].
double billedPixels(double width, double height) {
  final fitted = fitWithinLongEdge(width, height);
  return fitted.width * fitted.height;
}
