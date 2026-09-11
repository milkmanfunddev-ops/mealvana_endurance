/// Design SSOT materials — `docs/ssot/spec/design/tokens.md` §Materials
/// (RULED Xuan 2026-09-06, post-ratification addition; ships with
/// `home-shell@v1`).
///
/// The ONE registry for the translucent-blur materials. Raw values live here
/// and only here — components reference these constants, never inline alpha
/// values (home-shell handoff §3). Conformance reference is the app's own
/// goldens (`BackdropFilter` + painted rim), never a pixel match to HTML/iOS.
///
/// * **glass** — floating chrome: pills, circular buttons, and the compact
///   header row itself (RULED 2026-09-06: the export's blur-14 blackberry
///   fade on that row is superseded).
/// * **glass-sheet** — summoned surfaces (the calendar sheet), including its
///   scrim: `blackberry` 60% — load-bearing, not cosmetic; every future
///   summoned glass surface inherits it.
/// * **lensing** — edge refraction on glass chrome, contractual only where
///   the invoking component spec names it (first: tab-bar switch transition).
///   Defined by observable properties (magnitude, falloff, timing) — never
///   "matches iOS".
///
/// Boundaries (unchanged): timeline/content cards NEVER take glass — solid
/// fill + hairline stays their treatment. Dark-first: values are for the
/// `blackberry` ground; a light variant is deferred (bundle excludes).
library;

import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// Raw material constants from tokens.md §Materials. No widget code here —
/// the painting composite lives in
/// `lib/shared/widgets/kyle_design/materials/glass.dart`.
class AppMaterials {
  AppMaterials._();

  // ---- glass: backdrop chain (blur 4 · saturate 1.8 · brightness 1.12) ----
  static const double glassBlurSigma = 4.0;
  static const double glassSaturation = 1.8;
  static const double glassBrightness = 1.12;

  /// The composed backdrop filter: blur, then saturate + brighten. Content
  /// behind stays recognizable, gets more vivid and slightly BRIGHTER —
  /// never darker.
  static ImageFilter glassBackdropFilter() => ImageFilter.compose(
        outer: ColorFilter.matrix(
          _saturationBrightnessMatrix(glassSaturation, glassBrightness),
        ),
        inner: ImageFilter.blur(
          sigmaX: glassBlurSigma,
          sigmaY: glassBlurSigma,
        ),
      );

  // ---- glass: fill (vertical gradient, cream 7% → 2% alpha) ----
  static final Color glassFillTop = AppColors.cream.withValues(alpha: 0.07);
  static final Color glassFillBottom = AppColors.cream.withValues(alpha: 0.02);

  // ---- glass-sheet: fill (cream 4% → 1%) ----
  static final Color sheetFillTop = AppColors.cream.withValues(alpha: 0.04);
  static final Color sheetFillBottom = AppColors.cream.withValues(alpha: 0.01);

  /// glass-sheet top corner radius.
  static const double sheetTopRadius = 24.0;

  /// The sheet's OWN backdrop chain (RULED Xuan 2026-09-07, on-Rad review:
  /// "reads a little dirty" — the standard glass chain's weak blur +
  /// saturation boost kept the page legible through the sheet). Heavy blur
  /// melts the page into soft color fields; no brightening; the veil below
  /// adds body while keeping the sheet clearly translucent.
  static const double sheetBlurSigma = 18.0;
  static const double sheetSaturation = 1.2;
  static final Color sheetVeil = AppColors.blackberry.withValues(alpha: 0.30);

  static ImageFilter sheetBackdropFilter() => ImageFilter.compose(
        outer: ColorFilter.matrix(
          _saturationBrightnessMatrix(sheetSaturation, 1.0),
        ),
        inner: ImageFilter.blur(
          sigmaX: sheetBlurSigma,
          sigmaY: sheetBlurSigma,
        ),
      );

  // ---- rim, light source top ----
  /// 1 px inner specular highlight: cream 40% across the top arc fading to
  /// cream 8% at the sides.
  static const double rimWidth = 1.0;
  static final Color rimHighlightTop = AppColors.cream.withValues(alpha: 0.40);
  static final Color rimHighlightSide = AppColors.cream.withValues(alpha: 0.08);

  /// Bottom inner shadow: inset 0 −1px 1px black 25%.
  static final Color rimShadowBottom =
      const Color(0xFF000000).withValues(alpha: 0.25);

  // ---- outer lift (under floating pills only): 0 8px 24px black 25% ----
  static final List<BoxShadow> glassLift = [
    BoxShadow(
      color: const Color(0xFF000000).withValues(alpha: 0.25),
      offset: const Offset(0, 8),
      blurRadius: 24,
    ),
  ];

  // ---- glass-sheet scrim: blackberry 60% — rgba(56, 22, 51, 0.6) ----
  /// RULED 2026-09-06: the export governs; the intake's proposed black ~35%
  /// is corrected by that ruling. Between the page and the sheet.
  static final Color sheetScrim = AppColors.blackberry.withValues(alpha: 0.60);

  /// The summoned sheet's grabber bar at rest: cream 30% (the calendar
  /// sheet's value, carried by the Vana sheet so the two share it).
  static final Color sheetGrabber = AppColors.cream.withValues(alpha: 0.30);

  // ---- liquid-glass bubble (tab-bar active highlight; PROPOSED Xuan
  // 2026-09-06, Bevel recording — intake
  // 2026-09-06-tab-bar-liquid-bubble, pending ratification) ----
  /// The active tab's raised glass lens: refracts the bar's labels and the
  /// page behind it (Impeller shader; flat FakeGlass fallback on Skia, so
  /// tests and goldens render deterministically).
  static const double tabLensThickness = 16.0;

