# Ticket 25 run notes

- RUN: w14-20260924T2015Z. Slot claimed 20:15:26Z (owner testing-wave-25; testing-wave-24 also held).
- App build commit: 52c68764b2cde49951a27220a8dbdb3a463116f7 (per prompt and app-build.json). Worktree HEAD b3ddc260.
- Simulator: wave-pool-2, 1F66DA4A-A87E-4905-AB73-800EEE30B52F. App data cleared by the lead.
- Shared account with ticket 24 (wave-pool-1): 24 logs one library-photo meal today (AI logging call). Not mine.
- Planned values (written before saving) are in expected.md.
- 20:16:31Z launched; Welcome shown signed out. 20:17:09Z logged in as test@test.com (email + CRED type). No paywall (entitled).
- After login: What's New sheet then the TrainingPeaks sharing sheet; Got it, Keep Sharing (setting unchanged). Already filed as 12-008 / 30-010, not re-filed.
- Console at login: TrainingPeaks token refresh 400, V.O2 "Please reconnect". Known noise: the dev admin's integration tokens are expired (runs 03, 12, 14, 16, 19, 26, 30, 31). No other Flutter error or exception line in the run.
- Driving: taps and text through `idb ui tap/text --udid`, not the mobile MCP (it has read the other simulator's screen, IMPROVEMENTS #39). idb dropped the last two letters of "W14-25 Decimal kcal" once (typed "W14-25 Decimal kc"); read back before saving and appended "al". Harness noise, IMPROVEMENTS #35 kind.
- Timeline on login: no meal rows for today although 4 exist on the server (wave 13's). Known: 10-001 / 26-001, not re-filed.
- 20:17:35Z Log a Meal opened on Describe (wallet pill 255%). I did not type or tap Analyze/Camera/Gallery. ensure-credits 15:17:36 local (x2) = this open; it is not a model call.
- Manual: "W14-25 Manual oats", Breakfast, 437 / 61.3 C / 23.5 P / 11.7 F, sodium 287, notes "W14-25 manual note". Save 20:18:29–20:18:31Z → row 35409440 (created 20:18:29.588Z). All fields equal (db-meal-logs.txt). items [] since the manual form writes totals only. Shown time 3:17 PM = form open time, eaten_at 20:17Z (same kind as 26-009; in 25-002).
- Manual edge: "W14-25 Decimal kcal", no slot, 250.5 kcal / 30.2 C / 12.25 P / 8.4 F. Save 20:19:12–20:19:14Z → row a61f94fd (created 20:19:13.112Z), calories null → 25-001. 12.25 kept at two decimals (no column rounding).
- Build a meal: + Add food → Common → Chicken breast (187 / 0 / 35 / 4, Na 84); Manual → "W14-25 jasmine rice", 1.25 cup, 263 / 57.4 / 5.3 / 0.6, Na 3. Builder total 450 kcal C 57 P 40 F 5. Renamed "W14-25 Built bowl" (the first backspace run left " rice", fixed by a second tap-and-delete, read back before logging), Dinner, favorite box off. An unfocus tap opened the Chicken breast Edit Item sheet by accident; Cancel, nothing changed (22-edit-item-sheet.png; item values unchanged in the row). Log meal 20:21:48–20:21:50Z → row ae7dba02 (created 20:21:48.566Z). Items and totals equal; saved_meals still 1.
- Timeline Meals afterwards shows my three rows only; Decimal row reads 0 kcal. Header "DAILY BUDGET 8,839 kcal · 1007C · 134P · 475F" → 25-006.
- Ticket 24's row f510d5d3 "Spaghetti Bolognese W14-24" (photo) created in my window; expected, not mine, untouched. Its analyze-meal-photo call at 15:18:44 local is 24's (I was on the Manual tab then). COST status 14: logging 1/5 (24), plan 0/3; ticket 25 spent nothing.
- Edge requests in window (edge-requests.txt): sync-all-data + calculate-daily-macros-v6 at login, ensure-credits, garmin-push (server pushes), analyze-meal-photo (24). No describe-meal / vana-* / meal-ai from this run.
- Screens visited: Welcome, Log In (method picker, email), What's New sheet, TrainingPeaks sharing sheet, Timeline (All, Meals), Log a Meal (Describe landing, Manual), Build a Meal (empty, with items), Add food (Recipes, Common, Manual), Edit Item sheet. Look-around Findings: 25-002 (Manual), 25-003 (Build a Meal + Edit Item), 25-004 (Add food), 25-005 (Timeline Meals). Welcome, Log In, sheets and Describe landing are covered by earlier tickets' Findings (02, 12, 23, 26, 30), not repeated.
