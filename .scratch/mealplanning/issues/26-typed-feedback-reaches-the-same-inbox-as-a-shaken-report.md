# 26: Typed feedback reaches the same inbox as a shaken report

**Status:** in-progress (wave 1, 2026-09-15)
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee mealplanning`

**What to build:** A complaint typed to Vana appears in the same Wiredash inbox as a shaken report, with the athlete's words, the sentiment and the conversation id. The ticket's first step finds the ingest path (a Wiredash server API, or the client filing silently when it receives the feedback-saved part); if neither exists, the ticket stops and puts the question on the page instead of building a substitute.

**Decisions:** mp-245, mp-248; approved as mp-304.

**Touches:** supabase/functions/_shared/vana/tools.ts, supabase/functions/tests/vana/feedback_ack.test.ts, lib/features/feedback/data/feedback_repository.dart, lib/shared/widgets/shake_to_report.dart

- [ ] The ingest path is found and named in the ticket, or the ticket stops with an open question on the page.
- [ ] A saved feedback row produces one Wiredash entry carrying words, sentiment and conversation id (seam test with a fake client).
- [ ] The feedback-saved acknowledgement is unchanged for the athlete.

Next: /implement-lee mealplanning
