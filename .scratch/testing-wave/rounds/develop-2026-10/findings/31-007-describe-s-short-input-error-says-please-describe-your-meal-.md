# 31-007 · Describe's short-input error says "Please describe your meal" for 1-4 characters and is a hardcoded string

- kind: idea
- status: triaged
- ticket: 31
- run: w3-20261008T1256Z
- screen: Log a Meal (Describe tab)
- decision: folded into fix ticket 45 (short-input copy as a content key)

**Steps.**
1. Type "Eggs" and tap Analyze: the field says "Please describe your meal" (validator `trim().length < 5`, log_meal_screen.dart:2075, from code). Idea: say what is missing ("Add a few more words, e.g. how much") and move the text to the content system as CLAUDE.md asks.

**Expected.**


**Actual.**


**Evidence.**
- runs/31/07-analyze-4chars.png — the message under "Eggs"

**Decision quote.**
> 

**Triage.**

