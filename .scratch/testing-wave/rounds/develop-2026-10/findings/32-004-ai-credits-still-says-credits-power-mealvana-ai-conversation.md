# 32-004 · AI Credits still says credits power 'Mealvana AI conversations' after Jade was archived (ticket 27)

- kind: bug
- status: triaged
- ticket: 32
- run: w3-20261008T1256Z
- screen: AI Credits (/buy-credits)
- decision: fix ticket 46 (Go Home, AI Credits close, credits copy)

**Steps.**
1. Signed in, open AI Credits (`/buy-credits`) and read "How credits work".

**Expected.**
After ticket 27 archived the Jade chat (08-002), nothing in the app offers or sells a Mealvana AI
conversation.

**Actual.**
"AI credits power coach insights, meal photo analysis, meal descriptions, and Mealvana AI conversations.
Credits are consumed per request and never expire." The literal sits at
`lib/features/ai_credits/presentation/screens/buy_credits_screen.dart:328`. Other "Mealvana AI" strings left
in the app name the meal-estimate feature, which ticket 27 keeps (`log_meal_screen.dart:2042`,
`today_log_section.dart:244`, `edit_meal_log_screen.dart:367`).

**Evidence.**
- runs/32/i10-buy-credits.png "How credits work" text

**Decision quote.**
> 

**Triage.**
