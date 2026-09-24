# Turns on screen vs stored messages (count and order)

Stored rows: db-messages-ebac747d.txt, db-messages-1a24f2bf.txt (vana_messages ordered by created_at, id).
Screen: screenshots in this folder, read top to bottom; the list scrolls, so each turn is placed by
the turn above and below it in the same frame.

## ebac747d (Sep 22, archived Draft 15b6b4f4): 11 stored, 11 on screen, same order

| n | role | stored (start of content / parts) | on screen | frame |
|---|------|-----------------------------------|-----------|-------|
| 1 | assistant | "You're coming off a strong week…" + askChoice | bubble + "How much cooking…" + 3 chips, under the "Tue 22 Sep" divider, first item | 16-ebac747d-top.png |
| 2 | user | "Batch it—cook once, eat across the week" | user bubble | 15-ebac747d-scroll-5.png, 13-…-scroll-3.png |
| 3 | assistant | "Your Tuesday speedwork…" + suggestMeals | bubble + meal cards (Injera, Käsespätzle…) + chips | 13-ebac747d-scroll-3.png |
| 4 | user | "I like these" | user bubble | 14-ebac747d-scroll-4.png |
| 5 | assistant | (empty text) + askChoice | "How much of the week should this plan cover?" + 3 chips | 14-ebac747d-scroll-4.png |
| 6 | user | "Dinners and lunches" | user bubble | 14-ebac747d-scroll-4.png |
| 7 | assistant | "Wednesday's 45-minute bike…" + setSetting + suggestMeals | bubble + "Remembered: Plans dinners and lunches" + cards | 12-ebac747d-scroll-2.png |
| 8 | user | "I like these" | user bubble | 12-ebac747d-scroll-2.png, 10-ebac747d-open-1s.png (top) |
| 9 | assistant | "Your dinners and lunches are set…" | bubble | 10-ebac747d-open-1s.png |
| 10 | user | "That's my week" | user bubble | 10-ebac747d-open-1s.png |
| 11 | assistant | "Your collection covers 14 lunch and dinner slots…" | last bubble, above the plan bar | 10-ebac747d-open-1s.png |

Plan bar: "Your plan · 4 meals" + Review plan (the 4 plan_meals of 15b6b4f4, status archived). See Finding 15-001.

## 1a24f2bf (Sep 16, week 2026-09-13, confirmed plan f2c0bc78): 7 stored, 7 on screen, same order

| n | role | stored | on screen | frame |
|---|------|--------|-----------|-------|
| 1 | assistant | "You're 67 days out from Ironman Cozumel…" + askChoice | bubble + "What matters most for this week?" + 4 chips, under "Wed 16 Sep", first item | 20-1a24f2bf-scroll-5.png |
| 2 | user | "Lean on what worked last week" | user bubble | 20-1a24f2bf-scroll-4.png |
| 3 | assistant | "Last week you hit 4 of 4…" + sameAsLastTime | bubble (batch part stripped by design) | 20-1a24f2bf-scroll-3.png |
| 4 | user | "swap some meals for higher protein" | user bubble | 20-1a24f2bf-scroll-2.png |
| 5 | assistant | "These high-protein bowls…" + suggestMeals | bubble + cards + chips | 20-1a24f2bf-scroll-2.png, -1.png |
| 6 | user | "Next: lunch" | user bubble | 20-1a24f2bf-scroll-1.png |
| 7 | assistant | "You need lunches now…" + suggestMeals | last bubble + cards + chips, above the plan bar | 19-1a24f2bf-open.png |

Plan bar: "Your plan · 6 meals" + "Plan confirmed" (f2c0bc78 has 6 plan_meals, confirmed).

Opening both wrote nothing: counts 11 and 7 unchanged in db-after.txt, no meal_plans row created or updated.
