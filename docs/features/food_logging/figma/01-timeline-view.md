Design a mobile app screen for a nutrition tracking app for endurance athletes. This is the main "Activities" tab showing a daily timeline.

App style: Clean, modern fitness app. Warm palette - orange (CTAs/active), cream (backgrounds), teal (success). Rounded cards (12px radius), subtle shadows. Sans-serif typography.

Layout (top to bottom, iPhone 15 size):

1. STATUS BAR (system)

2. CALENDAR STRIP - Horizontal week view. 7 days showing day-of-week abbreviation (Mon, Tue...) and date number. Selected date: orange filled circle behind the number. Small colored dots below each date: orange dot = has activity, green dot = has food logged. Cream background.

3. DAILY MACRO DASHBOARD - Compact horizontal card, ~56px tall, white background, subtle border. Shows 6 nutrition values in a row with small muted labels above each value:
   - Calories: "2,040 cal"
   - Carbs: "245g"
   - Protein: "125g"
   - Fat: "62g"
   - Sodium: "1,850mg"
   - Hydration: "2.4L"
   Values in semibold, labels in 10px light gray text.

4. SCROLLABLE TIMELINE - Chronological list mixing activity cards and meal cards:

   MEAL CARD (7:00 AM - Breakfast):
   - White card, full width with 16px horizontal margins
   - Left edge: thin 3px vertical orange/amber accent bar
   - Top row: fork-knife icon + "Breakfast" bold + "7:00 AM" right-aligned muted + "450 cal" badge (small rounded pill, warm orange background, white text)
   - Food items: "Oatmeal with blueberries (1.5 servings)" and "Scrambled eggs (2 large)" in regular text, 14px
   - Bottom: "C: 58g | P: 22g | F: 12g" in 11px muted gray

   ACTIVITY CARD (9:00 AM - existing style):
   - White card, running shoe icon + "Morning Run" bold + "9:00 AM"
   - "6 miles | 8:30/mi pace | 52 min"
   - Small teal "Completed" badge

   Another MEAL CARD (12:00 PM - Lunch):
   - Same format as breakfast, "Grilled chicken, rice, broccoli", "580 cal" badge

   Another MEAL CARD (3:00 PM - Afternoon Snack):
   - "Banana, almond butter", "290 cal" badge

5. AI TEXT INPUT BAR - Docked above tab bar. White background, top shadow. Contains:
   - Rounded pill text field, light gray border, placeholder "What did you eat?" in gray
   - Camera icon button (circular, 36px) on the right inside the text field
   - Full width with 16px padding

6. BOTTOM TAB BAR - 3 tabs: Activities (calendar icon, selected/orange), Events (flag icon), Settings (gear icon). Orange circular "+" FAB floating above center of tab bar.
