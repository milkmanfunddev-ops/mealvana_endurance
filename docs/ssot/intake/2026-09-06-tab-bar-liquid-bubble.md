# PROPOSED — tab-bar active highlight = liquid-glass bubble (Bevel reference)

**Filed: 2026-09-06 (late evening). Status: PROPOSED — implemented ahead of ratification at
Xuan's direction ("implement it first and leave me intake to ratify"); Xuan ratifies by
flipping this to RESOLVED (or rules changes).**
**Reference: Xuan's Bevel screen recording (ScreenRecording_09-06-2026 21-54-48_1) — the lens
travels between tabs, expands over the bar's border, and refracts the content it passes over.**

## The proposal

The tab bar's active-item highlight becomes a **raised liquid-glass bubble** — present at
REST on the active item and traveling in transit — replacing the ratified cream-fill
highlight (tab-bar.md Q1) and the lens-only-in-transit negative (old tb6):

- At rest: the bubble sits on the active item and **bulges 6px past the bar's border** (the
  Bevel silhouette). Active ink is `cream` on glass (no fill, no blackberry ink).
- In transit: the same bubble travels with the ratified 340ms curve (tb4 unchanged),
  stretching along the travel (unchanged), **refracting the bar's labels and the page behind
  the translucent bar**, with chromatic aberration at the rim.
- Collapse morph: the bubble fades out; the collapsed button stays its own glass circle
  (unchanged).

## Implementation (landed on feature/home-shell-v1, pending this ratification)

- Package: `liquid_glass_renderer 0.2.0-dev.4` (MIT, whynotmake.it) — the shader primitive
  the 2026 component libraries vendor. True refraction shader on Impeller;
  **automatic FakeGlass fallback on Skia** (`ImageFilter.isShaderFilterSupported` runtime
  check), so `flutter test` + goldens render deterministically.
- Composite: `LiquidLensBubble` in `kyle_design/materials/glass.dart`; values in the ONE
  registry (`AppMaterials.tabLens*`): thickness 14 · refractiveIndex 1.35 ·
  chromaticAberration 0.8 (raised from 0.25 at Xuan's direction after the Bevel dispersion frame — IMG_8939) · blur 1.5 · saturation 1.15 · lightIntensity 0.4 · bulge 6px.
- Conformance: tb6 rewritten (`tb6_liquid_lens_bubble`, marked PENDING RATIFICATION in the
  manifest); tb4/tb5/tb7 unchanged and green; goldens `tab_bar_expanded_3/5`, `morph_mid`,
  `switch_transit_mid` re-blessed from the FakeGlass fallback rendering.

## Ratification considerations (the honest trade-offs)

1. **Supersedes ratified Q1**: the cream-fill active highlight is gone from the bar. The
   goldens manifest rows carry PENDING notes; ratifying makes them the contract, rejecting
   reverts to cream fill (one commit).
2. **Package maturity**: 0.2.0-dev.4, no pub release since ~Dec 2025 (repo alive; 886 likes,
   24.6k downloads). Its README warns against blind production use; a documented engine bug
   causes temporary memory spikes during animation (delayed texture disposal). Pivot
   candidates if it misbehaves on device: `liquid_glass_easy` 4.2.0 or
   `liquid_glass_widgets` 1.3.0 (both actively maintained, MIT; both vendor/extend the same
   shader approach). First-party Flutter Cupertino liquid glass explicitly does not exist
   and is paused (flutter/flutter#170310).
3. **Impeller-only**: the true effect renders on iOS/Android/macOS Impeller; Skia (tests,
   web) shows the flat FakeGlass approximation. Our web build would show FakeGlass — flag if
   web fidelity matters.
4. **Goldens capture the fallback**, not the device look — the device look is
   charter/freeplay territory (sim-explore).
5. Perf note for the charter: animated glass re-renders every frame (stationary is cheap);
   watch the traveling lens on iPhone-14-class hardware for jank/memory.
