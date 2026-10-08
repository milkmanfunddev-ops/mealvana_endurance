# Dev Sentry read for run 67 (read-only, org milkman-24, project mealvana-endurance-dev)

Read 23:13Z and again 23:30Z, search_errors last 1 h, every level, newest first. This run's users: e482a890-d753-4497-9d2e-74bf50be3931
(account A, anonymous from 23:10:02Z, verified 23:18:58Z, deleted 23:27:40Z) and f514bc05-1a9d-4c56-adce-e6060ec34ba0 (B, anonymous, 23:21:41Z).

Events from this run:
- 23:15:31Z warning SlowOperation "startup.total took 11860 ms" (e482a890): first launch after the simulator's cold boot (67-007).
  Known noise for the slowness; the `process_uptime_ms` it carries is wrong (67-005).

Not present (the checks this read is for):
- Nothing at 23:12:31Z-23:13:00Z: no event for Continue with Apple → Close on "Sign in to your Apple Account" (check 3). PASS 48-001.
- No event for the sign-outs (23:21:30Z, 23:26:17Z), the hint's Log in / login as A (23:23:30Z-23:24:22Z), the deep links
  (23:25:17Z, 23:25:38Z, 23:26:28Z, 23:26:40Z) or the delete (23:27:39Z).

Other runs' events in the hour (not this run; 67-006): 22:40:56Z error PlatformException CANCELED (ca2e1928); 23:14:16Z and 23:23:03Z
warning "onesignal init skipped: no app id configured yet" (607f9dd5, 81D07A23…); 23:16:32Z SlowOperation 11733 ms (DE3BCA55…, another
wave simulator's cold boot); 23:22:19Z warning FunctionException 400 describe-meal "description is too long"; 23:23:22Z warning
camera_access_denied; 23:28:38Z fatal FlutterError "Tried to modify a provider while the widget tree was building" (all 607f9dd5).
