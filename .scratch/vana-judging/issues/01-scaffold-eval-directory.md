# 01: Scaffold the /eval directory

**What to build:** The skeleton of the judging system's home at `/eval` in the repo root. The
Rubric (`rubric.md`) already exists there. Add: a README that writes down the round protocol
(how an Eval round is run: one Run per Scenario, the confirmatory re-run rule, the pass bar of
average ≥ 90 with no Run below 80, where things get written), a corpus index of Scenarios,
the master `improvements.md` backlog with its recording conventions (what / why / motivating
Run / status pending-applied-reverted-ticketed), an `accounts.md` skeleton mapping persona
accounts to Scenarios (credentials never here — secrets directory only), and empty
`scenarios/` and `runs/` directories.

**Blocked by:** None (can start immediately).

**Status:** ready-for-agent

- [ ] `/eval` contains README, rubric.md (already present), improvements.md, accounts.md,
      scenarios/ and runs/
- [ ] README documents the round protocol, the pass bar, and the JSON-sidecar convention for
      the future visual artifact
- [ ] improvements.md records the status vocabulary and the rule that every applied tweak is a
      commit (undoable)
- [ ] accounts.md states the one-persona-per-account rule and points at the secrets directory
      for credentials
