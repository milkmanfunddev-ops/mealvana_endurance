# 13: Sentry projects configured

**What to build:** Both Sentry projects carry the agreed settings, applied through the Sentry API or MCP and recorded in the ticket: spike protection on; a dev project cap of 2,000 errors a month; inbound filters for browser extensions and legacy browsers; per project one "New issue" rule and one "Regression" rule, environment production, action email, once per 24 hours per issue; project digests at 30 minutes minimum and 60 maximum; the two default rules replaced and the pull-request rule deleted; dev gets the weekly report only; one cron monitor on `raw-retention-sweep` (`17 3 * * *`, 30-minute grace) bound to the check-in from ticket 12; release health confirmed to show sessions per release after the SDK bump.

**Blocked by:** 12 Edge functions report

**Status:** ready-for-agent

- [ ] Spike protection enabled on both projects; dev project quota cap set to 2,000
- [ ] Each project has exactly two issue alert rules (New issue, Regression) with the agreed filters, action and frequency; the default rules and the pull-request rule are gone
- [ ] Digest settings 30/60 minutes on both projects; weekly report on for dev
- [ ] A cron monitor `raw-retention-sweep` exists in prod with the schedule and grace period and shows at least one check-in
- [ ] Release health shows crash-free sessions for the current dev release
- [ ] The ticket lists every setting changed with before and after values
