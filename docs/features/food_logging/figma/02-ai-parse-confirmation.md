Design a mobile bottom sheet modal for a nutrition tracking app. This sheet appears after a user types what they ate and AI parses it into structured food items.

App style: Clean, modern fitness app. Orange (CTAs), cream (backgrounds), teal (success). Rounded corners, sans-serif typography.

The bottom sheet overlays the main screen (dimmed background visible above). Sheet has white background, rounded top corners (16px radius).

Layout (top to bottom):

1. DRAG HANDLE - Small centered gray pill (40px wide, 4px tall), 12px from top

2. HEADER ROW - "Review Your Meal" in 18px semibold, left-aligned. Right side: meal type chip "Lunch" in small orange filled pill (auto-selected based on time).

3. ORIGINAL INPUT - Small muted italic text: "grilled chicken 6oz with rice and broccoli" with a subtle background highlight

4. PARSED FOOD ITEMS LIST - 3 items, each in its own row with dividers:

   Item 1:
   - "Grilled Chicken Breast" in 16px medium weight
   - "6 oz" serving description in 13px muted text below name
   - Right side: quantity stepper [ - ] 1.0 [ + ] with circular minus/plus buttons (28px, light gray bg)
   - Below: "280 cal | C: 0g | P: 52g | F: 6g" in 11px muted
   - Small green dot on left (high confidence indicator)
   - Small X remove button far right, 20px, light gray

   Item 2:
   - "White Rice, cooked"
   - "1 cup"
   - Stepper: [ - ] 1.0 [ + ]
   - "205 cal | C: 45g | P: 4g | F: 0g"
   - Green confidence dot, X button

   Item 3:
   - "Steamed Broccoli"
   - "1 cup"
   - Stepper: [ - ] 1.0 [ + ]
   - "55 cal | C: 11g | P: 4g | F: 1g"
   - Yellow dot (medium confidence), X button

5. ADD ITEM BUTTON - "+ Add another item" text button in orange, left-aligned

6. MEAL TYPE SELECTOR - Horizontal scrollable row of pill chips: Breakfast, Morning Snack, Lunch (selected/orange filled), Afternoon Snack, Dinner, Evening Snack, Pre-Workout, Post-Workout. Unselected chips have light gray background.

7. NOTES FIELD - Small text input, light gray border, placeholder "Add a note..." single line

8. LOG MEAL BUTTON - Full-width rounded orange button, white text "Log Meal", 48px height, 16px bottom margin

9. CANCEL - "Cancel" text button below in muted gray, centered
