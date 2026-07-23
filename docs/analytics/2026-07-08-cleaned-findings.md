# Cleaned Findings — 2026-07-08 session

Distilled, trustworthy takeaways AFTER removing ~66% dev/test pollution
(`mp_clean.py`). Separates benchmarks (numbers to track) from levers (things to
build) from things that were invalidated. Full detail: `README.md`.

## Trustworthy insights (survived cleaning)

1. **Real audience ≈ 280** (Mixpanel clean ≈ Supabase 263). There is NO hidden
   majority — the "826 users" was two-thirds our own testing. *(benchmark)*
2. **Real retention: D1 ≈19%, D7 ≈9%, D30 ≈5.5%** — robust to cleaning, so it
   holds. Leaky top, ~5% loyal core. *(benchmark → track as a North Star
   metric, NOT a feature request)*
3. **Real users barely close the post-workout feedback loop.** Fuel logging ≈0,
   plan ratings 0 (rating UI is archived). This is the core product gap and it
   held up all session (the mid-session "it works" reversal was pollution).
   *(lever)*
4. **Activation cliff = first activity, not plan creation.** 44% of onboarded
   users never add a first activity; once they do, a plan follows ~90% of the
   time. First-activity is the activation event. *(lever)*
5. **Integration-connect is the retention correlate** (Supabase: ~60% of actives
   vs 1–2% of churned have one). Getting a provider connected early is the
   clearest stickiness signal. *(lever)*
6. **Race = one-off goal → post-race churn** (84% of carb-loaders never return;
   carb-loading tracking essentially unused). *(lever)*

## Invalidated — do NOT trust (pollution artifacts)

- "Invisible majority of hidden real users" — was dev/sim/team traffic.
- "Fuel logging works, it's an adoption not a build problem" — all 9 loggers
  were dev/team; real fuel logging ≈0.
- The two activity-sync "bugs" — flagship case was an `arm64` simulator.
- Event-based per-feature counts (plan views = 24, edits, etc.) — upper bounds
  until re-run with the dev filter.

## Filing status — is everything captured?

| Insight | Type | Captured as |
|---|---|---|
| Feedback loop unused (#3) | lever | FR: auto-completion-push-deeplink, plan-rating-revive, instrument fuel-log-started |
| First-activity cliff (#4) | lever | FR: onboarding-first-activity + instrument first-activity-added |
| Integration → retention (#5) | lever | FR: evening-before-synced-run nudge; onboarding provider-connect |
| Post-race churn (#6) | lever | FR: post-race-reengagement |
| Retention baseline (#2) | benchmark | THIS doc + README — track in Mixpanel; NOT an FR |
| Real audience ≈280 (#1) | correction | THIS doc + README — NOT an FR |
| 66% dev pollution | data-integrity | FR: analytics-exclude-dev-internal-traffic |
| ID fragmentation | data-integrity | FR: analytics-anon-auth-id-merge |
| plan_generated≠created wiring | instrumentation | Bug: plan-generated-vs-created-not-sequential |

**Answer: yes — every actionable *lever* is filed as an FR, and the
data-integrity issues are filed too. The two items that are NOT feature
requests (retention baseline, real audience size) are benchmarks/corrections by
nature — they belong in this doc + a Mixpanel North Star board, not the roadmap.**

## Prerequisite before the next analysis round
Ship the two data-integrity FRs (dev-exclusion, ID-merge) first. Then future
data is clean by construction and we skip today's manual scrubbing.
