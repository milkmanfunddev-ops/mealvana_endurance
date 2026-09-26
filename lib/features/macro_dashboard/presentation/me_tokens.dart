import 'package:flutter/material.dart';

import '../../../theme/kyle_design/me_surface_tokens.dart';

export '../../../theme/kyle_design/me_surface_tokens.dart' show MeSurfaceTokens;

/// Design SSOT tokens — docs/ssot/spec/design/tokens.md (RATIFIED v1).
///
/// The named palette and its MEANING contracts. Code references tokens,
/// never raw values; a value lives in exactly one place — that table (and
/// this mirror of it). A component using [electrolyte] for a non-burn
/// element, or [dragonfruit] for a non-destructive one, fails conformance
/// even if it "looks right".
///
/// The ground/ink pair (`blackberry` / `cream` in the table) follows the
/// app theme: read it with [of] (Finding 119-003). Only the accents below
/// are theme-invariant statics.
abstract final class MeTokens {
  /// The surface's ground, ink and derived fills for the current theme.
  /// Without a registered [MeSurfaceTokens] (a bare `MaterialApp` in a
  /// test) the ratified dark values apply, so existing goldens hold.
  static MeSurfaceTokens of(BuildContext context) =>
      Theme.of(context).extension<MeSurfaceTokens>() ?? MeSurfaceTokens.dark;

  /// Burn / activity side (RULED Xuan 2026-08-14 — widened from
  /// verified-only): burn-side figures, workout accents, verified chips and
  /// the done-swipe fill. May not signify anything outside the burn/verified
  /// domain — never intake, never planning.
  static const Color electrolyte = Color.fromRGBO(28, 249, 207, 1);

  /// Energy & intake accent; planned-workout accent.
  static const Color orange = Color.fromRGBO(247, 139, 20, 1);

  /// Destructive. May not signify anything else.
  static const Color dragonfruit = Color.fromRGBO(220, 37, 151, 1);

  // Non-token accents used by the reference rendering's macro bars
  // (protein/fat per-macro accents — screenshot-held, not meaning-bound).
  static const Color proteinAccent = Color.fromRGBO(167, 139, 250, 1);
  static const Color fatAccent = Color.fromRGBO(236, 84, 153, 1);

  static Color electrolyteAlpha(double opacity) =>
      electrolyte.withValues(alpha: opacity);
  static Color orangeAlpha(double opacity) => orange.withValues(alpha: opacity);
}
