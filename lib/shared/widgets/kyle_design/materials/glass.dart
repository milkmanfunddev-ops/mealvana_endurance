/// Glass material composites — `docs/ssot/spec/design/tokens.md` §Materials
/// (RULED Xuan 2026-09-06; ships with `home-shell@v1`).
///
/// The painting layer for the ratified `glass` / `glass-sheet` recipes and
/// the lensing displacement. Raw values come from [AppMaterials] (the ONE
/// registry, `lib/theme/kyle_design/app_materials.dart`) — nothing here may
/// carry its own alpha or blur number.
///
/// * [GlassSurface] — capsule/circle/rounded chrome: backdrop chain (blur 4
///   · saturate 1.8 · brightness 1.12), cream 7→2% fill, 1 px specular rim
///   (cream 40% top arc → 8% sides), bottom inner shadow, optional outer
///   lift under floating pills.
/// * [GlassSheetSurface] — the summoned-sheet variant: top radius 24, cream
///   4→1% fill, same backdrop chain, specular line under the grabber. The
///   scrim ([AppMaterials.sheetScrim], blackberry 60%) is composed by the
///   summoning route, between the page and the sheet.
/// * [GlassLens] — the traveling-highlight refraction (tokens §Materials —
///   lensing, boundary lifted 2026-09-06). Contractual only where the
///   invoking component spec names it (first: tab-bar.md switch transition).
///   Displacement + falloff by observable properties; never "matches iOS".
library;

import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../../../theme/kyle_design/app_materials.dart';

/// Floating glass chrome: capsules, circles, and the compact header row.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.borderRadius,
    this.lift = false,
    this.nested = false,
    this.dimmed = false,
    this.child,
  });

  /// Shape of the chrome (capsule, circle, or rounded rect).
  final BorderRadius borderRadius;

  /// Outer lift shadow — under floating pills only (tokens §Materials).
  final bool lift;

  /// Dark fill under the blur (the tab bar: busy content behind must never
  /// outshout the labels — Xuan iteration 2026-09-07 #2).
  final bool dimmed;

  /// Chrome sitting ON another glass surface (the compact header row's
  /// circular buttons): keeps the recipe's fill + rim but does NOT re-apply
  /// the backdrop chain — the host surface already saturated/brightened the
  /// backdrop, and stacking the filter compounds it (saturation ~3.2×),
  /// which reads as a separate surface on device. Never lifts (in-row
  /// chrome is not a floating pill).
  final bool nested;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final painted = CustomPaint(
      foregroundPainter: GlassRimPainter(borderRadius: borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: dimmed ? AppMaterials.tabBarBackdropDim : null,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppMaterials.glassFillTop, AppMaterials.glassFillBottom],
            ),
          ),
          child: child,
        ),
      ),
    );
    if (nested) {
      return ClipRRect(borderRadius: borderRadius, child: painted);
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: lift ? AppMaterials.glassLift : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: dimmed
              ? AppMaterials.tabBarBackdropFilter()
              : AppMaterials.glassBackdropFilter(),
          child: painted,
        ),
      ),
    );
  }
}

/// Summoned glass sheet body (the calendar sheet). Fills its box; give it a
/// top-radius-only shape via [GlassSheetSurface.topRadius].
class GlassSheetSurface extends StatelessWidget {
  const GlassSheetSurface({super.key, this.child});

  final Widget? child;

