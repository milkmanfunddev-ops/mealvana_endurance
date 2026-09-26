# 118-008 · Vana's Ask Vana opener says you are tracking well toward 419 g carbs after 464 g logged

- kind: bug
- status: open
- ticket: 118
- run: w36-20260926T0031Z
- screen: Vana companion (Timeline → Ask Vana)
- decision: 

**Steps.**
1. test@test.com, Timeline for Sep 25, tap Ask Vana (00:46Z, conversation ec37f880-05e9-460f-8af0-cbb5e4403260,
   vana_calls 6f1f833d-acaf-4e01-99eb-4b4129b0395d).

**Expected.**
The opener's reading of the day matches its own numbers: 464 g logged against a 419 g target is
over the target.

**Actual.**
"Today you've got a 30-minute swim and a core routine, so you're aiming for 419 carbs and 117g
protein on 3064 calories—your formulas are covered, so that's about 2753 to log in meals. You've
already logged 464 carbs across 16 meals, so you're tracking well toward that target." 464 is 45 g
over 419, and the Timeline's net balance reads +1,512 kcal surplus. The first "419 carbs" and "464
carbs" also lack the "g" the protein figure has. Model output, so it may not repeat; the numbers
came from the day's context, so the comparison should be checked in the prompt or given to the
model already worked out.

**Evidence.**
- runs/118/53-vana-open.png: the opener.
- runs/118/36-timeline.png: +1,512 kcal surplus on the same day.

**Decision quote.**
> 

**Triage.**
