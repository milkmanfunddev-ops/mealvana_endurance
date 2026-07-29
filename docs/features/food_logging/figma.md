# Food Logging - Figma Design Specs

## App Context

Mealvana Endurance is a nutrition planning app for endurance athletes (runners, cyclists, triathletes). The app currently has a calendar-based Activities tab where users see their scheduled workouts with AI-generated nutrition plans (what to eat before, during, and after each workout). We are adding food logging so users can track what they actually eat throughout the day.

## Design System

- **Style**: Clean, modern, health/fitness app. Warm color palette.
- **Primary colors**: Orange (CTAs, active states), Cream (backgrounds), Blackberry/dark purple (dark mode backgrounds), Teal (success states)
- **Typography**: Clean sans-serif, section headers use medium weight, body uses regular
- **Cards**: Rounded corners (12-16px radius), subtle shadows, white/cream backgrounds
- **Icons**: Outlined style, consistent stroke weight
- **Platform**: iOS and Android (Flutter) - follow Material 3 with custom theming

---

## Screen 1: Activities Tab - Timeline View (Modified Existing Screen)

This is the main screen of the app. We are modifying it to include food logging alongside activities.

### Layout (top to bottom):
1. **Status bar** (system)
2. **Calendar** (existing) - horizontal week view showing 7 days with day-of-week labels and date numbers. Selected date highlighted with orange circle. Small colored dots below dates indicate: orange = activity, blue = event, green = food logged
3. **Daily Macro Dashboard** (NEW) - horizontal strip below calendar showing today's nutrition totals
4. **Timeline** (MODIFIED) - scrollable list mixing activity cards and meal cards in chronological order
5. **AI Text Input Bar** (NEW) - docked at bottom, above the tab bar
6. **Bottom Tab Bar** (existing) - Activities, Events, Settings tabs with floating orange "+" button

### Daily Macro Dashboard Component
- Compact horizontal strip, ~60px tall
- Light background card with subtle border
- Shows 6 values in a single row with small labels above:
  - Calories: "2,040" with "cal" label
  - Carbs: "245g"
  - Protein: "125g"
  - Fat: "62g"
  - Sodium: "1,850mg"
  - Hydration: "2.4L"
- Values in bold/medium weight, labels in small light text
- If no food logged yet, show "No meals logged" with muted styling

### Timeline Content (Chronological)
Activities and meals interleaved by time:

**Activity Card** (existing - no change needed):
- White card with rounded corners
- Activity type icon (running shoe, bike, swimmer) + title + time
- Distance, pace, and duration details
- Status indicator (planned, completed)

**Meal Card** (NEW):
- White card with rounded corners, same width as activity cards
- Left edge: thin vertical color bar (warm orange/amber tone to differentiate from activity cards)
- **Header row**: Meal type icon + meal type name ("Breakfast", "Lunch", etc.) + time ("7:00 AM") + calorie badge ("450 cal")
- **Food list**: 2-3 food item names with quantities, truncated with "..." if more than 3
  - Example: "Oatmeal with blueberries (1.5 servings)"
  - Example: "Scrambled eggs (2 large)"
  - Example: "+2 more items"
- **Photo thumbnail**: Small circular thumbnail in top-right corner if photo is attached
- **Bottom row**: Mini macro summary - C: 58g | P: 22g | F: 12g (muted text, small)
- Tap -> navigates to Meal Detail Screen
- Swipe left -> delete option

### AI Text Input Bar (Docked at Bottom)
- Positioned above the bottom tab bar
- Height: ~56px
- White/cream background with top border or shadow
- **Text field**: Rounded pill shape, placeholder text "What did you eat?" in muted gray
- **Camera icon button**: Right side of text field, circular, takes photo or opens gallery
- **Send button**: Appears when text is entered (orange arrow icon)
- When tapped, text field expands slightly and keyboard opens
- When user types and sends, triggers AI parsing flow (Screen 2)

### Empty State (No Timeline Items for Date)
- Centered illustration (fork/knife or plate illustration)
- "No activities or meals for this date"
- "Tap below to log what you ate" with arrow pointing to input bar

---

## Screen 2: AI Parse Confirmation - Bottom Sheet

Appears as a modal bottom sheet after user submits text or photo for AI parsing.

### Layout:
1. **Handle bar** at top (standard bottom sheet drag indicator)
2. **Header**: "Review Your Meal" title + meal type chip (auto-selected based on time, tappable to change)
3. **Photo thumbnail** (if from camera - shows the photo taken, small, left-aligned)
4. **Original input** - small muted text showing what user typed: "grilled chicken 6oz with rice and broccoli"
5. **Parsed food items list** (editable):

