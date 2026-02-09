Design a mobile bottom sheet modal showing a loading state for AI food parsing in a nutrition tracking app. This appears while AI analyzes what the user typed or photographed.

App style: Clean, modern fitness app. Orange (CTAs), cream (backgrounds). Rounded corners, sans-serif typography.

The bottom sheet overlays the main screen (dimmed background). White background, rounded top corners (16px radius).

Layout (top to bottom):

1. DRAG HANDLE - Centered gray pill (40px wide, 4px tall)

2. HEADER - "Analyzing your meal..." in 18px semibold with a small subtle circular spinner to the right of the text (orange color, 18px)

3. ORIGINAL INPUT - The user's text in small muted italic: "grilled chicken 6oz with rice and broccoli"

4. SHIMMER SKELETON ROWS - 3 placeholder rows mimicking the food item layout:

   Each skeleton row:
   - Left: small circle placeholder (12px, light gray shimmer)
   - Title: rounded rectangle placeholder (60% width, 16px tall, light gray shimmer)
   - Below title: shorter rectangle (30% width, 12px tall, lighter gray shimmer)
   - Right side: rectangle placeholder for stepper (80px wide, 28px tall, shimmer)
   - Bottom: thin rectangle (40% width, 10px tall, shimmer)
   - Light divider line between rows

   The shimmer animation pulses left-to-right with a subtle light gradient sweep.

5. Bottom area: Grayed out / disabled "Log Meal" button (full-width, muted gray, 48px height)

6. "Cancel" text button below in muted gray

Design a second variant of this same sheet for PHOTO INPUT:
- Same layout but between the header and skeleton rows, add:
- PHOTO THUMBNAIL - The captured photo displayed at ~120px height, full-width with 16px margins, rounded corners (8px), slight shadow. Shows food on a plate.
- Below photo: "Identifying foods in your photo..." in 13px muted text
- Then the same 3 shimmer skeleton rows below
