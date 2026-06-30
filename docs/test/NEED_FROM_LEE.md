# Things Only Lee Can Do (Test/Infra Unblockers)

Running list of items that require a human — a secret value, a dashboard
action, or a product decision — that I cannot do myself. 2026-06-25 onward.

## Open — blocking

1. **Sentry `SENTRY_AUTH_TOKEN`** (build-time symbol upload).
   - It's the ONLY Sentry gap — `SENTRY_DSN` is already set on Supabase (dev+prod)
     and Codemagic (both groups). The token was never minted.
   - I can't auto-mint it today: the chrome-devtools MCP connection is dead
     (a known unfixed design issue) AND it runs an isolated Chrome profile not
     logged into your Sentry.
   - **Quickest:** mint at https://sentry.io/settings/auth-tokens/ (org
     `milkman-24`; scopes `project:releases`, `project:write`, `org:read`) and
     paste it here — I'll push it to the Codemagic `mealvana_dev` + `mealvana_prod`
     groups.
   - **Better long-term (lets me drive your real browser):** switch to
     `@playwright/mcp` in `--extension` mode (Microsoft, actively maintained,
     persistent connection — unlike chrome-devtools-mcp). One-time: install the
     Playwright Chrome extension
     (https://chromewebstore.google.com/detail/playwright-extension/mmlmfjhmonkocbjadbfplnigmagldckm),
     then I reconfigure `.mcp.json` and can attach to your logged-in Sentry tab
     to mint the token (and handle future browser tasks) myself.

2. **Dev Supabase publishable key** (`sb_publishable_…` for `vlmtsdzpnjnavdgytcmi`).
   - Doesn't exist in any file or in Codemagic. Needed to finish migrating the
     dev app off the legacy anon key so legacy keys can be disabled.
   - **Do:** Supabase dashboard → project `vlmtsdzpnjnavdgytcmi` → Settings → API →
     copy the Publishable key → add `SUPABASE_PUBLISHABLE_KEY=sb_publishable_…`
     to `.env.dev.local`. (Also add the prod publishable key to `.env.prod.local`.)
     Then I complete the `app_config.dart` + `main_*.dart` migration.

## Open — security (found 2026-06-30)

4. **Rotate the Resend API key.** `send-nutrition-plan-email/index.ts:4` has a live
   key committed as a hardcoded fallback (`re_DHjg7ayY_…`). Rotate it in Resend,
   set `RESEND_API_KEY` in Supabase secrets, and I'll remove the source fallback.
5. **`save-user-food` auth hole** (not a secret, but security): the function trusts
   `device_id` from the body under the service-role key — any caller can write food
   as another user. I can fix the code (validate against the JWT); flag if you want
   it prioritized.

## Decisions needed (non-blocking)

3. **Delete dead-code screens?** Two confirmed (zero references in `lib/`):
   `SportPreferencesScreen` (BUGS_FOUND #1) and `CurrentPlanScreen` (#7, whole
   file commented out). Confirm and I'll remove both + the dead route reference.

## FYI (no action, just awareness)

- A background agent ran a `clean` mid-session that wiped all generated
  `.g.dart` files; I recovered with `build_runner`. The app would not have
  compiled in that window. (Mitigation: agents are now instructed never to clean.)
- The exposed dev service_role key is already removed from the working tree;
  it still exists in git history (full rotation pending item #2).