### Each Parsed Food Item Row:
- **Food name**: "Grilled Chicken Breast" (editable text, tappable)
- **Serving**: "6 oz" description text
- **Quantity stepper**: [ - ] 1.0 [ + ] (increment by 0.5)
- **Macro preview**: "280 cal | C: 0g | P: 52g | F: 6g" in small muted text
- **Confidence indicator**: Small green/yellow/red dot (high/medium/low AI confidence)
- **Remove button**: Small X icon on right side

After the list:
- **"+ Add another item"** button (text button, navigates to food search)
- **Meal type selector**: Row of tappable chips: Breakfast, Lunch, Dinner, Snack, Pre-Workout, Post-Workout. Auto-suggested one is pre-selected.
- **Notes field**: Optional, small text input "Add a note..."
- **"Log Meal" button**: Full-width orange CTA button at bottom
- **"Cancel"** text button below

### Loading State (Before Results):
- Same bottom sheet
- Pulsing/shimmer placeholder rows (3 skeleton food items)
- "Analyzing your meal..." text with subtle spinner
- If from photo: show the photo at top while loading

### Error State:
- "Couldn't parse your input" message
- "Try again" button + "Enter manually" button

---

## Screen 3: Add Food Log Screen (Full Screen)

Full-screen modal for adding food when user wants more control than the quick AI input bar.

### Layout:
1. **Navigation bar**: Back arrow + "Log Food" title + "Done" text button
2. **Meal type selector**: Horizontal scrollable chips (Breakfast, Lunch, Dinner, Morning Snack, Afternoon Snack, Evening Snack, Pre-Workout, Post-Workout). Selected chip is filled orange.
3. **Date/time row**: Calendar icon + "Today, 12:30 PM" (tappable to change)
4. **Search bar**: Magnifying glass icon + "Search foods..." placeholder. Full-width rounded input.
5. **Entry method tabs**: Segmented control or tab bar: "Search" | "AI Text" | "Barcode" | "Manual"

### Search Tab:
- Search results list showing food items from database
- Each result row: Food name, serving size, calorie count, small food image thumbnail
- Tapping a result adds it to the "Current Meal" section at bottom
- Sections: "Recent Foods" (last 10 logged) and "Search Results"

### AI Text Tab:
- Large multi-line text input
- Placeholder: "Describe what you ate... e.g., 'large bowl of oatmeal with banana and honey, 2 scrambled eggs, glass of orange juice'"
- "Parse with AI" orange button below
- Results appear inline (same format as Screen 2 food item rows)

### Barcode Tab:
- Camera viewfinder for barcode scanning
- "Point camera at barcode" instruction text
- After scan: shows matched food with nutrition info, "Add" button

### Manual Tab:
- Form fields:
  - Food name (required text input)
  - Serving description (text input, e.g., "1 cup", "6 oz")
  - Calories (number input)
  - Carbs g (number input)
  - Protein g (number input)
  - Fat g (number input)
  - Sodium mg (number input)
  - Fluid ml (number input)
- "Add to Meal" button

### Current Meal Section (sticky at bottom):
- Collapsed: Shows count "3 items | 780 cal" with expand chevron
- Expanded: List of added food items with quantity steppers and remove buttons
- "Log Meal" full-width orange CTA button

---

## Screen 4: Meal Detail Screen

View and edit an existing logged meal. Navigated to by tapping a meal card in the timeline.

### Layout:
1. **Navigation bar**: Back arrow + "Breakfast" (meal type) title + overflow menu (three dots)
2. **Meal header card**:
   - Meal type icon + name + date/time
   - Photo (if attached) - large, full-width, rounded corners, aspect ratio preserved
   - "Add Photo" button if no photo (camera icon + text)
3. **Macro summary card**:
   - Horizontal row of macro totals for this meal:
   - Calories | Carbs | Protein | Fat | Sodium | Hydration
   - Each with value and small label, similar to daily dashboard but for this meal only
4. **Food entries list**:
   - Each entry is a row:
     - Food name (bold) + serving description (muted)
     - Quantity: [ - ] 1.5 [ + ] stepper
     - "280 cal | C: 0g | P: 52g | F: 6g" inline
     - Swipe left to delete
5. **"+ Add Food"** button (text button with plus icon)
6. **Notes section**: Text area showing/editing meal notes
7. **Metadata footer** (small muted text): "Logged via AI text parse" + timestamp

### Overflow Menu Options:
- Edit meal type
- Edit time
- Delete meal (with confirmation dialog)

---

## Screen 5: Photo Capture Flow

