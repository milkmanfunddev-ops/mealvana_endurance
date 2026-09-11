# 07: Make it look like Mealvana

**What to build:** Shop with Kroger stops looking like a different app. It is presented inside the
app shell rather than pushed outside it, so it keeps the app's normal chrome and navigation
instead of a bare back arrow.

The screen is rebuilt from the existing design system: its buttons, cards, quantity control,
segmented control and input field; sheets on the glass sheet surface with the standard scrim;
typography from the token registry rather than inherited Material defaults. No new component is
invented here — where the design system is missing something this screen needs, that gap is raised
rather than filled locally.

Kroger appears only as the integration logo, never the primary Kroger mark: Kroger licenses the
primary logo for add-to-cart use only when the integration is not monetized, and this feature is
behind Pro. Product images are shown uncropped with no overlays, and product text exactly as
returned.

**Blocked by:** 06

**Status:** verified on the iOS simulator in dark, and the screen and confirm sheets in light (2026-09-10); design-system gaps in `../design-system-gaps.md`

- [x] The screen renders inside the app shell with the app's normal chrome —
      `/food/kroger/:planId` under the Food tree, so it carries `/food`'s Pro gate and the in-body
      round-back header its siblings (`recents`, `swap`) draw, in place of a bare `AppBar`
- [x] Every control is a design-system component; no raw Material stand-in remains where one exists
      — the two that remain (progress indicators, a sheet row) are DS-5 and DS-8, not stand-ins
      for something that exists
- [x] Sheets use the glass sheet surface and the standard scrim
- [x] All typography comes from the token registry
- [x] No colour, radius, spacing or shadow literal is introduced — one named size constant,
      `_productImageHeight`, kept local rather than put in the unratified registry (DS-4)
- [x] Only the Kroger integration logo is used; the primary Kroger mark appears nowhere — met by
      omission: we do not have the integration asset, so no Kroger mark is drawn at all (DS-1)
- [x] Product images are uncropped with no overlays; product text is unmodified
- [x] Goldens are added, following the meal-planning golden pattern — four states, both themes
- [x] Every control carries a screen-reader label — asserted by a semantics sweep, not by eye
- [x] Any design-system gap found is raised rather than solved on this screen — DS-1 … DS-9
