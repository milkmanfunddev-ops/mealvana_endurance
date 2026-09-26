import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The macro-dashboard surface's ground/ink pair and the card fills that
/// derive from it, as a [ThemeExtension] so the surface follows the app's
/// Light/Dark pick (Finding 119-003: the surface shipped dark-only and drew
/// cream text on the Light theme's cream Scaffold).
///
/// The dark values are the design SSOT's ratified tokens
/// (docs/ssot/spec/design/tokens.md: `blackberry` ground, `cream` ink) and
/// the reference rendering's card fills, unchanged. The light values invert
/// the pair; the light card fills are app-side choices awaiting Xuan, since
/// the bundle defers a light variant (app_materials.dart).
///
/// Accents (`electrolyte`, `orange`, `dragonfruit`, the macro-bar accents)
/// are theme-invariant and stay on `MeTokens`.
class MeSurfaceTokens extends ThemeExtension<MeSurfaceTokens> {
  const MeSurfaceTokens({
    required this.ground,
    required this.ink,
    required this.lift,
    required this.workoutDoneFill,
    required this.workoutPlannedFill,
    required this.workoutSkippedFill,
    required this.sheetFill,
    required this.popoverFill,
  });

  /// Surface ground; the Scaffold behind the timeline.
  final Color ground;

  /// Primary text and the base every dimmed label and hairline is an alpha
  /// of ([inkAlpha]).
  final Color ink;

  /// The translucent lift a raised card or pill adds over [ground]
  /// ([liftAlpha]); white over blackberry, blackberry over cream.
  final Color lift;

  /// Workout card fills (workout-card.md skins: done, planned, skipped).
  final Color workoutDoneFill;
  final Color workoutPlannedFill;
  final Color workoutSkippedFill;

  /// The breakdown pager sheet and its info popover.
  final Color sheetFill;
  final Color popoverFill;

  Color inkAlpha(double opacity) => ink.withValues(alpha: opacity);
  Color liftAlpha(double opacity) => lift.withValues(alpha: opacity);
  Color groundAlpha(double opacity) => ground.withValues(alpha: opacity);

  /// Today's values, verbatim: blackberry ground, cream ink.
  static const MeSurfaceTokens dark = MeSurfaceTokens(
    ground: AppColors.blackberry,
    ink: AppColors.cream,
    lift: AppColors.surfaceLight,
    workoutDoneFill: Color.fromRGBO(54, 38, 62, 1),
    workoutPlannedFill: Color.fromRGBO(55, 31, 57, 1),
    workoutSkippedFill: Color.fromRGBO(255, 255, 255, 0.03),
    sheetFill: Color.fromRGBO(48, 18, 44, 1),
    popoverFill: Color.fromRGBO(64, 26, 58, 1),
  );

  /// Cream ground, blackberry ink. Card fills: a done card lifts to white
  /// so its electrolyte border still reads; planned and skipped take the
  /// same faint plum lift dark gives them in white.
  static final MeSurfaceTokens light = MeSurfaceTokens(
    ground: AppColors.cream,
    ink: AppColors.blackberry,
    lift: AppColors.blackberry,
    workoutDoneFill: AppColors.surfaceLight,
    workoutPlannedFill: AppColors.blackberry.withValues(alpha: 0.05),
    workoutSkippedFill: AppColors.blackberry.withValues(alpha: 0.03),
    sheetFill: AppColors.cream,
    popoverFill: AppColors.surfaceLight,
  );

  @override
  MeSurfaceTokens copyWith({
    Color? ground,
    Color? ink,
    Color? lift,
    Color? workoutDoneFill,
    Color? workoutPlannedFill,
    Color? workoutSkippedFill,
    Color? sheetFill,
    Color? popoverFill,
  }) {
    return MeSurfaceTokens(
      ground: ground ?? this.ground,
      ink: ink ?? this.ink,
      lift: lift ?? this.lift,
      workoutDoneFill: workoutDoneFill ?? this.workoutDoneFill,
      workoutPlannedFill: workoutPlannedFill ?? this.workoutPlannedFill,
      workoutSkippedFill: workoutSkippedFill ?? this.workoutSkippedFill,
      sheetFill: sheetFill ?? this.sheetFill,
      popoverFill: popoverFill ?? this.popoverFill,
    );
  }

  @override
  MeSurfaceTokens lerp(ThemeExtension<MeSurfaceTokens>? other, double t) {
    if (other is! MeSurfaceTokens) return this;
    return MeSurfaceTokens(
      ground: Color.lerp(ground, other.ground, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      lift: Color.lerp(lift, other.lift, t)!,
      workoutDoneFill: Color.lerp(workoutDoneFill, other.workoutDoneFill, t)!,
      workoutPlannedFill: Color.lerp(
        workoutPlannedFill,
        other.workoutPlannedFill,
        t,
      )!,
      workoutSkippedFill: Color.lerp(
        workoutSkippedFill,
        other.workoutSkippedFill,
        t,
      )!,
      sheetFill: Color.lerp(sheetFill, other.sheetFill, t)!,
      popoverFill: Color.lerp(popoverFill, other.popoverFill, t)!,
    );
  }
}
