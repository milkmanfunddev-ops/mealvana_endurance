# Dev Sentry read for run 48 (read-only, org milkman-24, project mealvana-endurance-dev)

Read 17:45Z, search_errors last 1 h, every level, newest first. This run's users: 1c31d98e-1413-4233-92ad-1991d1737355
(account A, anonymous until 17:31:19Z) and 656d8eb7-2238-43f5-bf42-747103670f5a (second anonymous session, 17:34:53Z).

Events from this run:
- 17:24:02Z warning HandshakeException "Connection terminated during handshake" (1c31d98e, content fetch, pitfalls.continue_button).
  Known noise: netcut's slowproxy was holding app.mealvana.io and its upstream to 104.18.38.10 hit ETIMEDOUT at 17:24:02.896Z
  (slowproxy.log); the run's own tool cut the connection.
- 17:26:19Z warning SignInWithAppleAuthorizationException error 1000 "Apple Sign-In failed" (1c31d98e): Apple sheet closed. Filed (retest of 30-005).
- 17:33:23Z warning OSError Network is unreachable (1c31d98e, settings.profile_row): delete-user with netcut on, check 10.
  A real failure the athlete saw a message for; the record D9 asks for. Fine.

Not present (the checks this read is for):
- No event for the Google cancel (17:26:01Z), the 429 on Create Account (17:27:31Z), "email already registered" (17:36:09Z),
  or the wrong passwords (17:37:49Z, 17:42:55Z). PASS for those halves of 30-005 and for 30-008.
- No "Notification permission answer not stored: no local profile" warning at any launch in the hour (launches 17:20:02,
  17:20:50, 17:21:47, 17:30:10, 17:33:55, 17:34:10, 17:34:25, 17:34:4x, 17:44:00). PASS 30-011.
- No FlutterError RenderFlex overflow. PASS 30-002.

Other events in the hour belong to other users (607f9dd5 = the shared dev test account, 3FC24DA6, 69DA265B: the other wave
runs 49/50): onesignal init skipped, ListTile ink warnings, OSError, describe-meal 422, SlowOperation. Not this run.