  /// Extra glass thickness while the lens is in motion (stronger refraction
  /// mid-transit, the Bevel look).
  static const double tabLensTransitThicknessBoost = 14.0;
  static const double tabLensRefractiveIndex = 1.40;
  static const double tabLensChromaticAberration = 2.0;
  static const double tabLensBlur = 1.5;
  static const double tabLensSaturation = 1.15;
  static const double tabLensLightIntensity = 0.4;

  /// How far the bubble bulges past the bar's border at rest.
  static const double tabLensBulgePx = 6.0;

  /// The focused tab's content scales up slightly on the lens (readability
  /// + the magnified-through-glass read; Xuan iteration 2026-09-07 #1).
  static const double tabLensFocusZoom = 1.08;

  /// Dark fill under the tab bar's blur (Xuan iteration 2026-09-07 #2 —
  /// reduce the bar's transparency so busy content behind never outshouts
  /// the labels; the Bevel bar is a dark fill + blur).
  static final Color tabBarBackdropDim =
      AppColors.blackberry.withValues(alpha: 0.55);

  /// The dimmed bar's OWN backdrop chain: heavy blur, NO saturation boost
  /// (the standard glass chain saturates 1.8x + brightens — it amplifies
  /// exactly the bright content the bar needs to mute; the teal chip in
  /// Xuan's IMG_8941 burned straight through it).
  static const double tabBarBlurSigma = 12.0;
  static const double tabBarSaturation = 1.1;

  static ImageFilter tabBarBackdropFilter() => ImageFilter.compose(
        outer: ColorFilter.matrix(
          _saturationBrightnessMatrix(tabBarSaturation, 1.0),
        ),
        inner: ImageFilter.blur(
          sigmaX: tabBarBlurSigma,
          sigmaY: tabBarBlurSigma,
        ),
      );

  /// EXTRA bulge while the lens travels or is dragged — Bevel's lens spills
  /// well over the bar in motion and settles back down.
  static const double tabLensTransitBulgePx = 10.0;

  // ---- lensing (tokens §Materials, boundary lifted 2026-09-06) ----
  /// Distortion magnitude of the traveling-highlight lens: the backdrop
  /// inside the lens is displaced by up to this many px against the travel
  /// direction (observable property, pinned in `home-shell.gestures.yaml`
  /// tb6). Implemented as a matrix backdrop filter (the `RawMagnifier`
  /// precedent) — renders on every backend, unlike `ImageFilter.shader`.
  static const double lensDisplacementPx = 6.0;

  /// Falloff: an outer feather band of this width (px) renders at half the
  /// displacement, easing the distortion back to identity at the lens edge.
  static const double lensFalloffPx = 8.0;

  // ---- top-fade dissolve (compact header zone; RULED Xuan 2026-09-06 #3,
  // Bevel-reference review — reinstates the export's drawn treatment) ----
  /// Total height of the dissolve zone (export-exact: 104 px over the 64 px
  /// row). Content blurs and dims progressively as it scrolls beneath —
  /// no band, no edge.
  static const double topFadeHeight = 104.0;

  /// Peak blur at the very top of the dissolve (export: blur 14), easing to
  /// zero down the zone via stacked strips.
  static const double topFadeBlurSigma = 14.0;

  /// The dim gradient: `blackberry` 85% → 55% at half → transparent
  /// (export-exact stops).
  static final List<Color> topFadeGradient = [
    AppColors.blackberry.withValues(alpha: 0.85),
    AppColors.blackberry.withValues(alpha: 0.55),
    AppColors.blackberry.withValues(alpha: 0.0),
  ];
  static const List<double> topFadeGradientStops = [0.0, 0.5, 1.0];

  // ---- calendar-sheet cell channels (calendar-sheet.md Q1/Q2) ----
  /// Tint slot, BINARY v1: the warm glow of a day with ≥ 1 athlete food log.
  /// Export-exact values (the ratified walk's "warm glow, not a stain" — a
  /// cream-leaning orange; daily-intake meaning stays in the `orange` token
  /// domain). No intensity scaling renders in v1 (bundle excludes).
  static const Color calendarTintFill = Color.fromRGBO(255, 166, 48, 0.18);
  static const Color calendarTintRing = Color.fromRGBO(255, 180, 80, 0.15);

  /// Dot slot geometry: PLANNED = hollow `orange` ring, 2 px stroke over a
  /// visibly dark centre (the 1 px version reads solid at cell size —
  /// calendar-sheet.md Q1 round-2 fix); DONE = solid `electrolyte` dot.
  static const double calendarDotPlannedDiameter = 8.0;
  static const double calendarDotPlannedStroke = 2.0;
  static const double calendarDotDoneDiameter = 6.0;

  /// Selected (non-today) cell: 2 px `cream` ring (calendar-sheet.md
  /// today/selected ruling, 2026-09-06).
  static const double calendarSelectedRingStroke = 2.0;

  /// 5x4 color matrix combining saturation [sat] and brightness scale
  /// [bright] (linear RGB multipliers on top of a standard luminance-based
  /// saturation matrix).
  static List<double> _saturationBrightnessMatrix(double sat, double bright) {
    const lumR = 0.2126, lumG = 0.7152, lumB = 0.0722;
    final invSat = 1 - sat;
    final r = invSat * lumR, g = invSat * lumG, b = invSat * lumB;
    return <double>[
      (r + sat) * bright, g * bright, b * bright, 0, 0,
      r * bright, (g + sat) * bright, b * bright, 0, 0,
      r * bright, g * bright, (b + sat) * bright, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }
}
