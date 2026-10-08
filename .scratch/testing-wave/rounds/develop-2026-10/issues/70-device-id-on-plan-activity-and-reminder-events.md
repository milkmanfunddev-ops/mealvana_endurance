# 70: device_id on plan, activity and reminder analytics events

**Status:** ready (round develop-2026-10, fix wave 6)
**Labels:** fix, round:develop-2026-10, area:analytics
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** 60 (it adds `deviceInfoServiceProvider.deviceId` to the eight integration events; this ticket follows the same pattern). Runs after 60 merges.
**Next:** `/testing-wave develop-2026-10` (fix wave 6)
**Model:** opus

**What to build:** Lee (2026-10-08, ticket 60's question): the plan and activity analytics events that send the user id as `device_id`, and the reminder events that send `'unknown'`, carry the real device id. Grep `device_id` across `lib/` and list every event and its current value in Touches before changing anything. The reminder events live on the notification path: CLAUDE.md's notification rule applies (the `notification-testing` skill and `ops/docs/messaging-relay-and-testing.md` are not on this machine; read `notification_service.dart` and the reminder scheduling code first and say so in the fix notes). Ticket 104 (`user_registered`) and ticket 60 are the pattern: `deviceInfoServiceProvider.deviceId`, read before any `await`.

**Touches:** every file that tracks one of those events (filled in by the agent from the grep, listed here before the first edit), `test/` fakes that assert the `device_id` property.

**Questions for Lee.** None.

## Exit
- [ ] Every listed event sends the device id; none sends the user id or `'unknown'`.
- [ ] Analytics fake tests updated; `grep -rl` each changed class under `test/` and run those files (#116).
- [ ] `flutter analyze` clean on touched files.
- [ ] Retest: console check in retest ticket 69 (an activity event and a reminder event carry a device id that is not the user id).

Next: /testing-wave develop-2026-10 (fix wave 6)
