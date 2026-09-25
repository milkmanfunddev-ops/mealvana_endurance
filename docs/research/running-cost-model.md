# Running cost model

Researched 2026-09-20. Vendor prices were read from each vendor's pricing page today (URLs in the vendor notes). Usage figures come from the code on `mealplanning` and from read-only queries on the DEV Supabase project (`vlmtsdzpnjnavdgytcmi`) and its logs API. Codemagic minutes come from the Codemagic builds API. Nothing was written, deployed or built. Prod data was not read; the only prod fact used is the organisation's plan.

Covered elsewhere and not repeated here: Claude platform features, Vercel AI Gateway and AI SDK, the code-level AI audit, store fees and web checkout, startup credits, food databases, app attestation. AI cost per subscriber ($2.86 today, $1.64 after the cache fix) and the 15% store fee are taken as given inputs.

## Three things to know first

1. **The Supabase organisation is on the Free plan, prod included.** `get_organization` returns `plan: free` for org `wvtytomxjjuthxigunxx`, which holds both projects. Free has no backups, a 500 MB database cap, 1 GB storage, 5 GB egress and 200 realtime connections. A paid product cannot launch on it. Budget $25 a month for Pro before 10-01. This is a cost increase, not a saving, and it is the most urgent item in this document.
2. **Outside AI, the business costs about $0.35 to $0.55 per subscriber per month from 1,000 subscribers up.** AI is 80 to 90 percent of variable cost at every scale. The cache fix is worth more than every other saving here combined.
3. **The non-AI bills that scale are RevenueCat (1% of gross), Mixpanel (free until about 2,200 subscribers, then $350 a month at 5,000), OneSignal (free until about 670 subscribers) and Supabase egress.** Everything else is flat or near zero.

## Monthly cost by scale

Paying subscribers across the top. MAU is assumed to be 1.5 times paying subscribers (trials, lapsed users, coaches). All figures USD per month.

| Vendor | 100 | 500 | 1,000 | 5,000 | 10,000 | Unit that scales | Where it jumps |
|---|---|---|---|---|---|---|---|
| AI via gateway, today ($2.86) | 286 | 1,430 | 2,860 | 14,300 | 28,600 | tokens | linear |
| AI via gateway, after cache fix ($1.64) | 164 | 820 | 1,640 | 8,200 | 16,400 | tokens | linear |
| RevenueCat | 0 | 71 | 142 | 708 | 1,416 | 1% of gross tracked revenue | $2,500 MTR, about 180 subscribers at the blended price |
| Supabase (Pro, prod + dev) | 35 | 35 | 40 | 157 | 308 | compute size, egress GB, invocations | compute Small near 1,000, Medium near 5,000, Large near 10,000; egress past 250 GB near 1,700 subscribers |
| Mixpanel | 0 | 0 | 0 | 350 | 980 | events | 1M events a month, about 2,200 subscribers |
| OneSignal | 0 | 0 | 37 | 109 | 199 | MAU with the SDK | 1,000 MAU, about 670 subscribers |
| Sentry (Team) | 26 | 27 | 27 | 49 | 80 | errors, spans, replays | 50k errors, about 11,000 subscribers |
| Shorebird | 0 | 0 | 0 | 20 | 20 | patch installs | 5,000 installs a month, about 1,650 subscribers at 2 patches a month |
| Resend (SMTP) | 0 | 0 | 20 | 20 | 20 | emails | 100 a day or 3,000 a month |
| Wiredash | 0 | 0 | 0 | 0 | 32 | devices, seats | second team member or the device tier (unverified) |
| Vercel Pro (coach web) | 20 | 20 | 20 | 20 | 20 | seats | flat |
| Codemagic | 25 | 25 | 25 | 25 | 25 | build minutes | flat; $0 if the account is personal and stays under 500 min |
| Apple developer program | 8 | 8 | 8 | 8 | 8 | none | flat, $99 a year |
| Domain and mailbox | 10 | 10 | 10 | 10 | 10 | none | flat (unverified) |
| Claude Code for development | 200 | 200 | 200 | 200 | 200 | seats | flat (plan tier unverified) |
| Kroger, Garmin, TrainingPeaks, FinalSurge, VDOT, LocationIQ, Unsplash, Pexels, Sanity, GitHub, Google Play | 0 | 0 | 0 | 0 | 0 | request caps | see notes |
| **Total, AI at $2.86** | **610** | **1,826** | **3,389** | **15,976** | **31,918** | | |
| **Total, AI at $1.64** | **488** | **1,216** | **2,169** | **9,876** | **19,718** | | |
| Cost per subscriber, AI at $2.86 | 6.10 | 3.65 | 3.39 | 3.20 | 3.19 | | |
| Cost per subscriber, AI at $1.64 | 4.88 | 2.43 | 2.17 | 1.98 | 1.97 | | |
| Cost per subscriber without AI | 3.24 | 0.79 | 0.53 | 0.34 | 0.33 | | |

