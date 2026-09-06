# Design SSOT — Component: Tab Bar

**Status: RATIFIED v1 (Xuan, 2026-09-06 — ruling-desk block of 2026-09-06; first spec for an
already-shipped widget, brought under contract by the home-shell redesign). Ships as
`home-shell@v1`.**
**Component contract** — owns the bar's states, the scroll collapse gesture, the tab-switch
transition and the corner-slot geometry wherever the bar appears. Composition into the home
screen belongs to [`../surfaces/macro-dashboard.md`](../surfaces/macro-dashboard.md)
(home-shell recomposition, 2026-09-06).
**Tokens / material:** [`../tokens.md`](../tokens.md) — the bar and its collapsed button take
the `glass` material (§Materials); raw values live there, never here.
**Companion artifact:** `New Homepage with updated navbar calendar and chat.html` (Claude Design
export, walked live 2026-09-06) — the export **illustrates**; this file and the tokens numbers
**govern** (phase-card-parity precedent). The export does not draw the ruled tab-switch
refraction or drag-tracking at all — for those, the spec's observable properties are the only
reference.
**Ruling source:** [`../../../intake/2026-09-06-tab-bar-v2-glass-scroll-collapse.md`](../../../intake/2026-09-06-tab-bar-v2-glass-scroll-collapse.md) (RESOLVED).

## States — Q1 (RULED as filed)

| State | Contract |
|---|---|
| `EXPANDED` | Left-anchored glass pill; icon+label items; active-item highlight (cream fill, blackberry ink). Covers 3–5 destinations (Q3) |
| `COLLAPSED` | One ~52 px circular glass button at the bottom-**left** corner showing **only the active tab's icon** — regardless of destination count (Q3) |

**Trigger rule:** scroll-down past a threshold collapses; scroll-up (or reaching top) re-expands;
content scrolls under the bar in both states. **Thresholds and hysteresis are pinned by the app's
goldens + the gesture manifest, never by prose here.** The collapse/expand morph travels to/from
the left corner (the anchor makes the motion coherent — Q2).

## Anchoring and the reserved utility slot — Q2 (RULED: option (a))

Left-anchored pill, plus a **named, empty utility slot at the bottom-right corner**. The slot is
part of this contract so a future occupant fills it *additively* — no geometry change to the bar,
no re-ratification of this file. The occupant, whenever ratified (the deferred AI companion is the
known candidate — out of scope this bundle), **inherits the old FAB's clearance rule**: it must
not overlap a workout card's swipe-reveal travel
([`workout-card.md`](workout-card.md) G1/G4).

## Destinations — Q3 (RULED as filed)

3 to 5 items: Fuel Timeline, Food (Pro-unlocked, optional), Coach (web-only, optional),
Events/Learn — per the shipped bar
(`lib/shared/widgets/kyle_design/navigation/floating_action_buttons_bar.dart`). The expanded pill
must hold both extremes; the collapsed button is count-independent (active icon only).

**Q4 — RULED (Xuan, 2026-09-06): the Fuel Timeline tab icon is a HOUSE glyph.** The calendar
glyph is retired from this tab: the date header introduces a top-left calendar button
([`date-header.md`](date-header.md)), and two calendar glyphs with different meanings may not
coexist on the shell. The same collision rule extends to the whole destination set — no
destination's tab icon may be a calendar glyph while the date header renders one.

## Tab-switch transition — RULED contractual (Xuan, 2026-09-06, desk comments + block)

The full liquid-glass switch effect is **contract, not polish** — all three components:

1. **Highlight travel** — the active highlight morphs and travels from the old item to the new
   one (position and width both animate). The export's measured `0.34 s ·
   cubic-bezier(0.32, 0.72, 0, 1)` is the reference starting value; the ratified numbers are
   pinned in the gesture manifest + goldens.
2. **Finger-tracking drag** — a drag along the expanded bar moves the highlight fluidly with the
   finger (no snapping between items until release).
3. **Refraction in transit** — the traveling highlight lenses the content behind it
   (`../tokens.md` §Materials — lensing; boundary lifted 2026-09-06). Not drawn in the export;
   defined **by observable properties only**: distortion magnitude and falloff, easing/timing,
   the drag-tracking rule. **Never "matches iOS".** Mid-transit frames are golden-held.

Feasibility note (verified 2026-09-06): Impeller `ImageFilter.shader` backdrop filters; Impeller-
tied, GPU-costed — the implementation caveats live with the app, the properties live here.

## Conformance (design vectors)

- **Goldens (L1):** expanded (3-item and 5-item), collapsed, the collapse/expand morph, and
  **mid-transit tab-switch frames** (travel + refraction at fixed animation timestamps), at
  token-resolved colors.
- **Gesture manifest (L2):** scroll collapse/expand with the pinned thresholds + hysteresis;
  tab-switch travel timing/easing; drag-tracking (highlight under the finger, commit on release);
  collapsed button tap re-expands or switches per the manifest's rule.
- A golden may only be regenerated after this spec (or the tokens §Materials) changes — never to
  make a red test pass; regeneration commits cite the spec change.

## Open ratification questions
- *(none — Q1–Q4 and the tab-switch transition all RULED 2026-09-06; the transition's numeric
  properties land in the manifests at implementation, which is delegation, not an open ruling)*