  static BorderRadius get topRadius => const BorderRadius.vertical(
    top: Radius.circular(AppMaterials.sheetTopRadius),
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: topRadius,
      child: BackdropFilter(
        filter: AppMaterials.glassBackdropFilter(),
        child: CustomPaint(
          foregroundPainter: GlassRimPainter(borderRadius: topRadius),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: topRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppMaterials.sheetFillTop,
                  AppMaterials.sheetFillBottom,
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The 1 px specular rim + bottom inner shadow of the glass recipe.
///
/// Light source top: the inner highlight runs cream 40% across the top arc
/// fading to cream 8% at the sides (and below); the bottom edge carries the
/// inset 0 −1px 1px black 25% shadow.
class GlassRimPainter extends CustomPainter {
  const GlassRimPainter({required this.borderRadius});

  final BorderRadius borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Inset by half the stroke so the 1 px rim reads as an inner highlight.
    final rrect = borderRadius.toRRect(rect).deflate(AppMaterials.rimWidth / 2);

    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppMaterials.rimWidth
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppMaterials.rimHighlightTop,
          AppMaterials.rimHighlightSide,
          AppMaterials.rimHighlightSide,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawRRect(rrect, rim);

    // Bottom inner shadow: a 1 px blurred dark line along the inside bottom.
    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = AppMaterials.rimWidth
      ..color = AppMaterials.rimShadowBottom
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        rect.left,
        rect.bottom - rrect.blRadiusY - 2,
        rect.right,
        rect.bottom,
      ),
    );
    canvas.drawRRect(rrect.shift(const Offset(0, -1)), shadow);
    canvas.restore();
  }

  @override
  bool shouldRepaint(GlassRimPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius;
}

/// The liquid-glass lens bubble — the tab bar's active-item highlight
/// (PROPOSED Xuan 2026-09-06, Bevel reference recording; intake
/// `2026-09-06-tab-bar-liquid-bubble`, pending ratification — supersedes
/// the cream-fill highlight and tb6's lens-only-in-transit negative).
///
/// A raised glass shape that REFRACTS whatever is painted beneath it — the
/// bar's own labels and the page behind the translucent bar — with
/// chromatic aberration at the rim ([AppMaterials] tabLens* values). On
/// Impeller (iOS device) this is a true refraction shader
/// (`liquid_glass_renderer`); under Skia (`flutter test`, goldens) the
/// package automatically renders its flat FakeGlass approximation, keeping
/// CI deterministic.
class LiquidLensBubble extends StatelessWidget {
  const LiquidLensBubble({
    super.key,
    required this.radius,
    this.visibility = 1,
    this.motion = 0,
    this.child,
  });

  /// Capsule corner radius of the bubble.
  final double radius;

  /// 0..1 — fades the whole effect (the collapse morph drives this).
  final double visibility;

  /// 0..1 — how much the lens is in motion (travel/drag). Motion thickens
  /// the glass (stronger refraction + dispersion mid-transit, the Bevel
  /// spill).
  final double motion;

  /// Rendered crisply ON TOP of the glass (the Bevel behavior: the resting
  /// active label rides the lens instead of being refracted to mush under
  /// it; in transit the lens glides empty over the static labels).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass.withOwnLayer(
      shape: LiquidRoundedSuperellipse(borderRadius: radius),
      settings: LiquidGlassSettings(
        visibility: visibility.clamp(0.0, 1.0),
        thickness: AppMaterials.tabLensThickness +
            AppMaterials.tabLensTransitThicknessBoost * motion.clamp(0.0, 1.0),
        refractiveIndex: AppMaterials.tabLensRefractiveIndex,
        chromaticAberration: AppMaterials.tabLensChromaticAberration,
        blur: AppMaterials.tabLensBlur,
        saturation: AppMaterials.tabLensSaturation,
        lightIntensity: AppMaterials.tabLensLightIntensity,
      ),
      child: SizedBox.expand(
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

/// The top-of-page dissolve zone (RULED Xuan 2026-09-06 #3 — the export's
/// drawn compact-header treatment, the Bevel-style progressive fade):
/// content scrolling beneath blurs and dims GRADUALLY toward the top — no
/// band, no edge. Floating glass chrome sits on top of it.
///
/// Progressive blur is approximated with stacked backdrop strips of
/// decreasing sigma (Flutter has no gradient-masked backdrop filter); the
/// dim gradient rides over them and hides the strip seams.
class GlassTopFade extends StatelessWidget {
  const GlassTopFade({super.key, this.height});

  /// Zone height. Null fills the parent — the pinned-instrument-block
  /// dissolve (RULED Xuan 2026-09-06 #4): the ratified 104 px fade runs at
  /// the zone's bottom edge and everything above it holds the fade's peak
  /// (blur 14 · `blackberry` 85%). At exactly
  /// [AppMaterials.topFadeHeight] this reduces to the ruling-#3 treatment.
  final double? height;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = height ?? constraints.maxHeight;
            if (!h.isFinite || h <= 0) return const SizedBox.shrink();
            // (top, height, sigma) strips — the bottom 64 px eases the blur
            // out; everything above holds the peak. At h = 104 these are the
            // ratified #3 strips exactly.
            final strips = [
              (0.0, h - 64.0, AppMaterials.topFadeBlurSigma),
              (h - 64.0, 24.0, 8.0),
              (h - 40.0, 20.0, 4.0),
              (h - 20.0, 20.0, 1.5),
            ].where((s) => s.$2 > 0 && s.$1 >= 0);
            // Dim gradient: peak alpha down to the last 104 px, then the
            // ratified 85% → 55% → 0 fade to the boundary.
            final fadeStart = ((h - AppMaterials.topFadeHeight) / h).clamp(
              0.0,
              1.0,
            );
            final midStop = ((h - AppMaterials.topFadeHeight / 2) / h).clamp(
              0.0,
              1.0,
            );
            return Stack(
              fit: StackFit.expand,
              children: [
                for (final (top, stripHeight, sigma) in strips)
                  Positioned(
                    top: top,
                    left: 0,
                    right: 0,
                    height: stripHeight,
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: sigma,
                          sigmaY: sigma,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppMaterials.topFadeGradient[0],
                        AppMaterials.topFadeGradient[0],
                        AppMaterials.topFadeGradient[1],
                        AppMaterials.topFadeGradient[2],
                      ],
                      stops: [0.0, fadeStart, midStop, 1.0],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The lensing displacement of a traveling glass highlight (tokens
/// §Materials — lensing). Renders the backdrop displaced by [displacement]
/// px inside the capsule, with an outer feather band of
/// [AppMaterials.lensFalloffPx] at half displacement — magnitude and
/// falloff are the observable properties `home-shell.gestures.yaml` tb6
/// pins.
///
/// Implemented as matrix backdrop filters (translation needs no anchor and
/// renders on every backend); mid-transit appearance is golden-held.
class GlassLens extends StatelessWidget {
  const GlassLens({
    super.key,
    required this.borderRadius,
    required this.displacement,
    this.child,
  });

  final BorderRadius borderRadius;

  /// Horizontal backdrop displacement in px (signed: against the travel
  /// direction). Zero renders no lens layer at all — the filter must be
  /// active mid-transit and absent at rest (tb6).
  final double displacement;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (displacement == 0) return child ?? const SizedBox.shrink();
    final falloff = AppMaterials.lensFalloffPx;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: borderRadius,
            child: BackdropFilter(
              // Outer feather band: half displacement.
              filter: ImageFilter.matrix(
                (Matrix4.identity()..setTranslationRaw(displacement / 2, 0, 0))
                    .storage,
              ),
              child: Padding(
                padding: EdgeInsets.all(falloff),
                child: ClipRRect(
                  borderRadius: BorderRadius.all(
                    Radius.circular(
                      (borderRadius.topLeft.y - falloff).clamp(
                        0,
                        double.infinity,
                      ),
                    ),
                  ),
                  child: BackdropFilter(
                    // Lens core: full displacement.
                    filter: ImageFilter.matrix(
                      (Matrix4.identity()
                            ..setTranslationRaw(displacement, 0, 0))
                          .storage,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}
