# Changelog automation — merge to main → landing-page changelog

On merge to `main`, a GitHub Action generates user-facing release notes from the
merged commits (via Claude) and publishes them to Sanity, which the `me_website_new`
landing page renders on its `/changelog` route.

## Pieces
- `scripts/changelog/generate_and_publish.mjs` — zero-dependency Node script:
  reads the version from `pubspec.yaml`, collects non-merge commit subjects in the
  push range, asks Claude for structured user-facing notes (whatsNew / improvements /
  bugFixes, skipping chore/ci/refactor/etc.), and `createOrReplace`s a Sanity
  `changelog` document with a deterministic id `changelog-v<version>` (idempotent).
- `.github/workflows/changelog-on-main.yml` — runs the script on push to `main`.

## Activate (one-time)
1. Add repo secrets (Settings → Secrets and variables → Actions):
   - `ANTHROPIC_API_KEY` — note generation.
   - `SANITY_WRITE_TOKEN` — a Sanity token with write access to project `sigrvh1t`
     (Sanity → Project → API → Tokens → Editor).
   - `VERCEL_DEPLOY_HOOK` — *(optional)* a Vercel deploy-hook URL for the landing-page
     project, POSTed after publish so the new entry shows immediately. (Without it,
     the entry appears on the next landing-page deploy / ISR revalidation.)
2. The workflow only fires once it is **on `main`** (GitHub runs push workflows from
   the branch they live on) — it reaches main on your next release merge.

## Behavior / knobs (env on the script)
- `DRAFT=1` — publish as a Sanity draft (`drafts.*`) for review instead of going live.
  Flip this in the workflow if you want a human to approve each release's copy.
- `DRY_RUN=1` — print the document, write nothing (used for local testing).
- `CHANGELOG_MODEL` (default `claude-sonnet-4-6`), `ANTHROPIC_BASE_URL`,
  `SANITY_PROJECT_ID` (default `sigrvh1t`), `SANITY_DATASET` (default `production`),
  `FROM_REF`/`TO_REF` (the Action passes `github.event.before`..`github.sha`).

## Local test
```bash
ANTHROPIC_API_KEY=... DRY_RUN=1 FROM_REF=HEAD~30 node scripts/changelog/generate_and_publish.mjs
# prints the Sanity document it would publish, without writing.
```

## Catch-up
Sanity currently has entries through **1.18**. If a released version is missing
(e.g. 1.19/1.20 once they ship to main), run the script for that range, or ask
Claude to create the entries directly via the Sanity MCP. (Note: only create entries
for versions actually released to users.)

## Notes
- The landing-page changelog is a Sanity `changelog` document type (`version`,
  `title`, `label`, `whatsNew`/`improvements`/`bugFixes` rich text) — see
  `me_website_new/packages/sanity/schemaTypes/changelog.ts`.
- Same release copy can later feed the App Store "What's New" (idea #2) — one source,
  two destinations.
