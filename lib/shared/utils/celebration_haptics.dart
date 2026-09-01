import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Shared haptic pattern played alongside celebration visuals (confetti,
/// success overlays).
///
/// A single impact reads as a plain "tap acknowledged"; a celebration wants a
/// short rhythm. [CelebrationHaptics.play] fires one heavy impact followed by
/// two lighter ones so the burst lines up with the confetti launching.
///
/// Only mobile embedders implement the haptic platform channel, so calls are
/// skipped elsewhere and any platform failure is swallowed — a missing buzz
/// must never break the celebration it accompanies.
class CelebrationHaptics {
  const CelebrationHaptics._();

  /// Gap between the impacts in the celebration pattern.
  static const Duration _beat = Duration(milliseconds: 100);

  /// Plays the celebration pattern. Fire-and-forget: callers do not need to
  /// await this, and it never throws.
  static Future<void> play() async {
    if (!_isSupported) return;

    try {
      await HapticFeedback.heavyImpact();
      await Future<void>.delayed(_beat);
      await HapticFeedback.lightImpact();
      await Future<void>.delayed(_beat);
      await HapticFeedback.lightImpact();
    } catch (_) {
      // Haptics are cosmetic — a missing platform implementation is not an
      // error worth surfacing.
    }
  }

  /// Haptics exist only on the mobile embedders. Web is a no-op by design and
  /// desktop embedders have no implementation for the channel at all.
  static bool get _isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
  }
}
