> **RESOLVED 2026-09-20 → ruled in-session (arbitration): destroy-content CONFIRMED for samples/; fix = inverted default (A); ships as real-payload-corpus@v1.1**

type: spec-erratum
bundle: real-payload-corpus@v1 → correction ships as @v1.1

## Why this matters
The LANDED exemplars violate the ratified de-id standard: `AthleteId` (named verbatim in the
DROP row), an account-bearing deep-link `Url`, and unfuzzed scalars passed through, because
the scrubber's per-key census scrubbed only keys it recognized (TP 8/47, FS 9/21 classified)
— a blocklist cannot deliver the ruled universal "every scalar is fake".

## Discovery + proportion
First live FS capture (21 real payloads, Rad's account) exercised the census against real
width; app-a9 raised it, no change made pending ruling. The four landed exemplars are the
SANDBOX athlete with hand-typed values (env=uat) — no real person's data in the repo; prod
not deployed. qa-70's pre-land scan shares the miss (checked known identifier VALUES, not
identifier-shaped KEYS) — scan fixed for v1.1's sweep.

## The ruling (Xuan, in-session, 2026-09-20)
1. **Destroy-content CONFIRMED for `samples/`** (Q1 option 1): L-7 item 5 + the DROP row
   govern as ratified; the raw/forensic ruling (item 2) is unaffected and was never in
   question. Samples stay (the 90-day raw TTL is exactly why they must exist AND be clean).
2. **Fix shape A**: scrubber inverted to DEFAULT-DENY on content, per the amendment now in
   the de-id standard (unknown keys keep KEY+TYPE+null-pattern, values fuzzed/placeholdered;
   verbatim values only via the deliberate KEEP-ENUM allowlist).
3. **The four landed exemplars are RE-SCRUBBED, never deleted** (the intake's own
   frozen-exemplar correction sanction).

## Gates (→ @v1.1 via ship-bundle; post-land correction = new bundle version)
- [ ] App: scrubber inverted per A; KEEP-ENUM allowlist seeded by name (app-proposed,
      QA-reviewed at the v1.1 pre-land sweep); FS census kept only as classification floor.
- [ ] Re-scrub + re-export the four exemplars (same fingerprints, clean content).
- [ ] QA: corpus-deid vectors regenerated via spec-to-vectors against the AMENDED standard
      (unknown-value fuzz becomes an asserted property); pre-land leak scan checks
      identifier-shaped KEYS and URL-param patterns, not known values.
- [ ] DI-20 row re-flips on the regenerated vectors.