Fixed overhead is about $290 a month (Supabase base, Sentry, Vercel, Codemagic, Apple, domain, Claude Code). That is why 100 subscribers looks expensive per head.

### Gross margin per plan after the 15% store fee

Net revenue per subscriber per month: standard monthly $21.24, standard annual $14.17 ($199.99 / 12), founding monthly $10.62, founding annual $7.08 ($99.99 / 12). Margin is net revenue minus all costs above, fixed overhead included. RevenueCat is charged at 1% of that plan's gross price.

AI at $2.86 (today):

| Plan | 100 | 500 | 1,000 | 5,000 | 10,000 |
|---|---|---|---|---|---|
| Standard monthly $24.99 | $15.14 (71%) | $17.48 (82%) | $17.74 (84%) | $17.94 (84%) | $17.94 (84%) |
| Standard annual $199.99 | $8.06 (57%) | $10.49 (74%) | $10.75 (76%) | $10.95 (77%) | $10.95 (77%) |
| Founding monthly $12.49 | $4.51 (43%) | $6.98 (66%) | $7.24 (68%) | $7.44 (70%) | $7.44 (70%) |
| Founding annual $99.99 | $0.98 (14%) | $3.49 (49%) | $3.75 (53%) | $3.95 (56%) | $3.95 (56%) |

AI at $1.64 (after the cache fix):

| Plan | 100 | 500 | 1,000 | 5,000 | 10,000 |
|---|---|---|---|---|---|
| Standard monthly $24.99 | $16.36 (77%) | $18.70 (88%) | $18.96 (89%) | $19.16 (90%) | $19.16 (90%) |
| Standard annual $199.99 | $9.28 (66%) | $11.71 (83%) | $11.97 (85%) | $12.17 (86%) | $12.17 (86%) |
| Founding monthly $12.49 | $5.73 (54%) | $8.20 (77%) | $8.46 (80%) | $8.66 (82%) | $8.66 (82%) |
| Founding annual $99.99 | $2.20 (31%) | $4.71 (66%) | $4.97 (70%) | $5.17 (73%) | $5.17 (73%) |

The founding annual plan is the thin one. An annual subscriber uses AI every month but pays $7.08 net a month. At today's AI cost it keeps 53 to 56 percent; a heavy user on that plan (the $3.90 heavy profile in `vana-cost-and-pricing.md`) keeps under 40 percent.

## Savings, ranked by dollars at 1,000 subscribers

