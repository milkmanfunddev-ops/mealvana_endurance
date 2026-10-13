# Coach

domain: 7 Coach · folder: `lib/features/coach_mode/` (43 files + generated) · athlete screen `settings/.../coach_connection_screen.dart`

Two halves. The **athlete** pairs with a coach from Settings and then sees the coach's workouts, races, carb plans and
comments in the normal app. The **coach** works in the web Coach Portal (`/coach-portal`), which the phone never
links to.

## What athletes can do here

- **Connect to a coach.** Settings → "Coach Connection" → "Connect with Your Coach · Enter the pairing code your
  coach gave you. Once connected, your coach can view your activities and create nutrition plans for you." →
  "Enter Coach Code" (six characters, "ABC123") → "Connect" → "Connected to coach!". Errors: "Code must be 6
  characters", "This pairing code was not found.", "…has already been used.", "…has expired. Ask your coach for a
  new one.", "You cannot connect to your own pairing code.", "You are already connected to this coach."
- **Talk to the coach.** "Message Coach" opens "Chat" ("Start the Conversation", "Type a message…"). On a workout
  the plan screen shows a "Coach Feedback" card ("No feedback from your coach yet.", "Reply to coach…", "Comment
  sent"). No push notification announces a coach message.
- **See what the coach did.** Workouts, races and carb plans a coach creates appear in the athlete's app exactly like
  their own; nothing marks them as from the coach. Coach edits to the profile and nutrition targets show up in
  Settings.
- **Disconnect.** "Disconnect from Coach" → "Disconnect Coach? · This will remove {name} as your coach. They will
  no longer be able to view your activities or create plans for you." → "Disconnected from coach". Reconnecting to
  the same coach afterwards is refused with "You are already connected to this coach." (the check ignores that the
  old link was archived).

## What coaches can do (web portal)

- "Coach Portal" with "Athletes", "Reports", "Messages" and "Back to App". A web user who is not a coach sees the
  tab too and lands on "Not registered as a coach".
- **Pair an athlete.** "Generate Athlete Code" → "Generate Pairing Code" → a six-character code valid 24 hours
  ("Share this code with your athlete", "Expires in Xh Ym", "Generate New Code" retires the old one). "Remove
  athlete" → "Are you sure you want to remove {name}? You will no longer have access to their data."
- **Work on an athlete.** Tabs "Profile" (name, height, weight, gender, birthday, water bottle, gut training, GI
  sensitivity → "Save Profile"), "Targets" ("Nutrition Target Overrides": pre, during per sport, post; "Reset to
  Defaults" / "Save Targets"), "Events (n)" (+ creates a race for the athlete), "Carb Loading" ("Create Carb Loading
  Plan": link to event, race date, "2 Days" / "3 Days", body weight; day rows open the legacy day page; "Delete
  Carb Loading Plan"), "Activities (n)" (week/month calendar with dots; + opens the New Activity form for the
  athlete; tapping a workout opens its plan in coach view; "Delete activity"), "Chat".
- **Reports.** "Athlete Reports" for "This Week" / "Last Week" / "Custom…": Athlete, Completed, Fuel Logs, Adherence,
  Last Completed, Next Event; a row opens the "Athlete Report" (activity, date, duration, carbs, calories, "Done" /
  "Planned", "PLANNED" vs "ACTUAL", "Athlete Notes"). Read-only.
- **Feedback on a workout.** On the athlete's plan screen the coach sees "Activity Feedback" ("Add feedback…").

## What the data means

`coaches`, `coach_athlete_relationships` (status active | pending | declined | archived; `requested_by`),
`coach_pairing_codes` (coach-generated, 24 h, used once), `athlete_pairing_codes` (an older reverse flow nothing
uses), `coach_messages` (chat and workout comments, keyed by `activity_id` / `nutrition_plan_id`), plus the
athlete's `users`, `activities`, `events` and carb-loading rows written on their behalf through `forUserId`.
Realtime: `chat:{coach}:{athlete}` and `activity-feedback:{activityId}` on `coach_messages` inserts (the chat channel
receives every insert and filters on the device). The server requires an active relationship before a coach can
create a workout or race for someone.

## What already exists to reuse

- `application/coach_service.dart` (facade), `data/coach_repository.dart` + `coach_messaging_repository.dart`,
  `PairingCodeConnectResult` / `PairingCodeConnectFailureReason` (the error texts), `presentation/widgets/activity_coach_feedback_widget.dart`
  (drop-in comment thread for any workout), `screens/coach_chat_screen.dart` (phone and portal), `coach_portal_screen`,
  `portal_sidebar`, `portal_athlete_detail_panel`, `portal_athlete_profile_form`, `portal_nutrition_targets_form`,
  `portal_reports_panel`, `portal_messages_panel`, `coach_activity_detail_controller`; the `forUserId` hook on the
  activity, event and carb-loading flows.

Don't add: another pairing flow (use the coach-generated code), another comment thread. Dead: `create_activity_dialog`,
`create_event_dialog`, `athlete_card`, `pending_request_card`, `portal_reports_placeholder`, `invite_athlete_controller`;
unreachable screens `my_coaches_screen`, `coach_directory_screen`, `athlete_feedback_screen`, `coach_registration_screen`
(routes `/my-coaches`, `/coach-directory`, `/athlete/feedback`, `/coach/apply`; `/coach` lands on the Timeline);
unused service methods `inviteAthleteByCode`, `connectViaPairingCode`, `createActivityForAthlete`,
`createEventForAthlete`, `getNutritionPlanComments`, `subscribeToRelationshipChanges`. Gardening: stale comments at
`coach_connection_screen.dart:15`, `app_router.dart:587,819,1041-1045`, `activity_coach_feedback_provider.dart:20`;
the phone can open `/coach-portal` by deep link and gets a desktop layout.

## Links

- **qa:** none dedicated; `spec/design/components/tab-bar.md:42` (Coach tab, web only).
- **ops:** bug `coach-portal-carb-progress-dead-columns` · feature-request `coach-referral-attribution-pilot-bet`
  (blueprint D5). Not walkable on the phone simulator; the portal needs a web build and a coach account.
- **Related map pages:** `settings.md` · `activities.md` · `events.md` · `carb_loading.md` · `calendar.md` (the
  portal's month/week views) · `nutrition_plan/activity-detail.md` (coach view, feedback card).
