# 116-008 · Net balance on a future day reads +0 on track and a past day counts no planned sessions; the SSOT's intraday display only covers today

- kind: idea
- status: wontfix
- ticket: 116
- run: w32-20260925T2220Z
- screen: Timeline (NET BALANCE)
- decision: 

**Steps.**
Follow-up 30-009 traced the numbers: on test@test.com, past days Sun 20–Tue 22 read 0 − 2,447 = −2,447 (2,447 = rmr 1,901 + NEAT 546, full day); Wed 23 and Thu 24 add 10 % digestion of what was eaten (2,484, 2,782); today is clock-prorated; Sat 26 (future) reads 0 − 0 = "+0 kcal on track". Planned sessions count only once done (dashboard_assembler.dart), so the 12 mi Run and the rest of each past day's skipped sessions add nothing, and a future day's burn is 0 until its clock starts. The code does what it says, and the figures are right by that rule. The SSOT's intraday display (docs/ssot/spec/daily-macros/intraday-display.md) rules only on today's accrual since midnight; it does not say what a past or future day's net balance should read. Idea / product question: should a future day with a 17 mi long run planned read "+0 on track", and should a finished day's card say that its sessions were skipped? For the decisions page.

**Expected.**


**Actual.**


**Evidence.**
- runs/116/07-net-0920.png
- runs/116/07-net-0924.png
- runs/116/08-net-0926-collapsed.png
- runs/116/db-daily-macro-targets-0920-0927.json
- runs/116/db-activities-0920-0927.json

**Decision quote.**
> 

**Triage.**

Won't fix (Lee, 2026-09-26): keep as is.