| # | Saving | $ per month at 1,000 | At 10,000 | Effort | Risk |
|---|---|---|---|---|---|
| 1 | AI prompt cache fix (given input, covered elsewhere) | 1,220 | 12,200 | M | Low |
| 2 | Replace OneSignal with direct APNs and FCM sends from the edge function, or accept it | 37 | 199 | M | Medium. Token registration, delivery debugging and opt-out move in-house. One push type exists today, so the surface is small |
| 3 | Claude Code plan: check the tier matches real use once the pre-launch build wave ends | 0 to 100 | same | S | None |
| 4 | Keep DEV in its own Free organisation when prod moves to Pro | 10 | 10 | S | Low. Free pauses after 7 idle days and caps at 500 MB; DEV is 172 MB and used daily |
| 5 | Host the coach web build somewhere free for commercial static sites, if the Vercel team is only kept for that | 0 to 20 | same | S | Low. Check first whether the AI Gateway team needs Pro anyway (covered elsewhere) |
| 6 | Codemagic: make `dev-ios` manual or keep `[skip ci]` discipline | 0 to 8 | same | S | None. 89 of 202 September minutes were `dev-ios` auto-builds. Whole bill is under the 500 free minutes if the account is personal |
| 7 | Stop storing Garmin `epoch` and `stress` rows that nothing reads | 1 to 5 | 60 to 110 | S | Low. Removes about 90% of Garmin table growth and most `garmin-push` invocations; delays the Medium and Large compute steps. Backfill exists if the data is wanted later |
| 8 | Mixpanel: join the Startup Program before 1M events, and drop tap-level settings and help events | 0 | 980 | S | None. First year free if founded under 5 years ago with under $8M raised |
| 9 | Sentry: exclude `garmin-push` from edge tracing with a `tracesSampler` | 0 | 20 to 30 | S | None |
| 10 | Re-encode `recipe-images` (1.4 MB average) to about 150 KB | 0 | 5 to 25 | S | None. Protects the egress quota |
| 11 | Retention on `plan_generation_log`, `vana_calls`, `ai_usage`, `auth.audit_log_entries` | 0 | 5 to 10 | S | Low. Decide the retention window with the pricing analysis in mind; `vana_calls` is the cost ledger |
| 12 | Replace the always-open `token_wallets` realtime channel with a refetch after each debit | 0 | 0 to 5 | S | Low |
| 13 | Drop RevenueCat for native StoreKit and Play Billing | 142 | 1,416 | L | High. Not recommended; the entitlement cache, webhook and paywall all depend on it |

Rows 7 to 12 save almost nothing at 1,000 subscribers. They are listed because each is a small change now and each removes a tier step later.

Things checked that are not waste:
- Sentry release sample rates are 0.1 for traces and profiles, 0.0 for session replay, and replay-on-error is armed for a persisted 10% cohort only. The 1.0 trace rate applies only when `kDebugMode` is true (`lib/main_prod.dart:73-86`, `lib/shared/services/app_config.dart:349`).
- Mixpanel has `trackAutomaticEvents: false` and is consent-gated (`lib/shared/services/analytics/analytics_tracker.dart:78-81`).
- pg_cron runs one job, once a day (`raw-retention-sweep`, `17 3 * * *`). GitHub has two scheduled workflows, both weekly. Nothing runs too often.
- Meal photos are resized on the device before upload (`photo_capture_screen.dart:64-65`, max width 1200, quality 85). Stored average is 386 KB.
- Codemagic integration-test workflows have `events: []`. Patrol runs on the self-hosted runner, which bills nothing.

## Vendor notes

### Supabase
Pricing: https://supabase.com/pricing. Free: 500 MB database, 50,000 MAU, 5 GB egress, 5 GB cached egress, 1 GB storage, 500,000 edge invocations, 200 peak realtime connections, no backups, pauses after a week idle, 2 projects. Pro: $25 a month with $10 compute credit, 100,000 MAU, 8 GB disk per project, 250 GB egress, 250 GB cached egress, 100 GB storage, 2M invocations, 500 realtime connections, 7-day backups. Overage: MAU $0.00325, disk $0.125 per GB, egress $0.09 per GB, cached egress $0.03 per GB, storage $0.0213 per GB, invocations $2 per million, realtime connections $10 per 1,000. Compute: Micro $10, Small $15, Medium $60, Large $110. PITR $100 a month per 7 days. Each extra project pays its own compute.

