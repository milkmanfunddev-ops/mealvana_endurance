# Home shell

domain: 2 Your day · folder: `lib/features/home_shell/` (5 files)

The frame around the home tabs: the floating tab bar ("Timeline", "Events", "Learn"; "Coach" on web), the date
header with "Previous day" / "Next day" and the tappable date title, the calendar sheet host, and the dots-and-tint
logic for the month sheet. Everything an athlete does with it is described on the Timeline page: see
`macro_dashboard.md` ("Move between days", "Open the month", "The tab bar").

Reuse: `application/home_shell_calendar_assembler.dart` (one dot per day, keyed by `displayTime`; tint = any meal
log), `presentation/home_shell_chrome.dart` (header + bar + shrink-on-scroll), `presentation/widgets/home_shell_calendar_host.dart`,
`presentation/providers/home_shell_tab_request.dart` (switch the tab from another screen), `home_shell_providers.dart`
(activities + meal-log dates for the month). The drawing lives in `lib/shared/widgets/kyle_design/navigation/`.
qa: `spec/design/components/{tab-bar,date-header,calendar-sheet}.md`.
