# Terrain recon (stage 6b) — real-payload-corpus bundle, 2026-09-20

Read-only sweep over $APP_ROOT. Findings feed the test plan (DI-18..24) and the stage-7
handoff. **CONFLICT WATCHLIST** — every item must appear in the handoff:

| # | Finding | Risk | What the implementer must do |
|---|---|---|---|
| W1 | **No pg_cron precedent anywhere** — this is the codebase's first scheduled DB job | HIGH | enable the extension by migration; establish the local-CI story (the DI-18/19 harness needs supabase-local with the sweep callable as a plain function, `now` injected — never wall-clock) |
| W2 | **delete-user relies on FK CASCADE from users** (`delete-user/index.ts:77`) — nothing enumerates tables | HIGH | `provider_raw_payloads.user_id REFERENCES users(id) ON DELETE CASCADE` or the new table becomes the next L-6-class orphan surface (Q-INT7's lesson) |
| W3 | **Disconnect hard-purge predates the new table** (Q-INT2's "also delete my synced data") | MED | the purge must cover provider_raw_payloads + any new sample data_types — an APPLICATION of ruled Q-INT2 ("removes what the provider gave us"), not a new ruling |
| W4 | **RLS posture of garmin_health_data not found in migrations** — service-role-only assumed, unverified | MED | verify + replicate the actual posture on provider_raw_payloads; Q-INT8 discipline demands RLS stated, not assumed |
| W5 | **Superseded-behavior test pins**: `training_peaks_transformer_test.dart` (TSSPlanned casing fixtures, fallback classification), `manual_live/training_peaks_api_test.dart` (IsPremium), `intensity_distribution_test.dart` (relevance unconfirmed — sweep before assuming) | MED | these flip WITH the implementation, red-first; commit messages cite the spec change (goldens rule) |
| W6 | **Installed-version coexistence**: old app versions never upload FS/TP raw — a mixed fleet makes under-arrival flows false-alarm | MED | expected_flows preconditions must be SELF-ARMING (a flow arms only after its first-ever row, or keys on capable-client sync markers); never key on last_sync_status (proven liar) |
| W7 | **garmin-push size guard is a comment, not code** (`:260` note; sample capture ruled "size-guarded") | MED | the new sample data_type write needs an explicit byte cap + drop-with-log behavior |
| W8 | **Deploy ordering**: table migration → capable clients → cron sweep → expected_flows seeding; alert email reuses the send-nutrition-plan-email pattern (only existing edge email) | LOW | sequence in the runbook; seeding flows before clients exist would instant-alert |

Positive findings: no existing scrub/de-id utility (greenfield — no twin risk);
`garmin_health_data`'s generic (data_type, jsonb) store takes the new sample types without
schema change; email precedent exists.
