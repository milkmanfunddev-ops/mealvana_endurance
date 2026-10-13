# Create New Activity Plan (the form)

domain: 1 Fuel a workout · screen `nutrition_plan/presentation/screens/new_activity_screen.dart` · route `/distancepacegut`
(also `/distance-pace-gut-entry`) · door page `../nutrition_plan.md`

Where a workout and its fuel plan start. Reached from "+ Add Activity" on the Timeline (date only), from tapping a
planned workout that has no plan yet (pre-filled from it), from an unplanned brick row, from the plan screen's
"Generate Plan", pencil and "Regenerate Plan", from the night-before notification, from a race's "Create Nutrition
Plan", and from the coach portal.

## What athletes can do here

- **Pick the sport.** "RUNNING" · "BIKING" · "SWIMMING" · "BRICK". Switching sport clears any targets already
  generated and re-fetches the weather.
- **Set the date and time.** "DATE" / "TIME": tapping either opens the date picker and then the time picker. A new
  workout defaults to one hour from now, rounded up to the next quarter hour.
- **Name it.** "Workout Name" ("e.g., Long Run" / "Long Ride" / "Tempo Swim").
- **Describe the effort.** "WORKOUT DETAILS": "Distance", "Avg Pace" (or "Avg Speed" for the bike), "Duration"
  in hours and minutes. Pace and duration are always both shown; the one edited last is held and the other is
  derived with an "EST." badge. A chip "your usual · {pace}" fills the athlete's usual pace (training-zone pace, else
  9:00 /mi), and a guard line offers "Use your usual …" when a pace looks wrong. Units: run mi or km and min/mi,
  bike mph or kph, swim meters and min/100m. Brick: "Add Swim leg" / "Add Bike leg" / "Add Run leg", "Remove leg N".
- **Set the intensity.** "ESTIMATE" (chips "Easy Run", "Long Run", "Tempo Run", "Intervals", "Race Pace", "Recovery
  Run", with ride and swim versions) or "PRECISE" (three linked sliders: "Conversational (Z1-Z2)", "Tempo (Z3-Z4)",
  "All-Out (Z5+)"). Estimate / Precise itself is not remembered.
- **Choose the pre-workout window.** "Pre-Run Fueling Window" (Ride / Swim / Activity): a stepper, defaulting by
  session class (race and long sessions 3 h, mid-distance 2 h 30, a moderate 60–90 min session 2 h, an easy one 1 h,
  under an hour 45 min), dropping to 1 h for starts before 7:00 AM, and never more than the time left before the
  start (floor 15 min, cap 4 h). The caption says why: "Capped: session in …", "3 h — long session", "1 h — early
  start"; it disappears once the athlete sets the window by hand.
- **Check the conditions** (run; bike outdoors): "TEMPERATURE" and "HUMIDITY" with an "AUTO" badge while
  forecast-filled, "Auto-filled from location", a source chip "Measured" / "Assumed" (the 20 °C / 60 % fallback,
  45 % indoors) / "Manual", "View Forecast" (opens the forecast screen), and ± steps (−5 to 40 °C; humidity 20–95 %
  by 5). If location is off the line says so with "Open settings" / "Open app settings" / "Enable location";
  "Couldn't fetch weather. Enter manually or try again". Bike: "Environment" Outdoor / Indoor; indoor hides the
  weather and the section reads "Room Conditions". Swim: "Water Type" POOL / OPENWATER, no weather; "Pace from
  Training Peaks zones" when zones exist.
- **Generate.** "Generate Plan" creates the workout as a draft (status `draft`, intensity `moderate`), asks the
  engine for targets and opens "Adjust Your Macros". "Use Routine" (only when a routine exists for the sport)
  picks a saved routine, copies its foods (optionally scaled to fit) and jumps straight to the plan screen.

What carries over and what resets: the window, title, temperature and humidity reset on every entry; distance,
pace, duration, intensity, terrain and units stay from the last form on purpose (qa CF-9), unless the entry
pre-fills them (a tapped workout, a nudge, a race). Date and time always reset to the chosen day. Cycling terrain
and indoor/outdoor and swim pool/open-water and water temperature are accepted by the route but not applied when
re-opening a workout; edit and regenerate also do not carry intensity, temperature or humidity.

## Links

- Writes: a draft `activities` row (`activities.md`), targets into the phone's preferences cache. Engine:
  `generate-macros-v4`.
- qa: `spec/design/surfaces/create-activity-plan.md`, `create-flow-fueling-controls.md` (CF-1…CF-9), intake
  `activity-editor-01…07`, `fueling-window-tier-authority`. ops: bugs `prerun-window-capped-for-past-session`,
  `your-usual-pace-chip-is-tp-zone2-not-history`, `fueling-window-sticks-across-activities`,
  `deep-link-create-screen-back-button-dead`, `nudge-tap-back-button-dead-again`.
- Next screen: `adjust-macros.md`. Weather details: `../weather.md`. Routines: `../personal_templates.md`.