When user taps the camera icon from the AI input bar or from meal detail.

### Camera View:
- Full-screen camera viewfinder
- Bottom: Large circular capture button (white ring)
- Top-left: Close/X button
- Top-right: Flash toggle
- Bottom-left: Gallery icon (pick from photos)

### After Capture:
- Full-screen photo preview
- Bottom buttons: "Retake" (outline) | "Use Photo" (filled orange)
- "Use Photo" triggers AI parsing -> transitions to Screen 2 (AI Parse Confirmation) with photo thumbnail shown

---

## Screen 6: Quantity Adjuster Component

Used inline within food item rows throughout the app.

### Design:
- Horizontal layout: [ - ] value [ + ]
- Minus and plus are circular icon buttons, 32px
- Value in center: "1.5" with "servings" label below (or the serving description like "6 oz")
- Minus button decreases by 0.5 (min 0.5)
- Plus button increases by 0.5
- Tapping the value opens a number input for precise entry

---

## Screen 7: Meal Type Selector Component

Horizontal scrollable row of chips used in multiple screens.

### Design:
- Horizontal scroll, 8 options
- Each chip: Rounded pill, ~36px height
- Unselected: Light gray/cream background, dark text
- Selected: Orange filled background, white text
- Order: Breakfast, Morning Snack, Lunch, Afternoon Snack, Dinner, Evening Snack, Pre-Workout, Post-Workout
- Auto-selects based on current time of day

---

## User Flows

### Flow 1: Quick AI Text Log
1. User is on Activities tab timeline
2. Taps text input bar at bottom -> keyboard opens
3. Types "chicken burrito bowl with rice, beans, salsa, and guac"
4. Taps send arrow
5. Bottom sheet slides up with loading shimmer
6. AI results appear: 5 parsed items with estimated nutrition
7. User adjusts quantities if needed
8. Taps "Log Meal" (meal type auto-selected as "Lunch" based on 12:30 PM)
9. Bottom sheet dismisses, new Lunch meal card appears in timeline
10. Daily macro dashboard updates

### Flow 2: Photo Log
1. User taps camera icon in input bar
2. Camera opens, user takes photo of their plate
3. Photo preview -> "Use Photo"
4. Bottom sheet with photo thumbnail + loading shimmer
5. AI identifies: "Grilled salmon fillet, Roasted sweet potato, Mixed green salad"
6. User confirms, adjusts if needed
7. Taps "Log Meal"
8. Meal card appears in timeline with photo thumbnail

### Flow 3: Database Search Log
1. User taps input bar, then taps into the full Add Food Log Screen
2. Searches "banana"
3. Results show bananas from food database with nutrition info
4. Taps to add, adjusts quantity to 2
5. Searches "protein shake", adds it
6. Reviews current meal section at bottom (2 items, 350 cal)
7. Taps "Log Meal"

### Flow 4: Edit Existing Meal
1. User taps a Breakfast meal card in timeline
2. Meal Detail Screen opens showing all food entries
3. User taps [ + ] on oatmeal to increase from 1 to 1.5 servings
4. Swipes to delete the toast entry
5. Taps "+ Add Food" to add a coffee
6. Macro totals update in real-time
7. Taps back arrow to return to timeline (changes auto-save)

---

## Interaction Details

### Gestures:
- **Tap meal card**: Navigate to meal detail
- **Swipe left on meal card**: Reveal delete button
- **Swipe left on food entry**: Reveal delete button
- **Long press meal card**: Show context menu (edit, delete)
- **Pull to refresh timeline**: Refresh activities + meals

### Animations:
- Meal card insert: Slide in from bottom with fade
- Macro dashboard: Counter animation when values update
- Bottom sheet: Standard Material bottom sheet slide up
- AI loading: Shimmer skeleton placeholders
- Delete: Slide out left with fade

### States:
- **Empty day**: Illustration + "No meals logged" + arrow to input bar
- **Loading AI**: Shimmer skeletons in bottom sheet
- **AI error**: Error message with retry + manual fallback
- **Offline**: Can still log food (saves locally), subtle offline indicator
- **Syncing**: Small sync icon in dashboard area while uploading

---

## Responsive Considerations

- **iPhone SE (small)**: Compact macro dashboard (abbreviate labels: "Cal", "C", "P", "F"), meal cards show 2 food items max before truncation
- **iPhone 15 Pro Max (large)**: Full labels, 3 food items visible before truncation
- **iPad**: 2-column layout possible for timeline (activities left, meals right) - stretch goal
- **Dark mode**: Blackberry/dark purple backgrounds, cream text, orange accents remain
