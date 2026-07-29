Design a full-screen mobile view for viewing and editing a logged meal in a nutrition tracking app for endurance athletes.

App style: Clean, modern fitness app. Orange (CTAs), cream (backgrounds), teal (success). Rounded cards (12px radius), sans-serif typography.

Layout (top to bottom, scrollable):

1. NAVIGATION BAR - Left: back arrow. Center: "Breakfast" title in 17px semibold. Right: three-dot overflow menu icon.

2. MEAL HEADER CARD - White card, full width with 16px margins:
   - Row: fork-knife icon + "Breakfast" in 15px medium + "Today, 7:00 AM" right-aligned muted text
   - Below: Large photo of the meal (full card width, 200px height, rounded corners 8px, showing a bowl of oatmeal with berries and eggs on a plate). If no photo, show a dashed border rectangle with camera icon and "Add Photo" text button centered.

3. MACRO SUMMARY CARD - White card below header, full width:
   - Title: "Meal Totals" in 13px muted caps
   - 6 values in a 3x2 grid layout:
     Row 1: Calories "450" (large 22px bold) with "cal" label | Carbs "58g" with "carbs" label | Protein "22g" with "protein" label
     Row 2: Fat "12g" with "fat" label | Sodium "380mg" with "sodium" label | Hydration "350ml" with "hydration" label
   - Each value: number in semibold, label in 10px muted text below

4. FOOD ENTRIES LIST - White card:
   - Section title: "Foods" in 13px muted caps + item count "(3 items)" muted

   Entry 1:
   - "Oatmeal with blueberries" in 15px medium
   - "1.5 servings" in 13px muted below
   - Right side: quantity stepper [ - ] 1.5 [ + ] with small circular buttons
   - Below name: "225 cal | C: 42g | P: 8g | F: 4g" in 11px muted
   - Subtle divider

   Entry 2:
   - "Scrambled Eggs"
   - "2 large"
   - Stepper: [ - ] 2.0 [ + ]
   - "180 cal | C: 2g | P: 12g | F: 14g"
   - Divider

   Entry 3:
   - "Whole Wheat Toast"
   - "1 slice"
   - Stepper: [ - ] 1.0 [ + ]
   - "80 cal | C: 14g | P: 3g | F: 1g"

5. ADD FOOD BUTTON - "+ Add Food" text button in orange with plus icon, left-aligned, 44px height

6. NOTES SECTION - White card:
   - "Notes" label in 13px muted caps
   - Text area with light gray border: "Felt good energy from this meal before my run" in 14px regular

7. METADATA FOOTER - Small muted text, 11px: "Logged via AI text parse - 7:12 AM"
