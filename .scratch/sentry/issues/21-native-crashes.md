# 21: Native crashes

**What to build:** MEALVANA-ENDURANCE-BP (SIGSEGV), C2 (SIGBUS), B7 (watchdog termination), CR (outlined function). With symbols uploaded, read the native frames, find the cause (memory, a plugin, a view hierarchy), and fix or file upstream.

**Blocked by:** 10 Contract; 14 Symbols in release builds

**Status:** ready-for-agent

- [ ] Each crash symbolicated and attributed
- [ ] Fix landed or upstream issue linked with a mitigation
- [ ] Issues resolved or marked with the upstream link in Sentry
