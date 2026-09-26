# 117-004 · Month picker: Today moves the selection but leaves the sheet open, and the Next day arrow moves with the title's width

- kind: bug
- status: open
- ticket: 117
- run: w40-20260926T1052Z
- screen: Month picker (timeline date dropdown)
- decision: 

**Steps.**
1. test@test.com, Timeline, open the date dropdown, tap 21: the sheet closes on Monday, September 21.
2. Open it again, tap the month arrows (August, October), then Today.
3. On a past day, tap the Next day arrow where it sat on the previous day's title.

**Expected.**
Today lands on today and closes the sheet, like a day tap does. The arrows stay put while the title changes.

**Actual.**
Today moved the selection to 26 and back to September but left the sheet open until swiped down; the timeline then read Today. Separately, the Next day arrow sits right after the title, so its x moves with the day name's width (279 on "Today, September 26", 295 on "Sunday, September 20"): twice a tap at the old position hit the title and opened the month picker instead of moving a day. Markers (30-007 step 1): Sep 17-24 have only skipped sessions and still carry no marker; 16 and 25 green (completed), 26-30 orange rings.

**Evidence.**
- runs/117/20-month-picker-sep.png
- runs/117/21-month-picker-aug.png
- runs/117/22-month-picker-oct.png
- runs/117/23-after-today-tap.png
- runs/117/24-after-sheet-swiped-down.png

**Decision quote.**
> 

**Triage.**

