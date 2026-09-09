# 07: Home location Fact

**What to build:** An athlete tells Vana "I live in Birmingham" and from then on "what's the weather tomorrow" answers for Birmingham, not the race venue. Home city, coordinates, and timezone are three fields on the user record, a Fact the Doll reads. A profile tool lets Vana set them when the person mentions where they live. Weather and Kroger coverage key off home location when present and fall back to race location when not. The fields sync like the rest of the profile.

**Blocked by:** 03 General mode reads the Doll

**Status:** ready-for-agent

- [ ] Idempotent migration adds the three fields on dev; the local profile table and its sync carry them
- [ ] Server seam: the profile tool writes the fields; the context block carries a HOME line when set and omits it when not
- [ ] Server seam: weather resolves from home location when set and from race location otherwise
- [ ] Kroger coverage uses home location when set
- [ ] Live eval: "I live in Birmingham" then "what's the weather tomorrow" answers for Birmingham
