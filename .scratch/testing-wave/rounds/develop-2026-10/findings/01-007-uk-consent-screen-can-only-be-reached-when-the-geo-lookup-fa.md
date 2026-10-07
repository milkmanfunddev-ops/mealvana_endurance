# 01-007 · UK consent screen can only be reached when the geo lookup fails or answers a strict country; en_GB locale alone never shows it

- kind: followup-test
- status: triaged
- ticket: 01
- run: w1-20261007T1103Z
- screen: Welcome
- decision: 

**Steps.**
1. Rewrite ticket 01's step 8 before retesting. From code (`privacy_region.dart`, `privacy_region_service.dart`, `analytics_consent.dart`): the regime comes from the cached `/api/region` answer whenever `privacy_region_source` = `geo`, and the device locale is read only when the lookup fails. From this Mac `https://app.mealvana.io/api/region` answers `{"country":"US","region":"AL"}`.
2. A UK pass that can reach the screen needs one of: a fresh install (no region cache) with the lookup failing (2 s timeout or non-200; e.g. `netcut.sh slow 3000 SCRATCH --only app.mealvana.io --relaunch UDID`) plus `AppleLocale en_GB`; a build with `REGION_ENDPOINT` pointing at a stub that answers `{"country":"GB"}`; or a network egress in the EEA/UK. Note the cache survives account delete (prefs after delete still held `geo` US/AL), so the retest needs the lead's `clear-app.sh` first.
3. Then: Welcome → Build My Plan; take Decline; read prefs `analytics_consent_*`; finish signup; delete.

**Expected.**
With the lookup failing and locale en_GB (or a GB geo answer): the analytics consent screen comes before onboarding; Decline stores `analytics_consent_status=denied`, `analytics_consent_regime=strict`, `analytics_consent_at=<ISO time>`, `analytics_consent_version=1`; Settings → Privacy shows usage data OFF.

**Actual.**
This run (AppleLocale en_GB, app relaunched): no consent screen; prefs held `privacy_region_source=geo`, `privacy_geo_country=US`, `privacy_geo_region=AL`, so the regime was `standard`, which matches the code. No `analytics_consent_*` keys were written and Settings → Privacy showed "Share anonymous usage data" ON (implied grant). Not a bug by code; the ticket's premise does not hold on this network.

**Evidence.**
- runs/01/expected.md
- runs/01/41-C-after-build-my-plan-en_GB.png
- runs/01/prefs-C-before-build.txt
- runs/01/prefs-C-after-signup.txt
- runs/01/prefs-C-after-delete.txt
- runs/01/50-C-privacy.png

**Decision quote.**
> 

**Triage.**
rewritten into retest ticket 30: the consent screen is reached by failing the geo lookup (netcut) or a strict-country answer, not by setting the locale (Lee)
