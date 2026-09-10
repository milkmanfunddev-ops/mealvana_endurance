# 15: Home location on the device

**What to build:** The three home fields carried by the local profile and its sync, so the app can show
and edit where the athlete lives rather than only Vana being able to set it. The server half is done
and verified: the columns exist on dev, Vana writes them through `setHomeLocation`, and weather and
Kroger key off them.

**Blocked by:** None

**Status:** ready-for-agent

**Why it was split out (2026-09-09):** `UserProfile` is the model whose partial parsers once silently
reset onboarding answers, and three new fields mean touching the constructor, `fromSupabaseRow`,
`copyWith`, the Drift table, a schema step and every write path. That is a careful change in the app's
most fragile seam, and nothing in ticket 07's user story needed it.

- [ ] The three fields on the Drift profile table, with a migration step, and the schema version bumped
- [ ] `UserProfile` carries them through the constructor, `fromSupabaseRow`, `copyWith` and every write path
- [ ] A test proves a round trip through every parser leaves all three intact — the regression that bit before
- [ ] They sync like the rest of the profile, both directions
- [ ] Setting home in conversation shows up on the device without a reinstall
