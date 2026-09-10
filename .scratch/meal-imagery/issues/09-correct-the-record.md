# 09: Correct the record

**What to build:** The documentation contradicts the code and quotes a number we know to be
misleading. The README and the component spec both say a Meal with no picture shows nothing; the app
deliberately keeps the icon, and that was ruled on. The README still leads with 94.5% coverage, which
counted a photograph of water as a covered Meal.

Two decisions in this area are also hard to reverse, surprising without context, and were real
trade-offs — they should be recorded before they look arbitrary to whoever reads the code next.

**Blocked by:** 05 (the final numbers)

**Status:** ready-for-agent

- [ ] The README and the component spec describe the no-picture state as it actually behaves.
- [ ] The stale coverage claim is replaced by the measured honesty figure, with the distinction
      between the two stated plainly.
- [ ] An ADR records why mirroring is decided per provider — archive material mirrored, stock-photo
      providers hotlinked — and what unwinding it would cost.
- [ ] An ADR records why Mosaics are composed on the client rather than pre-rendered, and what that
      rules out.
- [ ] The production gate for the flagged unlicensed hotlinks is carried into the cutover checklist.
