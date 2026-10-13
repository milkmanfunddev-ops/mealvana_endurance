# Learn (education)

domain: 8 Learn and ask Vana · folder: `lib/features/education/` (10 files)

The "Learn" tab of the home shell.

- **Mealvana 101 · Free nutrition lessons for endurance athletes.** A row of lesson cards (number, play button,
  duration, title, description). Tap to play in the app; "Failed to load video" / "Retry" on error. Lessons are the
  published rows of `education_content` with type free, in sort order; videos are MP4 files on AWS CloudFront.
  Offline, the last list is kept on the phone; with nothing cached: "Couldn't load the lessons. Check your
  connection and try again."
- **Pro Videos** and **Courses** are "Coming Soon" cards ("Premium Video Library · Expert-led deep dives on race
  nutrition, hydration strategies, and performance fueling." / "Structured Learning Paths · Step-by-step courses from
  beginner to advanced endurance nutrition.") with "Notify Me" → "Noted" ("We'll let you know"). Nothing is gated;
  there is no Pro check in this folder.

No progress is stored; watching exists only as analytics: `education_video_opened`, `education_video_closed`,
`education_video_completed` (fires at 90 % actually played; properties `percent_watched`, `watched_sec`,
`furthest_sec`, `duration_sec`), `education_notify_me_tapped`. A completed lesson counts as a core fueling action
in the blueprint's Weekly Fueling Athletes definition. Reuse: `education_screen`, `video_player_screen` (also used
by the plan's carb explanation), `coming_soon_section_widget`, `education_cache`, `education_interest_service`.
Dead: `video_card_widget.dart`, route `/learn/video`. qa: none. Related: `macro_dashboard.md` (the tab bar).
