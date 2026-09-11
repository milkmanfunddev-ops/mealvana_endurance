# Design-system gaps found rebuilding Shop with Kroger (ticket 07)

Ticket 07 says no new component is invented on this screen: where the design system is missing
something the screen needs, the gap is raised instead. This is that list. Nothing here was solved
locally, and nothing here is a licence to solve it locally next time — the promotion path is
`docs/ssot/spec/design/source-authority.md` §3 (candidate in `prototypes/`, ratified in `/qa`,
implemented in `kyle_design/`, pushed by `/design-sync`).

## DS-1 — There is no Kroger integration logo, so Kroger's mark appears nowhere

**2026-09-11: still open.** Needs Kroger's integration logo file and a licence ruling; nothing to build without them.

`assets/images/integrations/` carries Garmin, Strava, TrainingPeaks and Final Surge marks. It
carries no Kroger asset, and the design system has no integration-attribution component the other
integrations share either — each one draws its own badge at its own call site.

Kroger licenses its **primary** mark for add-to-cart use only while the integration is not
monetized; this feature is behind Pro, so the primary mark is not ours to use. The **integration**
logo is the one that applies, and we do not have the file.

Rather than draw a mark we are not licensed for or invent a Mealvana-made Kroger badge, the screen
shows no Kroger imagery at all. It is named in copy (`kroger.title` — "Shop with Kroger") and
nothing more. **Needed:** the integration logo from Kroger's brand kit, and a ruling on whether
integration attribution becomes a shared component or stays per-call-site.

## DS-2 — `KyleInputField` cannot take focus on open

**2026-09-11: fixed.** `KyleInputField` has `autofocus`; the Kroger sheet uses it and its focus-node workaround is gone.

It accepts a `focusNode` but has no `autofocus`. A sheet that exists to be typed into has to own a
`FocusNode` and request focus in a post-frame callback (`_InputSheetState`). Every caller that
wants a keyboard will repeat that.

## DS-3 — `KylePlusMinusControl` announces itself in hardcoded English

**2026-09-11: labels fixed.** `KylePlusMinusControl` takes `increaseLabel` / `decreaseLabel`, and Kroger passes its content keys. The `tappable: true` dialog is still raw Material.

`_semanticLabel` builds "Increase <label>" / "Decrease <label>" in Dart. The content system already
holds this screen's own words for it (`kroger.quantity_increase`, `kroger.quantity_decrease`) and
there is no way to pass them in, so the label a screen reader speaks is outside the content system
and untranslatable.

Its `tappable: true` path also raises a raw Material `AlertDialog` with hardcoded `Cancel` / `OK`
buttons — not the glass sheet surface, not content-managed. This screen uses `tappable: false` to
stay clear of it.

## DS-4 — There is no product-image slot, and no token for one

**2026-09-11: still local.** The photo is now a 64 px square thumbnail on a white tile (`_productImageSize`), still uncropped. Waits for a ratified component.

The screen shows Kroger's product photograph, which under Kroger's terms must be uncropped with
nothing drawn over it. The design system has no component for a remote product image (the meal
mosaic is a different thing with different rules — it crops, and it composes tiles).

Interim: the screen keeps a named `_productImageHeight` of its own and uses a plain
`Image.network` with `BoxFit.contain` and no `Stack`. It is deliberately **not** in
`lib/theme/kyle_design/`: §3 of the authority doc keeps unratified values out of the registry, so
an unratified 96 px would be worse there than here. It wants a ruling with the component.

## DS-5 — There is no design-system progress indicator

**2026-09-11: smaller.** The Material linear bar under the header is gone; while busy, the refresh button's slot shows a small ink-coloured spinner. A Kyle spinner is still missing.

Busy and first-load states fall back to Material's `LinearProgressIndicator` and
`CircularProgressIndicator`. Every Kyle button already draws its own inline spinner, so the shapes
exist; there is no standalone one.

## DS-6 — Every sheet re-assembles the glass recipe by hand

**2026-09-11: packaged.** `showGlassSheet` (`lib/shared/widgets/kyle_design/materials/glass_sheet.dart`) holds the recipe; Kroger uses it. The calendar and What's-new sheets are not migrated: both files carry another session's uncommitted edits.

`showModalBottomSheet` + `AppMaterials.sheetScrim` + transparent background + `GlassSheetSurface` +
`SafeArea` + padding is copied at each call site (`whats_new_sheet.dart`, `kyle_calendar_sheet.dart`,
and now `kroger_screen.dart`'s `_sheet`). The recipe is documented but not packaged, so a caller
that forgets the scrim or the transparent background gets a sheet that looks nearly right.

## DS-8 — There is no design-system row for a choice inside a sheet

**2026-09-11: still open.** The product row is now a thumbnail beside the name, but still its own `InkWell`.

The product search results are a list of tappable rows on the glass sheet. The design system has
list-shaped cards (`FoodItemCard`, `MealCard`) but nothing for a plain selectable row on a sheet
surface, so `_ProductChoice` wraps its own `InkWell`. `KyleCalendarSheet` has the same problem and
solves it the same way.

## DS-9 — `VanaRoundButton` is a design-bearing widget living in a feature

**2026-09-11: still open.** Moving `VanaRoundButton` would collide with in-flight Vana work in that file.

The in-body round back button every meal-planning detail screen draws lives at
`lib/features/meal_planning/presentation/widgets/vana_round_button.dart`. Kroger now composes it
too, which means a `kroger` screen imports a `meal_planning` presentation widget — the coupling
`CLAUDE.md`'s "implemented once in `lib/shared/widgets/kyle_design/` … features compose them" rule
exists to prevent.

Re-implementing it inside `kroger` would be the duplication the same rule forbids, and moving it
into `kyle_design/` is a design-system change this ticket may not make. **Needed:** ratify it (it
is the header treatment of every detail screen in the app) and move it, with `/design-sync`.

## DS-7 — Nothing on this screen is segmented

Recorded so the next reader does not read its absence as an oversight: the ticket lists the
segmented control among the components to build from, and this screen has no two-way choice to put
in one. Delivery is the only Modality (ticket 02) and the delivery area is a typed postcode, not a
pick from a set.
