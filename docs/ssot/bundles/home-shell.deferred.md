# Deferred ledger — home-shell

Known-open items carried past the `home-shell@v1.1` landing (qa `5dc1b82`, app
`release/1.26.0`). Every line is a CONSCIOUS carry, not an oversight: it names what is not
done and the condition that closes it. Re-verdict this whole file at the next RC gate
(`sim-explore` rule 5). Source: `runs/2026-09-08-home-shell-landing.md` §Open threads;
attestation context: `bundles/home-shell.landing.md`.

Opened 2026-09-08 at bundle close-out.

| id | item | why deferred | un-deferred by |
|---|---|---|---|
| HS-D1 | **CI attestation** — the two "green in CI" done_when items are evidenced locally only | Lee's M1 runner (`tests-selfhosted`) offline throughout implementation and landing; local evidence is 23/23 Patrol + full suites + goldens (0.5 % cross-host comparator). The 2026-09-08 attestation records this exception explicitly. | `tests-selfhosted` green on the runner's return; annotate `home-shell.landing.md` with the run. A divergence from the local result is a NEW finding, not a footnote |
| HS-D2 | **charter-home-shell sim-explore run** — never executed | The charter (`.claude/skills/sim-explore/references/charter-home-shell.md`) landed with the freeze; no dev-build walk happened before ship. The device-look of the Impeller lens is charter territory by the intake's own terms. | Run the charter on a dev build during the Vana window; file findings through intake/ops as usual |
| HS-D3 | **iPad rail** — renders the legacy NavigationRail | Sweep-board round-1 finding; the home-shell specs contract the phone shell only. Needs its own design pass, not a patch. | Its own intake (+ design pass) — file when the iPad pass is scheduled |
| HS-D4 | **meal_logs never download to a fresh device** (app-side, not spec) | `sync-all-data` omits them and no client pull path exists; today it costs history-on-reinstall (the calendar tint rebuilds from empty). Product decision pending — matters more once Vana ships meal-planning. | A product decision with the **Vana bundle's planning**; then the sync work it names |
| HS-D5 | **Vana design-sync debt** — `KyleTabPill`, `MacroPillRow`, `SelectableChipGrid` absent from the design twin | Develop's Vana merge added kyle_design widgets never mirrored to the twin (project c4ad6c0d @ 51 components). Two of the three also carry PROPOSED specs awaiting ratification (macro-pill-row.md, selectable-chip-grid.md — on the desk 2026-09-08); KyleTabPill has no spec at all. | Ratify/amend the two PROPOSED specs; a spec (or an explicit no-spec ruling) for KyleTabPill; then `/design-sync` before or with the Vana release |
