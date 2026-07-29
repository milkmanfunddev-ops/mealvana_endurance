Design a full-screen mobile modal for adding food to a meal log in a nutrition tracking app for endurance athletes.

App style: Clean, modern fitness app. Orange (CTAs/active), cream (backgrounds), teal (success). Rounded cards, sans-serif typography.

Layout (top to bottom):

1. NAVIGATION BAR - Left: back arrow. Center: "Log Food" title 17px semibold. Right: "Done" text in orange.

2. MEAL TYPE CHIPS - Horizontal scrollable row. 8 pill-shaped chips: Breakfast, Morning Snack, Lunch (selected - orange fill, white text), Afternoon Snack, Dinner, Evening Snack, Pre-Workout, Post-Workout. Unselected: light gray fill, dark text. Height 34px each.

3. DATE/TIME ROW - Calendar icon + "Today, 12:30 PM" tappable text in 15px. Right side: small chevron indicating tappable. Full width, 44px height, subtle bottom border.

4. SEARCH BAR - Magnifying glass icon + "Search foods..." placeholder. Full-width rounded input, light gray border, cream background, 44px height.

5. TAB SELECTOR - Segmented control with 4 options: "Search" (selected/orange text + underline) | "AI Text" | "Scan" | "Manual". Equal width, 40px height, subtle bottom border.

6. SEARCH RESULTS AREA (showing "Search" tab active):

   SECTION: "Recent Foods" header in 13px caps muted gray
   - Row: "Banana, medium" + "105 cal" right-aligned + small banana image (32px circle) + "+" add button (circular, orange outline)
   - Row: "Greek Yogurt, plain" + "130 cal" + yogurt image + "+" button
   - Row: "Peanut Butter, 2 tbsp" + "190 cal" + "+" button

   SECTION: "Search Results" header (when search query entered)
   - Similar rows with food name, serving size subtitle, calorie count, and "+" add button

7. CURRENT MEAL SECTION - Sticky at bottom, above safe area:
   - Collapsed state: White card with top shadow, showing "3 items | 780 cal" left-aligned + expand chevron icon right side. 48px height.
   - Below: "Log Meal" full-width orange rounded button, 48px height

Show the collapsed current meal section with the Log Meal button visible at the bottom of the screen.
