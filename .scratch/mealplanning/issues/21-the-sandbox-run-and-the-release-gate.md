# 21: The sandbox run and the release gate

**Status:** ready-for-agent (wave 5 failed, 2026-09-16)
**Blocked by:** 19, 20.
**Next:** `/implement-lee mealplanning`

**What to build:** A person with a fresh sandbox account on each store walks a wizard that subscribes through the introductory offer, checks the entitlement is active on day one, checks the Allowance landed, cancels, meets the paywall, and restores; the wizard records each step and the write-up goes with the release. The release checklist gains the trial gate: no meal-planning release without a green run on both stores.

**Decisions:** mp-289, mp-270; approved as mp-299.

**Touches:** scripts/sandbox-trial-wizard.sh, docs/release, docs/deployment/supabase-deploy-playbook.md

- [ ] A bash wizard walks the two-store run step by step and writes a dated log under docs/release.
- [ ] The release checklist names the run as a gate for any meal-planning release.
- [ ] One run on each store is logged green before the ticket closes.

Next: /implement-lee mealplanning
