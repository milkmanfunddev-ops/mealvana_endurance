# Plus-address code, read with the Gmail tool

- Requested: 14:59:48 UTC from the app (Log in with email -> Forgot Password -> Send Reset Code)
  for lee+e2e-02-20260923T1450Z@rightpathprogramming.com (account A2).
- Gmail search `to:lee+e2e-02-20260923T1450Z@rightpathprogramming.com newer_than:1d`: one thread,
  id 1a0cec7ba5af11bd, from support@mealvana.io, subject "Reset Your Password",
  received 14:59:50 UTC (2 s later), inbox, delivered to the lowercased plus address.
- The six-digit code in its body was typed into the app's Enter Reset Code screen.
- Signup itself sends no code on dev: `mailer_autoconfirm` is true (auth config read 09-23), so
  the account was confirmed at creation (email_confirmed_at 0.1 s after created_at).
