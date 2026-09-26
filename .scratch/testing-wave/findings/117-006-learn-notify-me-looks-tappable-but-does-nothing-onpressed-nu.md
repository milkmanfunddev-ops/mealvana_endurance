# 117-006 · Learn: Notify Me looks tappable but does nothing (onPressed null), no feedback on either card

- kind: bug
- status: open
- ticket: 117
- run: w40-20260926T1052Z
- screen: Learn
- decision: 

**Steps.**
1. test@test.com, Learn tab, tap Notify Me under Premium Video Library, then again.
2. Scroll to Courses; its Notify Me is the same.

**Expected.**
Notify Me gives feedback (29-005: "Notify Me gives feedback and does not write twice on a second tap"), or reads as disabled.

**Actual.**
Nothing happens on either tap: no snackbar, no state change, no console line. The button is drawn as an outlined white pill like an active button, but `coming_soon_section_widget.dart` line 102 sets `onPressed: null, // Disabled`. The Courses card's Notify Me is the same widget.

**Evidence.**
- runs/117/30-learn.png
- runs/117/31-learn-notify-tap1.png
- runs/117/38-learn-courses.png

**Decision quote.**
> 

**Triage.**

