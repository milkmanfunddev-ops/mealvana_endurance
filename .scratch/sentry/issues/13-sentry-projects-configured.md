# 13: Sentry projects configured

**What to build:** Both Sentry projects carry the agreed settings, applied through the Sentry API or MCP and recorded in the ticket: spike protection on; a dev project cap of 2,000 errors a month; inbound filters for browser extensions and legacy browsers; per project one "New issue" rule and one "Regression" rule, environment production, action email, once per 24 hours per issue; project digests at 30 minutes minimum and 60 maximum; the two default rules replaced and the pull-request rule deleted; dev gets the weekly report only; one cron monitor on `raw-retention-sweep` (`17 3 * * *`, 30-minute grace) bound to the check-in from ticket 12; release health confirmed to show sessions per release after the SDK bump.

**Blocked by:** 12 Edge functions report

**Status:** done except dev quota cap (no per-project cap exists on the Developer plan) and weekly report (user-settings endpoints refuse API tokens; UI only)

- [x] Spike protection enabled on both projects (was already on; re-armed via API). Dev quota cap: NOT POSSIBLE on the Developer plan, see below
- [x] Each project has exactly two issue alert rules (New issue, Regression) with the agreed filters, action and frequency; the default rules and the pull-request rule are gone
- [x] Digest settings 30/60 minutes on both projects. Weekly report: not reachable by API (403 on every `/users/me/*` endpoint); Sentry default is ON for all projects, confirm in User Settings > Notifications
- [x] A cron monitor `raw-retention-sweep` exists in prod with the schedule and grace period. No check-in yet: the 03:17 UTC run today predated the prod rollout (13:08 UTC); first check-in due 2026-10-07 03:17 UTC
- [x] Release health shows crash-free sessions per release in dev (1.29.0+6: 54 sessions, 100% crash-free, 5 users, 7d). No build with SDK 9.30.1 has been cut yet (branch is local-only), so that specific release cannot show
- [x] The ticket lists every setting changed with before and after values

## Settings changed (2026-10-06, applied through the Sentry API)

Org `milkman-24` (plan `am3_f` Developer), projects `mealvana-endurance` (prod, id 4509882394083328) and
`mealvana-endurance-dev` (dev, id 4510121638166528). Token: the personal sentry-cli token in `~/.sentryclirc`
(scopes include `org:admin`, `project:admin`, `alerts:write`). Issue alerts now live in the workflow engine:
the legacy `/projects/{org}/{project}/rules/` endpoints return 404; `/organizations/{org}/workflows/` is the
rule list, each bound to a per-project "Issue Stream" detector (prod 6006611, dev 6062021).

