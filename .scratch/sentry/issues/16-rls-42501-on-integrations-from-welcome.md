# 16: RLS 42501 on integrations from welcome

**What to build:** MEALVANA-ENDURANCE-3W: inserting into `integrations` violates row-level security from the welcome screen's get-started path (59 events, 3 users). Find why the insert runs before the session exists or with the wrong user id, fix it, and resolve the issue.

**Blocked by:** 10 Contract

**Status:** ready-for-agent

- [ ] Root cause written in the ticket
- [ ] The insert no longer runs unauthenticated, or the policy is corrected with a migration applied to dev
- [ ] A seam test covers the path through the real controller
- [ ] Issue resolved in Sentry with the fixing commit
