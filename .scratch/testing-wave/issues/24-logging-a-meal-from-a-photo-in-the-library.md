# 24: Logging a meal from a photo in the library

**Status:** ready-for-agent
**Blocked by:** 03 (touches integration_test/flows/meal_log_photo_flow_test.dart).
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** The athlete picks a meal photo from the simulator's library, the app reads it, and the meal saves.

**Decisions:** approved as mp-644.

**Touches:** integration_test/flows/meal_log_photo_flow_test.dart

- [ ] Runs by the runbook: a slot and the build lock taken and released, the console saved to the run folder, a look-around on every screen visited, every problem written as a Finding and nothing fixed.
- [ ] Uses the entitled dev test account from the credentials file; no new account.
- [ ] A food photo is added to the simulator's library first; the method is written in the run notes.
- [ ] Counts against the AI cap.
- [ ] The saved meal's rows are checked by SQL.

Next: /implement-lee testing-wave
