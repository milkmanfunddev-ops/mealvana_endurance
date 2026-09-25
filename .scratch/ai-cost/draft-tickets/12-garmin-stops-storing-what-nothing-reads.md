# 12: Garmin stops storing what nothing reads

**Status:** ready-for-agent
**Blocked by:** none
**Next:** `/mattpocock-skills:implement 12 ai-cost`
**Model:** opus
**Due:** October

**What to build:** 61,000 of 65,000 rows in `garmin_health_data` are `epoch` and `stress` data no code reads, the 90-day sweep skips them, and `garmin-push` is 97% of edge function calls on dev.

**Spec:** .scratch/ai-cost/spec.md
**Research:** docs/research/running-cost-model.md

**Touches:** supabase/functions/garmin-push/, supabase/migrations/, docs/integration/

- [ ] Confirm by search that nothing reads `epoch` or `stress` rows.
- [ ] `garmin-push` acknowledges and drops those summary types without a write.
- [ ] Existing rows are deleted by an idempotent migration; the sweep covers every type.
- [ ] Whether Garmin lets us unsubscribe from those push types is recorded here.
- [ ] Recipe images over 400 KB are resized.

Next: /mattpocock-skills:implement 12 ai-cost
