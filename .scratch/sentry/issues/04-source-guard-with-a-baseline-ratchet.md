# 04: Source guard with a baseline (ratchet)

**What to build:** A test in the normal suite walks the app source and fails when a catch block neither rethrows, nor calls `Report` (or an alias listed as acceptable until contract), nor appears in an allow-list file beside the test where every entry has a one-line reason. The same test fails on a Sentry SDK import outside the service and the bootstrap, and on `print` or `debugPrint` inside a catch. It lands green by listing every current violation in a baseline section of the allow-list, so each migration batch deletes its entries and the test ratchets downward; an entry can never be added without a reason.

**Blocked by:** 01 Report service exists

**Status:** ready-for-agent

- [ ] The test exists, runs in `flutter test`, and is green on the branch at the moment it lands
- [ ] The allow-list file has a `baseline` section listing every current violation by file and line signature, and a `reasoned` section that is empty or carries one-line reasons
- [ ] Deleting a baseline entry without fixing its catch turns the test red; adding an unreported catch anywhere turns it red
- [ ] A `sentry` import outside the two permitted locations turns it red; a `print` inside a catch turns it red
- [ ] The test's own matching is documented at the top of the file in plain words, including what counts as reported
