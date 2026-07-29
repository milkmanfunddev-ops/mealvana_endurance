# Usability Issues Checklist

- [x] **Issue 1: Visibility of form bottom**
    - **Problem:** Users easy to overlook the bottom of the form, especially in Create Plan → Cycling/Swimming screens.
    - **Proposed Solution:** Add a visible scroll affordance; or a “Scroll for more” hint shown once?
    - **Actual Solution:** Changed layout to `Stack` with sticky "Generate Plan" button. Added bottom padding to content so it scrolls behind the button, providing visual context.

- [x] **Issue 2: Water bottles context**
    - **Problem:** “how many water bottles”, answer depends on cycling duration and training location.
    - **Proposed Solution:** “how long is this session?”→“Estimated bottles for this session: x”, and a note, “ 1 bottle = 24 oz ”; include -/+ to adjust numbers
    - **Actual Solution:** Updated Onboarding/Settings Cycling Details to ask for "Total bottle capacity", added "1 bottle = 24 oz" note, and used `KylePlusMinusControl` widget.

- [x] **Issue 3: Redundant weather input**
    - **Problem:** app pulls weather(temp+humidity) from location but still ask this again.
    - **Proposed Solution:** If weather is successfully pulled, then pre-fill and notify user (add a note there) it as “Auto” or “already filled”. If no weather available (permissions denied / offline), show weather inputs with prompt.
    - **Actual Solution:** Added "AUTO" badge to Cycling and Running screens when weather is auto-filled from forecast.

- [x] **Issue 4: Indoor/outdoor context**
    - **Problem:** Indoor/outdoor training sessions affects sweating and other stuff.
    - **Proposed Solution:** add a toggle “indoor/ outdoor” when this information is not already available from TP. If indoor, hide weather fields and prefill “estimated room temp”, and give users option to adjust it. If outdoor, then show the local weather temp stuff.
    - **Actual Solution:** Added "INDOOR / OUTDOOR" toggle to Cycling screen. Indoor mode hides weather/forecast controls and simplifies inputs to Room Temp/Humidity. Outdoor mode enables full weather features.

- [x] **Issue 5: Lack of CTA/Process clarity**
    - **Problem:** users don’t see how our app is proceed at the first time, there is no CTA.
    - **Proposed Solution:** use a sticky footer with a “next” button during creating plan.
    - **Actual Solution:** Resolved by the fix for Issue 1 (Sticky "Generate Plan" button).

- [x] **Issue 6: Inconsistent units**
    - **Problem:** there is inconsistent units across onboarding and create plans. including: oz/ml; g/oz; water bottle or cup definition default: 20/24/26 oz
    - **Proposed Solution:** unify; also let users set defaults.
    - **Actual Solution:** 
        1. Added "Unit Preferences" to Settings (Distance: mi/km, Pace: min/mi / min/km).
        2. Updated `RunningInputController` and `CyclingInputController` to respect these settings and convert units for backend.
        3. Updated `RunningTabContent` and `CyclingTabContent` to display correct unit labels.
        4. Updated `ActivityDetailScreen` (and Brick view) to convert fluid targets (mL -> oz) if user prefers Imperial (implied by 'miles' preference).

- [x] **Issue 7: Serving size confusion**
    - **Problem:** confusion on “what exactly is one serving”?
    - **Proposed Solution:** whenever when we show “serving”, pair it with a note: “1 bottle = 24 oz”, “1 cup cooked oatmeal (versus dry oatmeal)”, “1 gel packet”
    - **Actual Solution:** 
        1. Updated Supabase Edge Function `generate-nutrition-plan` to return `serving_size`, `serving_unit`, `serving_qualifier` from the database.
        2. Updated Flutter `FoodItemData` to parse these fields.
        3. Updated `ExpandableFoodItemWidget` to display the serving size note (e.g., "1 bottle = 11 fl oz") below the quantity.

- [ ] **Issue 8: Stale plans from TP changes**
    - **Problem:** if users moves a workout session in TP, our plan becomes stale.
    - **Proposed Solution:** add a refresh button anywhere plans depend on TP schedule. Show “Last updated: Jan 16, 2026 at 3:42 PM” near plan header. On refresh, show a lightweight confirmation “updated”.

- [ ] **Issue 9: Adherence tracking**
    - **Problem:** coaches worries if athletes do not follow the plan, app needs to reclect an actual behavior.
    - **Proposed Solution:** add a per-session status: planned; completed; skipped. make it simple and quick to log.

- [ ] **Issue 10: Under-fueling warning**
    - **Problem:** we learned that under-fueling is common thing.
    - **Proposed Solution:** add a clear but non-judgemental indicator: like a badge, “low fuel risk”, with a note, ”Planned intake is below target for this workload.”

# Ideas (Not Usability Issues)

1. Show the “why” behind recommendations
    - can add a page on profile/setting page, explaining our algorithm (our blog post)
    - add rotating short micro-lessons as “tips”
2. Support special populations; add educational component into our app?
    - menopause
    - immune diseases
    - special diet
