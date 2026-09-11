# 09: Correct the record

**What to build:** The documentation contradicts the code and quotes a number we know to be
misleading. The README and the component spec both say a Meal with no picture shows nothing; the app
deliberately keeps the icon, and that was ruled on. The README still leads with 94.5% coverage, which
counted a photograph of water as a covered Meal.

Two decisions in this area are also hard to reverse, surprising without context, and were real
trade-offs — they should be recorded before they look arbitrary to whoever reads the code next.

**Blocked by:** 05 (the final numbers)

**Status:** done (2026-09-11)

- [x] The README and the component spec describe the no-picture state as it actually behaves.
- [x] The stale coverage claim is replaced by the measured honesty figure, with the distinction
      between the two stated plainly.
- [x] An ADR records why mirroring is decided per provider — archive material mirrored, stock-photo
      providers hotlinked — and what unwinding it would cost.
- [x] An ADR records why Mosaics are composed on the client rather than pre-rendered, and what that
      rules out.
- [x] The production gate for the flagged unlicensed hotlinks is carried into the cutover checklist.

## Done (2026-09-11)

- The no-picture state was already described correctly by ticket 08 (README "The fallback ladder",
  spec MIM-9). This pass fixed what was left: the spec's "a fifth of the library" (it is 1,118 of
  1,922), the widget header's "or nothing at all", and the README's "Why tiles" section, which still
  offered a Mosaic to every meal without a photo.
- README now opens with "Where it stands": honesty 75.3%, coverage 41.8%, what each counts, and
  where 94.5% came from. The 2026-09-08 coverage table is gone.
- ADRs: `docs/adr/0001-meal-images-mirroring-is-decided-per-provider.md`,
  `docs/adr/0002-mosaics-are-composed-on-the-client.md`.
- Cutover: `supabase/migrations/cutover/meal_planning/03_image_gate.sql` raises while any
  `image_unlicensed` row exists (tested on dev: raises on 30). `90_verify.sql` reports it, and the
  runbook's new "Meal imagery" section carries it into steps 3 and 5.
- Found on the way, recorded in the runbook: the seed snapshot is from 2026-09-01 and predates
  all the imagery work, and 506 of the 804 meals showing a picture load one from the **dev**
  storage bucket, which a verbatim seed would carry into production.
