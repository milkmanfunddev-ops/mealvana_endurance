# 15: Device check and the doc

**What to build:** The debug screen, behind the existing admin gate, has four buttons: throw a Fault, raise a Degraded, record a Note then throw, and call an edge function with a bad payload. Run on the simulator against dev, all four arrive in the dev project within a minute with the right level, the user id and role, the breadcrumb trail, no replay, and the Mixpanel `error_reported` event; the edge one arrives under `edge-dev`. The Sentry integration doc is rewritten for `Report`, the ladder, the allow-list, the guard and the settings. The QA-seed failures seen in the dev project (users RLS 42501, qa-seed uuid upload) are written to the SSOT review queue for the QA repo.

**Blocked by:** 10 Contract; 12 Edge functions report

**Status:** ready-for-agent

- [ ] Four buttons exist on the debug screen, visible only behind the admin gate
- [ ] The ticket records four dev-project event ids and the Mixpanel event, with level, user, breadcrumbs and environment as expected; replay count unchanged
- [ ] The Sentry integration doc describes `Report`, the ladder, the allow-list, the guard test, the edge wrapper and the project settings, and names no deleted class
- [ ] A review-queue entry exists for the QA-seed failures with the issue ids
