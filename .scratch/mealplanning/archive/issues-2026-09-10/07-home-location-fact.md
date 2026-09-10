# 07: Home location Fact

**Status:** done
**Blocked by:** None
**Next:** The device half is ticket 15. This ticket is the server, and the server is verified.

**What to build:** An athlete tells Vana "I live in Birmingham" and from then on "what's the weather tomorrow" answers for Birmingham, not the race venue. Home city, coordinates, and timezone are three fields on the user record, a Fact the Doll reads. A profile tool lets Vana set them when the person mentions where they live. Weather and Kroger coverage key off home location when present and fall back to race location when not. The fields sync like the rest of the profile.

- [x] Idempotent migration applied on dev (the local profile table and its sync do NOT carry them — see below)
- [x] Server seam: the profile tool writes the fields; the context block carries a HOME line when set and omits it when not
- [x] Server seam: weather resolves from home location when set and from race location otherwise
- [x] Kroger coverage uses home location when set
- [x] Live eval: "I live in Birmingham" then "what's the weather tomorrow" answers for Birmingham

**Notes (2026-09-09).** `20260909190000_users_home_location.sql` adds `home_city`, `home_lat`,
`home_lon` and `home_timezone` to `users`, idempotently. The context builder reads them, the block
carries a HOME line only when they are set, and today's weather now keys off home, falling back to
the race venue exactly as before when home is empty. The `setHomeLocation` tool geocodes the place
the athlete named through the existing Open-Meteo geocoder, which also supplies the timezone.
Kroger's store search takes a zip when the athlete typed one and otherwise searches near the home
coordinates, so shopping is about their town rather than their next race venue.

`geocode()` in weather.ts now returns the timezone alongside the coordinates; nothing else about it
changed.

Not done, and deliberately:
- **The local Drift mirror and its sync.** `UserProfile` is the model whose partial parsers once
  silently reset onboarding answers, and adding three fields means touching the constructor,
  `fromSupabaseRow`, `copyWith`, the Drift table, a v21 migration step, and every write path. That
  is a careful change in the app's most fragile seam and it is not what makes the user story work:
  Vana reads and writes these fields server-side. Do it as its own piece of work, with the profile
  screen that edits them.
- The migration has NOT been applied to dev. Until it is, `setHomeLocation` fails on the update and
  the HOME line never appears.
- The live eval line. Case `home-location` is in `scripts/vana-eval/personalization.ts`.

**Verified live on dev, 2026-09-10.** "I live in Birmingham, Alabama" wrote `home_city =
Birmingham, Alabama` and `home_timezone = America/Chicago` to the user record, and the next question
about tomorrow's weather answered for Birmingham (93°F, 40% rain) rather than for a race venue.
