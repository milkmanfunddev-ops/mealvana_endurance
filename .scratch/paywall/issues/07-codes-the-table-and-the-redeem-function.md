# 07: Codes: the table and the redeem function

**Status:** done (wave 2, 2026-09-22)
**Blocked by:** 01.
**Next:** `/implement-lee paywall`
**Model:** opus

**What to build:** A signed-in caller posts a code to `redeem-code`. A coach entering their own code is marked coach and gets 30 days of `pro`. An athlete entering a coach or influencer code gets the attribute set and a pending pairing. A giveaway code grants 365 days once. A wrong, expired or used code gets a plain reason.

**Decisions:** mp-458, mp-429; approved as mp-486.

**Touches:** supabase/migrations, supabase/functions/redeem-code

- [x] The `codes` table exists on dev with type, owner, validity window and perk; only the service role writes it.
- [x] Each code type and each refusal is covered by a handler test with a fake REST client and database.
- [x] Deployed to dev and a coach code redeemed by curl grants `pro`.

Next: /implement-lee paywall
