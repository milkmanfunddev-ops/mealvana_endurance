# 19: Edge gateway 502 and 504

**What to build:** MEALVANA-ENDURANCE-B5, AA, AB, C1, C4, C3, C0, BM: `SentryHttpClientError` 502/504 from `functions_client.invoke` and the connected-apps row. Identify the function per issue, whether cold start, timeout or upstream, fix what is fixable, and classify the rest as Degraded in the allow-list with a reason.

**Blocked by:** 10 Contract

**Status:** ready-for-agent

- [ ] Each issue mapped to a function and a cause
- [ ] Fixes landed or the cause documented; timeouts raised only with a reason
- [ ] Issues resolved in Sentry
