# 21: The sandbox run and the release gate

**Status:** built (wave 3, 2026-09-15); the wizard exists, Lee has said (2026-09-16) he will not run it. The release gate it names (playbook P3c) stays on paper until he or Xuan rules otherwise.
**Blocked by:** nothing an agent can do.
**Next:** Lee, on physical phones with fresh sandbox accounts: `scripts/sandbox-trial-wizard.sh preflight`, then `scripts/sandbox-trial-wizard.sh` (see `docs/release/sandbox-trial-runs/README.md`). Tick the last box and set the status to done when both logs are green.

**What to build:** A person with a fresh sandbox account on each store walks a wizard that subscribes through the introductory offer, checks the entitlement is active on day one, checks the Allowance landed, cancels, meets the paywall, and restores; the wizard records each step and the write-up goes with the release. The release checklist gains the trial gate: no meal-planning release without a green run on both stores.

**Decisions:** mp-289, mp-270; approved as mp-299.

**Touches:** scripts/sandbox-trial-wizard.sh, docs/release, docs/deployment/supabase-deploy-playbook.md

- [x] A bash wizard walks the two-store run step by step and writes a dated log under docs/release.
- [x] The release checklist names the run as a gate for any meal-planning release.
- [ ] One run on each store is logged green before the ticket closes.

Next: nothing scheduled; Lee declined the run on 2026-09-16.
