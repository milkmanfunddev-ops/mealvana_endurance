import 'package:flutter/material.dart';

/// Exact design tokens extracted from the onboarding HTML spec
/// (`../prototypes/onboarding/index.html`, commit 9d73588).
///
/// This is a PORT, not a redesign: every value here is the prototype's own
/// CSS value, not an approximation. Do not "harmonize" these with the app
/// theme — the spec wins. When the spec and app data conflict, the ruling
/// log lives in docs/features/onboarding-redesign/README.md.
abstract final class OnbTokens {
  // ── Colors (hex-exact from the spec) ──────────────────────────────────────
  /// #381633 — screen background plum.
  static const Color bg = Color(0xFF381633);

  /// #f8f6eb — cream: primary text, light surfaces, outlined borders.
  static const Color cream = Color(0xFFF8F6EB);

  /// #f78b14 — orange: primary CTA fill, headings, big numbers.
  static const Color orange = Color(0xFFF78B14);

  /// #1cf9cf — teal accent: links, insight lines, selected captions.
  static const Color teal = Color(0xFF1CF9CF);

  /// #4a2143 — raised card surface.
  static const Color cardRaised = Color(0xFF4A2143);

  /// #3a1835 — subtle card surface.
  static const Color cardSubtle = Color(0xFF3A1835);

  // Cream at the spec's exact alpha stops (rgba(248,246,235,.x)).
  static Color creamA(double a) => cream.withValues(alpha: a);

  /// rgba(247,139,20,.4) — orange at 40%, used for hairlines/accents.
  static const Color orange40 = Color(0x66F78B14);

  /// rgba(28,249,207,.3) — teal at 30%.
  static const Color teal30 = Color(0x4D1CF9CF);

  // ── Corner radii ──────────────────────────────────────────────────────────
  /// 100px — pill buttons (Continue, Connect, provider pills).
  static const double rPill = 100;

  /// 15px — standard card radius.
  static const double rCard = 15;

  /// 20px — large surfaces (sheets, hero cards).
  static const double rLarge = 20;

  /// 14px — inner tiles / option rows.
  static const double rTile = 14;

  /// 18px — select cards (gender, gut/sweat segments).
  static const double rSelect = 18;

  /// 12px — small chips.
  static const double rChip = 12;

  /// 8px — checkbox squares.
  static const double rCheckbox = 8;

  // ── Typography ────────────────────────────────────────────────────────────
  // Families. Sansita (700) = display headings. Apercu = body.
  // fontLabel = section headers / tile labels / attributions.
  // fontMono = numeric values + unit labels.
  static const String fontDisplay = 'Sansita';
  static const String fontBody = 'Apercu';

  // Compadre: the app's existing brand font family (already bundled and
  // shipping elsewhere — calendar, activities, fuel timeline). Backed by
  // Compadre-Demo-*.otf; licensing is tracked at the pubspec registration,
  // not here — this token just points at the family name.
  static const String fontLabel = 'Compadre';

  // Apercu Mono: bundled 2026-08 for the onboarding redesign (same foundry,
  // The Entente, as the already-licensed Apercu family).
  static const String fontMono = 'Apercu Mono';
}