Evidence from DEV:
- Organisation plan is `free` (Supabase MCP `get_organization`).
- Database 172 MB. Largest tables: `meal_library` 45 MB (shared catalog), `garmin_health_data` 40 MB, `catalog_variants` 11 MB, `catalog_items` 11 MB, `plan_generation_log` 8.7 MB, `activities` 4.9 MB, `vana_messages` 3.1 MB. Shared catalog data is about 85 MB and does not grow with users.
- `garmin_health_data`: 65,103 rows for 7 users since 2026-03-25. 57,897 rows are `epoch` and 3,140 are `stress`. Code reads only `daily` and `body_composition` (`supabase/functions/calculate-daily-macros-v6/index.ts:162,183,263,288`; `lib/features/integrations/presentation/providers/integrations_providers.dart:386`). Writes are at `supabase/functions/garmin-push/index.ts:558,828` and `garmin-ping/index.ts:428,492`. The 90-day sweep purges only `activity_raw`, `activity_detail_raw` and `activity_detail_full`, so epoch and stress rows grow without limit, about 0.95 MB per Garmin user per month.
- Edge invocations over the last 24 hours: `garmin-push` 657, every other function 21 combined. With 7 Garmin users that is about 94 pushes per user per day, about 2,800 a month. At a 60% Garmin connect rate (assumption), 1,000 subscribers produce 1.7M invocations a month from Garmin alone, against 2M included.
- REST requests on DEV ran 5,500 to 18,500 a day last week with a handful of active users. Bytes are not reported by that endpoint, so egress per user is an estimate (150 MB a month, unverified). Egress is the least certain Supabase number and the one to watch in the first billing month.
- Storage: `meal-images` 566 objects, 82 MB, 149 KB average (one 4.4 MB outlier). `meal-photos` 37 objects, 14 MB, 386 KB average, no bucket size limit set. `recipe-images` 30 objects, 42 MB, 1.4 MB average. The model assumes 17 photos per subscriber per month if photo history ships to everyone; today it is internal-only.
- Realtime publication holds `coach_messages` and `token_wallets`. The wallet channel is opened by a `keepAlive` controller, so every signed-in session holds one connection (`lib/features/ai_credits/application/credits_controller.dart:38,42`; `lib/features/ai_credits/data/credits_repository.dart:130`).
- No retention on `plan_generation_log` (4,718 rows, 1.8 KB each, keyed by `device_id`, migration `supabase/migrations/20260721090000_plan_generation_log.sql`), `vana_calls`, `ai_usage`, `vana_messages` or `auth.audit_log_entries` (10,273 rows).
- Extensions installed: `vector`, `pg_cron`, `pg_net`, `pg_trgm`, `supabase_vault`. None is billed separately.

Model: Pro $25 with prod on Micro inside the credit, DEV as a second project at $10. Compute steps to Small, Medium and Large are judgment calls, not measured (unverified). PITR is left out; consider it from about 1,000 subscribers.

### RevenueCat
Pricing: https://www.revenuecat.com/pricing/. Free up to $2,500 monthly tracked revenue, then 1%. MTR is gross, before the store's cut. No features are gated. The page wording reads as 1% of all tracked revenue once past the threshold; the model uses that reading (unverified). Annual purchases count in the month they are bought, so launch month MTR will spike. Blended gross price assumed $14.16 per subscriber per month.

### Mixpanel
Pricing: https://mixpanel.com/pricing/. Free to 1M events a month. Growth includes the first 1M and charges per event after. The per-event price of $0.00028 comes from third-party trackers, not Mixpanel's page (unverified): https://www.usercall.co/post/mixpanel-pricing. Startup Program: first year free if under 5 years old and under $8M raised.

Evidence: 218 `track` call sites, about 50 distinct event names. Most are taps: 10 `help_*_tapped`, 15 `settings_*_tapped`, plus `screen_viewed` fired by hand from individual screens (for example `lib/features/settings/presentation/screens/food_preferences_screen.dart:76`). There is no router-level screen tracking. One server-side sender exists (`supabase/functions/_shared/analytics/mixpanel.ts:23`). Estimate: 300 events per MAU per month (unverified; replace with the October project total).

### OneSignal
Pricing: https://onesignal.com/pricing. Free with unlimited mobile sends up to 1,000 MAU. Growth starts at $19 a month plus $0.012 per MAU. The model adds the two (unverified). MAU counts every device running the SDK, not only devices that receive a push.

