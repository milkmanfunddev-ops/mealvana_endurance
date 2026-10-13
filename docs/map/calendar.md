# Calendar

domain: 2 Your day · folder: `lib/features/calendar/` (13 files)

Athletes never see a screen from this folder. The month sheet they use is drawn by `home_shell` (see
`macro_dashboard.md`, "Open the month"); the athlete app has no week view. This folder holds the app-wide selected
day and the data service behind Events and sync, plus the month/week grids that only the web coach portal shows.

Reuse: `presentation/providers/calendar_selected_date_provider.dart` (the selected day every tab reads; resets on
user change), `application/calendar_service.dart` + `calendar_controller.dart` (local events, carb-loading plan and
days, activities), `presentation/widgets/calendar_{month,week}_view_kyle.dart` (coach portal only, behind its
week/month toggle). Dead: `calendar_day_indicators_provider.dart`, `upcoming_event_widget.dart`, the
`activityDetailProvider` in `calendar_controller.dart`. Stale: `calendar_view_provider.dart:9-15` names callers that
no longer exist. Related: `coach_mode.md`, `events.md`.
