# 16: Confirming a plan archives the week and builds the shopping list

**Status:** in-progress (wave 9, 2026-09-24)
**Blocked by:** 14 (confirms the Draft 14 makes).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete confirms a Draft from the Review sheet. The plan bar shows it, every other plan for that week is archived, and the server builds a shopping list whose rows add up to the plan's meals; the athlete lands on the Food tab's shopping list.

**Decisions:** mp-241, mp-244, mp-235.

**Touches:** the dev test account's plans and shopping lists

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] Confirms an existing Draft; no new plan is generated.
- [ ] SQL shows one confirmed plan for the week and the rest archived.
- [ ] The list's rows are compared with the plan's meal ingredients and any mismatch is a Finding with both lists attached.

Next: /implement-lee testing-wave
