# 07: The production cutover carries the photos

**What to build:** Whoever runs the meal-planning production cutover has exact steps to bring the
photos across, so prod never loads a picture from dev storage. Web-address photos need nothing,
because their addresses work from anywhere. This ticket changes the runbook only; nothing is run
against prod.

**Blocked by:** 05

**Status:** ready-for-agent

- [ ] The meal-planning cutover runbook gains ordered steps:
      1. Apply the bucket migration to prod.
      2. List every current-photo address and History storage path that points at dev storage.
      3. Copy those files into the prod bucket at the same paths.
      4. Rewrite the host in the current-photo fields and History rows.
      5. Run a read-only verify that no address still names the dev project.
- [ ] The runbook states that the whole dev bucket isn't copied, only the files referenced by
      shown photos and History.
- [ ] The copy and rewrite are scripted, idempotent and have a dry-run mode that prints counts.
      A dry run against dev prints the expected count (109 switchover photos plus any Tester
      uploads).
- [ ] The existing image gate and verify steps in the cutover folder are updated to check the new
      fields, not the pipeline's image columns.
- [ ] The prod `app_config` is untouched, and the deploy playbook's ordering is respected.
