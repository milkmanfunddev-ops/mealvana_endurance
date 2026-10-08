# 32-003 · AI Credits opened by deep link has no Back or close, and an edge swipe does nothing

- kind: bug
- status: closed
- ticket: 32
- run: w3-20261008T1256Z
- screen: AI Credits (/buy-credits)
- decision: fix ticket 46 (Go Home, AI Credits close, credits copy)

**Steps.**
1. Signed in, `xcrun simctl openurl UDID "com.milkman.mealvanaendurance:///buy-credits"`.
2. Look for a way back; swipe from the left edge.

**Expected.**
A Back or close control, as Coach Messages (`/athlete/feedback`) has when opened the same way.

**Actual.**
AI Credits renders (balance 2490, three packs, Restore) with no leading Back or close; an edge swipe from
x=2 does nothing. The only way out was another deep link (`/main`). 08-004 listed `/buy-credits` among the
route-only screens with no Back; ticket 26 left it to ticket 23 and ticket 23 did not touch navigation, so
nothing owns it now. In-app, Get credits pushes it (Back may exist on that path; not checked: no AI spend).

**Evidence.**
- runs/32/i10-buy-credits.png no Back or close
- runs/32/i09-athlete-feedback.png the comparable route with Back

**Decision quote.**
> 

**Triage.**
