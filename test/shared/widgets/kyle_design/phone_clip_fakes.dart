/// A [PhoneClipPlayer] the test drives by hand, and a poster that needs no
/// asset bundle. Shared by the library's own test and the paywall screen's.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/data/phone_clip_frame.dart';

class FakePhoneClipPlayer implements PhoneClipPlayer {
  FakePhoneClipPlayer({this.endOnStart = false});

  /// Reports [PhoneClipPhase.ended] as soon as it is started: for tests that
  /// only want the page after the clip.
  final bool endOnStart;

  static const viewKey = ValueKey('fake_phone_clip.view');

  @override
  final ValueNotifier<PhoneClipPhase> phase = ValueNotifier(
    PhoneClipPhase.loading,
  );

  bool started = false;
  bool muted = false;
  bool disposed = false;

  @override
  Future<void> start() async {
    started = true;
    muted = true;
    if (endOnStart) phase.value = PhoneClipPhase.ended;
  }

  @override
  Widget buildView() => const SizedBox.expand(key: viewKey);

  @override
  void dispose() {
    disposed = true;
    phase.dispose();
  }
}

/// A 1×1 transparent PNG.
final testPoster = MemoryImage(
  Uint8List.fromList(const [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]),
);
