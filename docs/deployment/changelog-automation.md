# Changelog automation — merge to main → landing-page changelog

On merge to `main`, a GitHub Action generates user-facing release notes from the
merged commits (via Claude) and publishes them to Sanity, which the `me_website_new`
landing page renders on its `/changelog` route.

## Pieces
- `scripts/changelog/generate_and_publish.mjs` — zero-dependency Node script:
  reads the version from `pubspec.yaml`, collects non-merge commit subjects in the
  push range, asks Claude (via the **Vercel AI Gateway**, OpenAI-compatible endpoint)
  for structured user-facing notes (whatsNew / improvements / bugFixes, skipping
  chore/ci/refactor/etc.), and `createOrReplace`s a Sanity `changelog` document with a
  deterministic **dot-free** id `changelog-v<version-with-dashes>` (e.g. `1.22.0` →
  `changelog-v1-22-0`; idempotent).
  - **Why dot-free:** the `production` dataset's anonymous read grant is
    `_id in path("*")`, which matches only single-segment (dot-free) ids. A dotted id
    like `changelog-v1.22.0` is permission-omitted for the public site (visible to
    authenticated reads only), so the entry silently never appears. The `version`
    field keeps the dotted value for display.
- `.github/workflows/changelog-on-main.yml` — runs the script on push to `main`.

## Activate (one-time)
1. Add repo secrets (Settings → Secrets and variables → Actions):
   - `AI_GATEWAY_API_KEY` — the Vercel AI Gateway key (the same one the app's edge
     functions use to call Claude). Note generation runs through it, so no separate
     Anthropic key is needed. Value lives in `secrets/ai_gateway.env`.
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
- `CHANGELOG_MODEL` (default `anthropic/claude-sonnet-4.6`), `AI_GATEWAY_BASE_URL`
  (default `https://ai-gateway.vercel.sh/v1`), `SANITY_PROJECT_ID` (default `sigrvh1t`),
  `SANITY_DATASET` (default `production`), `FROM_REF`/`TO_REF` (the Action passes
  `github.event.before`..`github.sha`).

## Local test
```bash
AI_GATEWAY_API_KEY=$(grep ^AI_GATEWAY_API_KEY= secrets/ai_gateway.env | cut -d= -f2-) \
  DRY_RUN=1 FROM_REF=HEAD~30 node scripts/changelog/generate_and_publish.mjs
# prints the Sanity document it would publish, without writing.
```

## Catch-up
Sanity has entries through **1.22.0** (1.22.0 was published manually on 2026-07-23,
as a `1.18`→`1.22` catch-up). If a released version is missing, run the script for
that range, or ask Claude to create the entries directly via the Sanity MCP — but use
a **dot-free `_id`** (see above) or the entry won't be publicly visible. (Note: only
create entries for versions actually released to users.)

## Notes
- The landing-page changelog is a Sanity `changelog` document type (`version`,
  `title`, `label`, `whatsNew`/`improvements`/`bugFixes` rich text) — see
  `me_website_new/packages/sanity/schemaTypes/changelog.ts`.
- Same release copy can later feed the App Store "What's New" (idea #2) — one source,
  two destinations.
