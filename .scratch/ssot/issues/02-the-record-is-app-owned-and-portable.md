# 02: The record is app-owned, portable, and knows who ruled

**Status:** done (2026-09-14), sharing box left for Lee
**Blocked by:** 01 (the `by` field in history lines).
**Next:** `/mattpocock-skills:implement 03`

**What to build:** An agent reading CLAUDE.md no longer refuses to apply Lee's verdicts, because
the never-edit rule for the SSOT mirror carves out the decisions folder as app-owned. Xuan clones
the repo, reads the README, and can run every sync command without Lee's machine, home directory
or session. On the page, every verdict records the viewer who gave it, and a ruled card shows who
ruled. Decision mp-262 governs.

- [x] CLAUDE.md carries one line carving `decisions/` out of the never-edit rule, written only by a skill applying a ratifier's verdict
- [x] The README has a "fresh clone" section: what to install, the test command, the apply command, the artifact link
- [x] No path under the page folder or in the sync module assumes a home directory, a user name, or a session id
- [x] The page writes the viewer's identity on every verdict document and shows "approved by Lee, 09-14" style lines on ruled cards
- [ ] The artifact is shared with Xuan and a verdict from a second account lands with that account's name. Lee shares from the page's share menu; the platform gives the page no viewer identity (no `user` capability on this account, room peers carry a null id), so Xuan picks the name in the header once and every verdict carries it as `by`.
