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

**Status:** ready-for-agent

- [ ] The screen renders inside the app shell with the app's normal chrome
- [ ] Every control is a design-system component; no raw Material stand-in remains where one exists
- [ ] Sheets use the glass sheet surface and the standard scrim
- [ ] All typography comes from the token registry
- [ ] No colour, radius, spacing or shadow literal is introduced
- [ ] Only the Kroger integration logo is used; the primary Kroger mark appears nowhere
- [ ] Product images are uncropped with no overlays; product text is unmodified
- [ ] Goldens are added, following the meal-planning golden pattern
- [ ] Every control carries a screen-reader label
- [ ] Any design-system gap found is raised rather than solved on this screen