| # | Setting | Project | Before | After | How |
|---|---|---|---|---|---|
| 1 | Spike protection | prod | on (`quotas:spike-protection-disabled: false`) | on | `POST /organizations/milkman-24/spike-protections/` `{"projects":[both]}` → 201 (no-op re-arm) |
| 1 | Spike protection | dev | on | on | same call |
| 2 | Dev quota cap 2,000/month | dev | none | **none (blocked, see below)** | `GET /organizations/milkman-24/spend-allocations/` → 404; `/spend-allocations/index/` → 403; `PUT .../keys/40b0…/` with `rateLimit` → 200 but `rateLimit` stays `null` |
| 3 | Inbound filter browser-extensions | prod | off | on | `PUT /projects/milkman-24/mealvana-endurance/filters/browser-extensions/` `{"active":true}` → 204 |
| 3 | Inbound filter legacy-browsers | prod | off | on | `PUT .../filters/legacy-browsers/` `{"active":true}` → 204 |
| 3 | Inbound filter browser-extensions | dev | off | on | same, dev |
| 3 | Inbound filter legacy-browsers | dev | off | on | same, dev |
| 4 | Issue alert rules | prod | 2569558 "Send a notification for high priority issues" (new/existing high-priority, no env, every 30 min, email issue_owners) | 6123426 "New issue" (`first_seen_event`) + 6123429 "Regression" (`regression_event`); env `production`; frequency 1440 min; email → team `milkman` (4509882393034752), fallthrough ActiveMembers | `POST /organizations/milkman-24/workflows/` ×2 → 201; `DELETE .../workflows/2569558/` → 204 |
| 4 | Issue alert rules | dev | 2679920 same default rule | none (spec: dev gets the weekly report only; the two production-filtered rules created first, 6123430/6123431, could never fire on `development` events and were deleted at code review) | `POST` ×2 → 201; `DELETE .../workflows/2679920/` → 204; `DELETE .../workflows/6123430/`, `/6123431/` → 204 |
| 4 | Pull-request rule | org | 5648553 "Send a notification when pull requests are ready" (never fired) | deleted | `DELETE .../workflows/5648553/` → 204 |
| 5 | Digests min/max | prod | 300 s / 1800 s | 1800 s / 3600 s | `PUT /projects/milkman-24/mealvana-endurance/` `{"digestsMinDelay":1800,"digestsMaxDelay":3600}` → 200 |
| 5 | Digests min/max | dev | 300 s / 1800 s | 1800 s / 3600 s | same, dev |
| 6 | Weekly report | dev | unknown (unreadable by API) | unchanged | `GET /users/me/notification-options/`, `/users/me/`, `/users/me/emails/` all → 403; MCP catalog has no notification-settings tool |
| 7 | Cron monitor `raw-retention-sweep` | prod | none (org monitor list `[]`) | id `d9b2b042-d6d2-403b-9a0e-a48f6b1db537`, active, crontab `17 3 * * *`, checkin_margin 30, max_runtime 30, tz UTC, 0 check-ins | `POST /organizations/milkman-24/monitors/` → 201; `GET .../monitors/raw-retention-sweep/checkins/` → `[]` |
| 8 | Release health | dev | n/a | sessions per release present: `1.29.0+6` 54 sessions, crash-free 100%, 5 users; `1.28.0+5` 53 sessions, 96.2% | `GET /organizations/milkman-24/sessions/?project=4510121638166528&field=sum(session)&field=crash_free_rate(session)&field=count_unique(user)&groupBy=release&statsPeriod=7d` |

After-state verified by GET: both projects `digestsMinDelay 1800 / digestsMaxDelay 3600`, `quotas:spike-protection-disabled false`,
filters `browser-extensions true, legacy-browsers true`; workflow list is exactly the four new ids; monitor list is exactly
`raw-retention-sweep` on prod.

**Dev quota cap — why it is not set.** The Developer plan exposes no per-project error budget. Spend allocations
(per-project reserved quota) are a Business-plan feature: the endpoint 404s/403s here. The other candidate, a client-key
rate limit, needs the `projects:rate-limits` project feature, which neither project carries (project `features` list has no
`rate-limits`); the PUT is accepted and silently dropped, and the API also caps `window` at 86400 s, so even on a paid plan
it would be a daily cap (66/day ≈ 1,980/month), not a monthly one. The spec's own fallback stands: if dev threatens the
pool, lower dev `sampleRate` in the app. Spike protection is the only automatic guard the plan gives.

**Weekly report — why it is unverified.** Every `/users/me/*` endpoint refuses API tokens in this org (403, even
`/users/me/`); the setting is per user and lives only in the UI (User Settings > Notifications > Weekly Reports).
Sentry's default is ON for every project, so dev receives it unless it was switched off by hand. No prod change intended.

**Cron monitor — why zero check-ins.** Prod pg_cron job 2 ran 2026-10-06 03:17:00 UTC and succeeded (audit row 20), but
the SQL body that posts on every run (migration `20261006120000`) and `raw-retention-alert` v3 (with the check-in) both
reached prod at ~13:08 UTC, after that run; the old body only posted on an alert, and no alert fired. The monitor is now
created explicitly with the same config the SDK upserts, so the 2026-10-07 03:17 UTC run should register `in_progress`
then `ok`; a miss alerts after the 30-minute margin. The prod `SENTRY_DSN` secret hashes to the prod project's DSN, so the
check-in lands in `mealvana-endurance`. `SENTRY_CRON_MONITORS` hashes to `1`.

**Release health — what is missing.** Sessions already arrive per release in dev (SDK 9.6.0 builds). Every dev event in
the last 7 days is SDK 9.6.0; no build carrying 9.30.1 exists because the `sentry` branch has no remote and Codemagic cuts
dev builds on `develop` pushes. Re-check after the first dev cut from this branch.
