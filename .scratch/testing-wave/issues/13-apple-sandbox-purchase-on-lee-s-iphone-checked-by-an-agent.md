# 13: Apple sandbox purchase on Lee's iPhone, checked by an agent

**Status:** ready-for-human
**Blocked by:** 05.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Lee installs a build that buys through Apple, not the Test Store, on his iPhone, and buys with a sandbox tester. An agent checks App Store Connect in the browser, RevenueCat by API and the dev database by SQL, and records whether all three agree.

**Decisions:** mp-289; approved as mp-633.

**Touches:** docs/release/sandbox-trial-runs/

- [ ] Status ready-for-human: Lee buys; the agent checks.
- [ ] The sandbox tester is added to the credentials file.
- [ ] RevenueCat shows the App Store purchase; the dev webhook's handling of it (dev drops real production events) is recorded; App Store Connect's sandbox view is checked through the browser.
- [ ] The run is written up beside the earlier sandbox trial runs and any disagreement is a Finding.

Next: /implement-lee testing-wave
