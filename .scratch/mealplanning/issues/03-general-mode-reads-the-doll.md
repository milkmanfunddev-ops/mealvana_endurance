# 03: General mode reads the Doll

**What to build:** An athlete opens Vana from the Plan tab avatar and asks "what's my workout tomorrow" or "what did I log today". She answers from what she already knows, without a tool call failing or a guess. Both conversation kinds receive the same context block every turn, extended with a LIKES line from Meal feedback (thumbed-up and thumbed-down Meals by name) and a GOALS line from the onboarding survey. Long conversations stay coherent: each turn replays at most the last 20 messages, and when the cap bites the conversation's episode sentence is prepended once. This ticket also creates the personalization eval runner beside the existing vana-eval scripts, with these as its first cases and token cost recorded per case.

**Blocked by:** 02 Vana test harness

**Status:** ready-for-agent

- [ ] General and planning kinds produce the same context block for the same fixture rows, proven at the server seam
- [ ] LIKES line lists thumbed Meals by name and stance; absent thumbs reads "none"
- [ ] GOALS line carries the onboarding survey's goals; absent survey reads "none"
- [ ] History cap: 21 messages in, 20 replayed, episode sentence prepended; 10 messages in, nothing prepended
- [ ] Personalization eval runner exists, refuses to run against anything but dev, records input and output tokens per case
- [ ] Live eval: "what's my workout tomorrow" and "what did I log today" answer correctly in general mode for the eval user
- [ ] Live eval: a fresh user with an empty Doll still gets a sensible opener
