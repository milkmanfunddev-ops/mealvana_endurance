# 02: Home location on the device

**Status:** ready-for-agent
**Blocked by:** None
**Next:** `/mattpocock-skills:implement 02` — give it a fresh window; this is the app's most fragile seam.

**What to build:** The three home fields carried by the local profile and its sync, so the app can
show and edit where the athlete lives rather than only Vana being able to set it.

**The server half is done and verified live (2026-09-10).** `home_city`, `home_lat`, `home_lon` and
`home_timezone` exist on dev; "I live in Birmingham, Alabama" wrote the city and
`America/Chicago`, and the next weather question answered for Birmingham rather than for a race
venue. Weather and Kroger both key off home when it is set.

**Why this was split out and why it needs care.** `UserProfile` is the model whose partial parsers
once silently reset onboarding answers — the "my onboarding answers vanished after I signed in" bug.
Three new fields mean touching the constructor, `fromSupabaseRow`, `copyWith`, the Drift table, a
schema step and every write path. Missing one of those is exactly how that bug happened.

- [ ] The three fields on the Drift profile table, with a migration step, and the schema version bumped
- [ ] `UserProfile` carries them through the constructor, `fromSupabaseRow`, `copyWith` and every write path
- [ ] A test proves a round trip through every parser leaves all three intact — the regression that bit before
- [ ] They sync like the rest of the profile, both directions
- [ ] Setting home in conversation shows up on the device without a reinstall

**Full history:** `../archive/issues-2026-09-10/07-home-location-fact.md` and `15-home-location-on-the-device.md`