Evidence: the only server send is the Garmin activity-uploaded push (`supabase/functions/_shared/garmin/onesignal.ts:80,129`). Local reminders use `flutter_local_notifications`, which costs nothing.

### Sentry
Pricing: https://sentry.io/pricing/ and https://docs.sentry.io/pricing/. Developer: free, 1 user, 5,000 errors, 5M spans, 50 replays. Team: $26 a month billed annually, 50,000 errors, 5M spans, 50 replays, unlimited users. Overage on Team: errors $0.00029 falling to $0.00012, spans $0.0000016, replays $0.003, logs $0.50 per GB.

Evidence: release rates in `lib/main_prod.dart:84-85,105,116`; replay cohort 10% in `lib/shared/services/sentry/sentry_replay_sampling.dart:17`; `attachScreenshot = true` at `lib/main_prod.dart:167`, so every error carries an image attachment; `maxBreadcrumbs = 100`. Every Drift query and every Supabase HTTP call becomes a span (`lib/shared/database/connection_native.dart:9-12`, `lib/main_prod.dart:199`). Edge functions trace at 0.1 (`supabase/functions/_shared/sentry.ts:50`), which includes the high-volume `garmin-push`. Estimates: 3 errors and 900 spans per MAU per month (unverified). Which Sentry plan is active today is unknown.

### Wiredash
Pricing: https://wiredash.com/pricing. Indie: free, 1 team member, 100k custom events, 7 days of analytics history. Growth: 29 euros a month, 3 members. Business: 199 euros. Priced by devices in the last 30 days.

Overlap: three feedback paths exist. Wiredash (`lib/features/feedback/data/wiredash_feedback_filer.dart`, pinned to 2.6.0 because it imports `package:wiredash/src`), the Sentry feedback screenshot setup (`lib/main_prod.dart:161-167`), and shake-to-report (`lib/shared/widgets/shake_to_report.dart`). No Wiredash analytics events are sent, so there is no analytics duplication with Mixpanel. The overlap costs maintenance, not money.

### Shorebird
Pricing: https://shorebird.dev/pricing/. Free 5,000 patch installs a month. Pro $20 for 50,000. Business $400 for 1M. Overage $1 per 2,500. Each patch is installed once per active device, so monthly installs are roughly patches times MAU. Two flavors are registered (`shorebird.yaml`); dev patches count too. Model: 2 patches a month.

### Codemagic
Pricing: https://codemagic.io/pricing/. Personal accounts get 500 free M2 minutes a month. Pay as you go: M2 $0.095 a minute, M4 $0.114, Linux and Windows $0.045. Extra concurrency $49 a month. Unlimited M2 plan $3,990 a year.

Evidence from the builds API, 2026-08-22 to 2026-09-20: 22 builds, 264 minutes, all on `mac_mini_m2`. `dev-ios` 8 builds (102 min), `prod-ios` 6 (73 min), `prod-android` 6 (88 min). Average 12 minutes. At pay-as-you-go rates that is $25. Auto triggers: `dev-ios` on push to `develop` (`codemagic.yaml:427-433`), `prod-ios` and `prod-android` on push to `release/*` (`:650-656`, `:788-794`), `pr-validation` and web E2E on pull requests (`:1741-1752`, `:1791-1803`). PR workflows ran zero times in the window. Every workflow uses the M2 machine, including PR validation and web E2E, which would run on Linux at half the rate. Whether the account is personal or team is unknown.

### Vercel
Pricing: https://vercel.com/pricing. Hobby is non-commercial only. Pro is $20 per developer seat with $20 usage credit, 1 TB transfer and 10M edge requests. `vercel.json` builds the Flutter web app for the coach portal (project `mealvana_endurance_coach_mode`) and `api/region.js` is one function. Web traffic will not approach the included usage. AI Gateway billing is covered elsewhere.

