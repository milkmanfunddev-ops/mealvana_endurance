---
name: shorebird-patch
description: Ship a Dart-only fix to a released prod build over the air via Shorebird — the full workflow from "is this patchable?" through backport branch, dry-run, diff review, publish, and verification. Invoked as "/shorebird-patch", "shorebird this fix", "OTA patch this", "hotfix the App Store build". Mechanics live in docs/technical/shorebird-code-push.md — this skill is the checklist and the guardrails.
---

# Shorebird OTA patch

The workflow that shipped patches #1–#3 on 1.26.0 (2026-09-11). Read
`docs/technical/shorebird-code-push.md` FIRST every run — it is the source of
truth for mechanics (auth, commands, flags, the two traps) and this skill
deliberately does not restate it. Current app_ids: `shorebird.yaml`. Current
workflows: `codemagic.yaml` (`*-ios-patch`, `*-android-patch`).

## Gate 0 — is this patchable at all?

- **Dart-only?** `git diff --stat` the fix: only `lib/` (+ tests). Any native,
  asset, pubspec, or schema change → NOT patchable; it ships in the next
  release cut instead. A Drift migration in the diff is an automatic stop.
- **Worth an OTA?** A patch reaches only devices on ONE release version.
  Check the console's Mission Control version distribution first — if the
  target release has trivial adoption, the next cut may serve better.

## Order of operations (the shape that keeps lineages honest)

1. **Fix on a branch off `develop`**, regression tests red-then-green, merge
   to develop `[skip ci]` (--no-ff — a fast-forward puts a non-skip title at
   HEAD and cuts a paid dev build). Develop is the canonical home; the patch
   is a delivery mechanism, not a fork.
2. **Backport branch off the release branch** (never patch from develop —
   doc trap #1). Cherry-pick the fix commits; then verify
   `git diff <release-branch>..HEAD` shows ONLY the intended files, and
   byte-compare the patched lib files against develop's (`git show | shasum`)
   so prod-on-patch and the next release behave identically.
3. **Resolve `--release-version` from Shorebird, never pubspec or the store**
   (doc trap #2 — and note one cut registers separate iOS/Android releases
   with consecutive build numbers).
4. **Dry-run first, read every diff, then ship** — commands, auth, and the
   known-inert diff set are in the doc. A NATIVE diff is a full stop, no
   flag, no ship.
5. **Verify**: `shorebird patches list --release-version=<v>` (the release's
   own list — the app-level latest_patch_number lies across platforms), then
   the console release page.
6. **Android** goes through Codemagic only (keystore constraint — see doc);
   pin its RELEASE_VERSION in `codemagic.yaml` on the backport branch.

## Guardrails

- A patch is a FULL snapshot: the backport branch tree at ship time IS what
  every device runs. Stack later fixes on the same branch so patch N carries
  patch N−1's content.
- Patch builds are real release builds (~15 min local, paid minutes on
  Codemagic). Dry-run costs the same as ship — don't iterate casually.
- Patches land on devices two cold starts after publish (download, then
  apply). Set expectations accordingly; Mission Control shows adoption.
- **Test the shipped patch ON A DEVICE, release-mode.** Unit suites, the
  debug simulator, and the dry run all passed while a release-only bug
  (stripped-assert snackbar-queue trap, patch #3's cause) sat invisible.
  Device retesting caught both follow-on bugs on 2026-09-11.
- After shipping: the release's Notion cut card records the patch (an OTA
  patch changes what that shipped build contains); an ops bug intake exists
  for the defect; the worktree's `ios/Runner.xcodeproj` gets restored
  (Shorebird rewrites it).
- Rollback exists per-patch in the console (Mission Control → Rollback) —
  prefer rolling back over rushing a corrective patch when a shipped patch
  misbehaves.
