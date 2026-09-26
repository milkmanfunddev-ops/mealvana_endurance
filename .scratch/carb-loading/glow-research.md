# Flutter glow materials — research for desk amendment (c)

**Status: research only** (per Xuan's directive in the 2026-09-24 handback; no glow
implementation before the desk's amendment-(c) ruling and the D7
electrolyte-vs-orange addition). Reference aesthetic: the v17 prototype's LOAD
face — orange (#F78B14) loader with hot-edge gradient fill
(`rgba(247,139,20,.55) → #F78B14 52% → #FFB25C 84% → #FFD9A4 100%`), outer glow
`0 0 12px rgba(247,139,20,.55)`, inset top highlight, card ambient glow
`0 6px 26px -6px rgba(247,139,20,.45)`, 1px orange hairline. Target: iOS +
Android + web, Flutter ~3.4x stable, Impeller on iOS.

## Ranked routes

### 1. Pure Flutter, zero dependency — layered BoxShadow + MaskFilter + LinearGradient (RECOMMENDED default)
- The hot-edge fill ports 1:1 as a `LinearGradient` with the CSS stops. The card
  ambient glow maps to `BoxShadow(color: Color(0x73F78B14), offset: Offset(0,6),
  blurRadius: 26, spreadRadius: -6)` — negative spread is supported. Hairline =
  `Border.all`; inset highlight = top-aligned white→transparent gradient with
  `BlendMode.softLight`/`overlay`.
- The bar's outer glow reads better as **2–3 stacked BoxShadows** (tight 6px @
  ~70% + wide 16–20px @ ~25%) than one — CSS and Skia/Impeller scale
  blur-radius→sigma differently, and a single Flutter shadow at small radii
  looks harder-edged/banded. For a true "neon tube," `CustomPainter` +
  `MaskFilter.blur(BlurStyle.outer)` in 2–3 passes (bright core → soft halo).
- Perf: no BackdropFilter, so it dodges the known Impeller blur-compositing
  regressions; cheapest for an always-on-screen widget; 60fps-scroll safe.
- Impeller gotchas to verify **on a real device**: BoxShadow.spreadRadius
  black-box artifact (flutter/flutter#162128, device-only); MaskFilter.blur
  clipping bugs (#136519, #155930, #160224, #161575) — budget an oversized
  render-bounds workaround.

### 2. `flutter_shaders_ui` v1.2.0 — real GLSL effects, least effort for true bloom
- pub.dev/packages/flutter_shaders_ui: 49 likes / 160 points / 25.9k downloads,
  published ~1 month ago (healthiest maintenance of the shader-effect packages).
  `GlowOrb`/`PulseEffect` radial bloom + `GlassEffect`; shaders compiled once and
  cached; draws via `Paint.shader` (works on Impeller AND Skia).
- A GPU radial bloom **exceeds** what CSS box-shadow can do — this is the
  "exceed Claude Design" route with least engineering. Not purpose-built for a
  progress bar: combine its glow with our own gradient fill.

### 3. Hand-rolled `.frag` bloom via Flutter's FragmentProgram (quality ceiling)
- Official API (docs.flutter.dev fragment-shaders); `flutter_shaders` package
  (131 likes / 1.15M downloads, ~24 months stale but stable glue) for uniform
  binding. Encode the exact CSS stops/alphas as uniforms — pixel-perfect
  hot-edge + outer glow + inset highlight in one draw call, cheaper per-frame
  than compositing blurred layers.
- Caveats: GLSL only, premultiplied alpha, precache the compiled program.
  **Draw with `Paint()..shader`, not `ImageFilter.shader()`** — the latter is
  Impeller-only and dies under Skia (web/older devices).

## Avoid
- **Anything BackdropFilter/ImageFilter.blur-based for persistent surfaces**
  (`glowy_borders` — 3 years stale, self-warns on perf): long open trail of
  Impeller blur regressions through 2026 (#126353 16ms-vs-6ms raster, #161297
  iOS, #191207). Fine for an occasional sheet; wrong for the always-visible
  face.
- `simple_neon` (right widget shapes, ~zero adoption, 21 months stale) — read
  for inspiration, don't depend.
- Animated-gradient-border packages (`gradient_glow_border` etc.): border
  shells only, not progress fill; low adoption across the board.

## Honorable mention
`liquid_glass_widgets` v1.7.2 (317 likes / 79.4k downloads, published days ago,
needs Flutter ≥3.41): shader-based liquid glass with `GlassGlowColors` tunable
to #F78B14 and an Impeller/Skia dual path. Solves glass refraction, not flat
neon glow — relevant only if the desk later wants iOS-26 liquid glass on the
plum surface.

## Bottom line for the desk A/B
Safest 60fps match: route 1 (pure primitives). Most luminous with least effort:
route 2. Pixel-perfect ceiling: route 3. Whichever wins, validate on a physical
iOS device — the cited Impeller artifacts don't reproduce in the simulator.
Full citations (pub.dev pages + flutter/flutter issue numbers) inline above.
