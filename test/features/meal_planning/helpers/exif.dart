/// Reading a JPEG's metadata the way a stranger would.
///
/// Shared by the photo-preparation test and the seam-2 upload test: both have
/// to prove the same thing, which is that a Tester's location never leaves the
/// phone, and they should not each carry their own copy of the check.
library;

import 'dart:typed_data';

/// Whether [bytes] carry an APP1 EXIF segment at all.
///
/// Scanning the raw bytes rather than asking a decoder is the honest check: a
/// decoder that skipped or ignored the segment would still let it ship.
bool carriesExifSegment(Uint8List bytes) {
  const signature = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]; // "Exif\0\0"
  for (var i = 0; i + signature.length <= bytes.length; i++) {
    var hit = true;
    for (var j = 0; j < signature.length; j++) {
      if (bytes[i + j] != signature[j]) {
        hit = false;
        break;
      }
    }
    if (hit) return true;
  }
  return false;
}