### Resend
Pricing: https://resend.com/pricing. Free 3,000 emails a month with a 100 a day cap. Pro $20 for 50,000. Used for the nutrition-plan email (`RESEND_API_KEY` in `send-nutrition-plan-email`) and probably as the Supabase auth SMTP provider (`secrets/resend.env` exists; the auth SMTP config was not read, unverified). The 100 a day cap is the step that matters: a launch-day signup spike can exceed it while still far under 3,000 a month.

### Free today, with a cap to watch
- **LocationIQ**: https://locationiq.com/pricing. Free 5,000 requests a day at 2 a second, and free commercial use requires a visible "Search by LocationIQ.com" link. Used for event location autocomplete (`lib/features/events/presentation/screens/event_form_screen.dart:389`). No attribution string was found in `lib/` (unverified whether it is shown some other way). First paid plan is $100 a month.
- **Unsplash**: https://unsplash.com/documentation. Free, 50 requests an hour in demo mode, 1,000 after production approval, hotlinking and attribution required. Used by offline sourcing scripts and rendered through `lib/shared/widgets/kyle_design/data/meal_image_mosaic.dart`. Does not scale with users because image bytes come from `images.unsplash.com`.
- **Pexels**: https://www.pexels.com/api/documentation/. Free, 200 an hour and 20,000 a month, attribution required.
- **Sanity**: https://www.sanity.io/pricing. Free plan: 20 seats, 10k documents, 1M CDN requests, 250k API requests. The app does not call Sanity; it feeds the landing page and changelog (`.github/workflows/changelog-on-main.yml`).
- **Garmin**: https://developer.garmin.com/gc-developer-program/program-faq/. No licence or maintenance fee; "access to some metrics may require a license fee" for commercial use.
- **Kroger**: no price found. The rate-limit page returned no content today (unverified).
- **TrainingPeaks, FinalSurge, VDOT**: no fees found in `docs/integration/` (unverified).
- **GitHub**: three hosted workflows, two of them weekly, plus the self-hosted M1 runner for tests. Within the free Actions allowance. Whether GitHub bills self-hosted minutes in 2026 was not checked (unverified).
- **Google Play**: $25 once. https://support.google.com/googleplay/android-developer/answer/6112435.
- **Apple**: $99 a year is the standard fee; the page fetched today did not show the price (unverified). https://developer.apple.com/support/compare-memberships/.

### Claude Code and agent usage
Pricing: https://claude.com/pricing. Pro $20, Max from $100, Team premium seat $125 monthly. The fetched page listed both Max tiers as "from $100", so the $200 in the model is unverified. `secrets/claude_routines.env` shows scheduled routines exist. This is a development cost, not a cost of serving subscribers, and it is the largest fixed line.

## Assumptions

1. MAU is 1.5 times paying subscribers.
2. Blended gross price $14.16 a month: 40% founding monthly, 30% founding annual, 20% standard monthly, 10% standard annual. Used only for RevenueCat dollars in the scale table.
3. Store fee is a flat 15% (given). AI is $2.86 or $1.64 per subscriber per month (given), the same on every plan.
4. 60% of subscribers connect Garmin. Each produces 2,800 `garmin-push` invocations and 0.95 MB of rows a month (measured on 7 DEV users). Other functions add about 300 invocations per subscriber per month (assumed).
5. Database: 1.5 MB per subscriber plus 0.6 MB a month of growth, costed at month 12, so 8.5 MB each.
6. Storage: 17 meal photos a month at 386 KB, costed at month 12, so 80 MB each. Only applies once photo history ships beyond internal users.
7. Egress 150 MB per subscriber per month. Not measured.
8. Mixpanel 300 events per MAU per month. Sentry 3 errors, 900 spans and 0.3 replays per MAU per month. Not measured; DEV traffic is too thin and too synthetic to measure them.
9. Shorebird 2 patches a month, each installed by every MAU.
10. Supabase compute steps (Small at 1,000, Medium at 5,000, Large at 10,000) are judgment, not load tests.
11. Codemagic is costed at pay-as-you-go for the last 30 days' minutes and held flat, since builds follow developer activity, not subscribers.
12. Costs left out: payroll, contractors, the nutrition advisor, legal, accounting, insurance, tax, refunds, chargebacks, marketing, and PITR.
