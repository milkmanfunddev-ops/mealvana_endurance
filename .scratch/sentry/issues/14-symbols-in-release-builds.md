# 14: Symbols in release builds

**What to build:** Prod and dev stack traces read as app code. The Sentry plugin config names the right Sentry project per flavor so dev symbols land in the dev project. The Codemagic symbol-upload step runs only in release workflows, never on the dev auto-cut, and fails loudly when the auth token is missing instead of skipping. A documented step uploads symbols after a Shorebird patch, and it is run once to prove it. Android ProGuard mappings and web source maps are included.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] Plugin config carries a project per flavor; a dev build's symbols upload to the dev project
- [ ] Codemagic: symbol upload is referenced only by release workflows; the dev workflow does not run it; a missing token fails the release step
- [ ] iOS dSYM, Android mapping and web source maps all upload for a release build (verified on the next release cut or by a one-off upload recorded in the ticket)
- [ ] The Shorebird patch runbook includes the symbol upload step, and one patch upload was run and its Sentry artifact listed
- [ ] No Codemagic workflow added or re-armed
