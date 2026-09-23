# Testing waves: agents and Patrol test the paying, planning, shopping and logging paths until nothing is open

**Status:** ready-for-agent

Written by `/to-spec` on 2026-09-23 from Lee's grilling session the same day. The glossary terms used here
(Testing wave, Finding, Follow-up test, Test Store, Lapsed, Gate, Grant, Admin) are in `CONTEXT.md`.

## Problem Statement

Paying for the app, meal planning with Vana, shopping lists with Kroger, and meal logging were each built
across many waves, and each wave checked its own ticket. Nobody has run them end to end as an athlete
would: sign up, meet the paywall, buy, cancel, come back, plan a week, shop it, log what was eaten. When a
wave did check on a device, it checked the screen and rarely checked that RevenueCat and the dev
database agreed with what the screen showed. The Patrol suite has drifted: its README lists flows that
no longer exist, the signup flow was rewritten for the paywall and has never been run, and several flows
were last touched in early September. The old bug lists in the test docs have been abandoned since the
summer. Lee has no single place that says what is broken, what contradicts a decision in the SSOT, and
what has not been tried yet.

## Solution

Testing proceeds in rounds called Testing waves. In each wave, agents drive the real dev app on
simulators through the mobile MCP, one scenario per ticket. While they drive it they check RevenueCat,
the dev database and the app's console, and they write the deterministic parts of each scenario into a
Patrol flow so the suite can repeat it without an agent.

Agents fix nothing during a run. Everything they find becomes a Finding, one file each, in one folder:
a bug, a clash with an SSOT decision, a Follow-up test, or an idea. On every screen they visit they stop
to look for other paths through it and other ways it could break, and write each one down as a
Follow-up test. The scenario list therefore grows as the waves go.

After each Testing wave, Lee and an agent triage the open Findings in the terminal. SSOT clashes become
decision cards and Lee rules on them. Bugs become fix tickets. Lee picks up to ten Follow-up tests for
the next round. A fix wave runs, then a retest wave runs what the fixes touched plus the chosen
Follow-up tests. The loop ends when no Finding is open and no Follow-up test is waiting.

## User Stories

### Running the waves

1. As Lee, I want testing split into many small scenario tickets, so that each hard-to-test path gets its own deliberate run instead of a skim.
2. As Lee, I want tickets grouped into waves run by the same machinery as the build waves, so that I start, watch and close them the way I already do.
3. As Lee, I want two tickets to run at a time, so that a wave moves along without exhausting the Mac's memory.
4. As an agent, I want to take a build lock before building the app and release it once the app is running, so that two builds never run together and crash the machine.
5. As an agent, I want to claim a simulator from the pool and release it straight after my run, so that the other agent in the wave can get one.
6. As an agent, I want to terminate the app already on my simulator before I rebuild, so that its memory is freed first.
7. As Lee, I want no full unit-test run while a Testing wave is live, so that the wave's builds are not killed.
8. As Lee, I want each round to follow the same cycle (Testing wave, triage, fix wave, retest wave), so that the process has a known shape and a known end.
9. As Lee, I want the loop to stop only when no Finding is open and no Follow-up test is waiting, so that "done" means something I can check.
10. As Lee, I want each retest wave limited to ten Follow-up tests of my choosing, so that the backlog cannot grow faster than we work it down.

### Findings

11. As an agent, I want to record every problem as a Finding instead of fixing it, so that my run stays a test and all the fixing happens after triage.
12. As an agent, I want each Finding in a file of its own, so that two agents writing at the same time never collide.
13. As an agent, I want every Finding to carry a kind (bug, SSOT conflict, Follow-up test, idea), a status, the ticket it came from, the screen, the steps, what I expected, what happened, and the evidence, so that triage can act without rerunning me.
14. As an agent, I want to attach screenshots, console excerpts, RevenueCat records and database rows to a Finding, so that it can be judged from the file alone.
15. As an agent, when a bug contradicts or tests the edge of a decision in the SSOT, I want to cite the decision's id and quote it, so that triage can see whether the code or the decision is wrong.
16. As an agent, I want to keep going after a Finding unless it makes the rest of the scenario meaningless, so that one stray console line does not end a whole ticket.
17. As an agent, when a Finding does make the rest meaningless, I want to mark the ticket stopped and say why, so that the retest knows where to resume.
18. As Lee, I want an index of all Findings grouped by kind and status, generated from the files, so that I see the whole state of testing in one place.
19. As Lee, I want an SSOT conflict to become a decision card during triage, so that I rule on it through the record like every other decision and the newest ruling wins.
20. As Lee, I want each bug turned into a fix ticket or closed as won't-fix during triage, so that nothing stays open without an owner.
21. As Lee, I want a Finding closed only when a retest confirms the fix, so that "fixed" is proven on the device.

### Growing the scenario list

22. As an agent, I want a look-around step on every screen I visit, where I list other paths through the screen and other ways it could break, so that the scenario list grows from what the app shows.
23. As an agent, I want each of those written as a Follow-up test Finding with the screen and the idea, so that a later round can pick it up.
24. As Lee, I want Follow-up tests from all agents gathered with the rest of the Findings, so that I choose the next round's tests from one list.
25. As an agent in a retest wave, I want to run the chosen Follow-up tests and turn each into pass or a new Finding, so that the backlog shrinks.

### Credentials and test accounts

26. As an agent, I want one credentials file in the gitignored secrets folder listing the admin account, Lee's Kroger login and every test account created, so that I never have to ask for a password.
27. As an agent, I want to type the passwords from that file myself, so that runs do not stop for Lee.
28. As an agent, I want to sign up new accounts at plus addresses on Lee's work mailbox, unique per ticket and run, so that each run starts from a fresh account and nobody else's run depends on it.
29. As an agent, I want to read the signup and sign-in codes from that mailbox with the Gmail tool, so that signup needs no human.
30. As an agent, I want to add a row to the credentials file for every account I create (address, password, what it bought, when, its current state), so that later runs can reuse a paid or lapsed account.
31. As an agent, I want to delete my account through the app's own delete-account flow at the end of my run, so that deletion is tested every time.
32. As Lee, I want a sweep that removes any leftover test accounts from dev, so that failed deletions do not pile up.

### Paying for the app

33. As a new athlete, I want to sign up and meet the onboarding paywall with no way to close it, so that the test proves the Gate stops a never-paid account.
34. As the agent testing signup, I want to confirm that RevenueCat has a customer for the new account and the dev database has no entitlement row yet, so that the starting state is right.
35. As a new athlete, I want to start the trial by buying through the Test Store, so that a purchase can be tested on a simulator.
36. As the agent testing purchase, I want to confirm that the Gate opens, RevenueCat shows the subscription and its expiry, and the entitlement row in the dev database has the same expiry, so that all three agree.
37. As the agent testing purchase, I want to find out whether Test Store purchases reach the dev webhook at all, so that we know whether the entitlement row can be checked on a simulator or only on a device.
38. As a paying athlete, I want to sign out and back in and see no paywall, so that a paid account is recognised on return.
39. As the admin, I want to sign in and skip the paywall, so that the admin bypass is proven.
40. As the admin, I want to try an AI action and record what the server does, so that we know how the client-only bypass behaves against the server's check.
41. As a paying athlete, I want to reinstall the app and restore my purchase, so that Restore purchases is proven.
42. As a paying athlete, I want to cancel, keep full access until my period ends, and then become Lapsed, so that cancellation follows the rule in the SSOT.
43. As the agent testing cancellation, I want to confirm that RevenueCat and the entitlement row agree on the date access ends, both before and after it passes, so that the server and the app agree on when access ends.
44. As the agent testing cancellation, I want to cancel inside the Test Store if it allows it, or else use a Grant that expires within minutes, so that the change from open to Lapsed can be watched in one run.
45. As a Lapsed athlete, I want to sign in and see my data read-only with the plan-ended bar, so that I know my plan ended without losing my history.
46. As a Lapsed athlete, I want an edit or an AI action to open the paywall as a sheet I can close, so that the write guard and the AI guard are proven.
47. As a Lapsed athlete, I want to resubscribe and have full access back, so that coming back works.
48. As a coach, I want to redeem a coach code and get 30 days of Pro, so that the coach path is proven.
49. As an athlete, I want to redeem an athlete code and an invalid one and a too-long one, and see the right answer each time, so that code redemption handles every case.
50. As a paying athlete, I want the Subscription screen to show my plan, its expiry and a way to manage it, so that I can see what I pay for.
51. As an athlete, I want to delete my account in the app and find Supabase and RevenueCat in the expected state afterwards, so that deletion is proven. If deletion fails, the ticket stops.
52. As an athlete who deleted my account, I want to sign up again with the same address and start as a new account, so that deletion leaves nothing behind that changes what the Gate decides.
53. As Lee, I want one ticket where I buy through Apple's sandbox on my iPhone while an agent checks App Store Connect, RevenueCat and the dev database, so that the real Apple path through the webhook is proven once.

### Planning meals

54. As an athlete, I want to start a new plan and see it open a new Vana conversation, so that planning starts clean.
55. As an athlete, I want to open the conversation list, pick an older conversation, and see its whole history load, so that past planning is not lost.
56. As an athlete, I want to confirm a plan and see the plan bar, with the week's other plans archived, so that confirming does what it says.
57. As an athlete, I want to open the previous plans sheet and open an old plan, so that I can look back at earlier weeks.
58. As an athlete, I want to browse with Vana, so that browsing is proven.
59. As Lee, I want no more than three new plans generated per wave across all agents, with everything else reusing the plans already on the dev accounts, so that testing does not run up the AI bill.

### Shopping

60. As an athlete, I want confirming a plan to create a shopping list whose items match the plan, so that I can shop the week.
61. As an athlete, I want to see previous shopping lists, start a new one, and delete one, so that list management works.
62. As an athlete, I want the items I check off to stay checked after a restart and after going offline, so that the list keeps up with me in the store.
63. As an athlete, I want to connect Kroger through its sign-in sheet with Lee's Kroger login, so that the OAuth connection is proven.
64. As the agent testing Kroger, I want to try driving the sign-in sheet through the MCP and then through Patrol's native layer, and record where it stops if it stops, so that we learn whether this step can run without Lee.
65. As an athlete, I want Kroger to match my list and hand off to checkout, so that the retailer path works end to end.

### Logging meals

66. As an athlete, I want to log a meal by describing it, so that Describe is proven.
67. As an athlete, I want to log a meal from a photo in my library, so that photo logging is proven on a simulator without a camera.
68. As an athlete, I want to log meals from Manual, Recent, Common, Recipes and build-a-meal, so that every way of logging is proven.
69. As an athlete, I want to edit and delete a logged meal and see the day's totals change, so that corrections work.
70. As an athlete, I want to scan a barcode if the simulator allows it, so that barcode logging is tried, or else written down as needing a device.
71. As Lee, I want no more than five AI logging calls per wave across all agents, so that logging tests stay cheap.

### The app in general

72. As an athlete, I want the app to start cold, sign in, and render every tab without a console error, so that the basics are proven.
73. As an athlete, I want the timeline and the fuelling plan to show my week, so that the core of the app is proven.
74. As an athlete, I want settings and profile to open and sign-out to work, so that the account basics are proven.

### Patrol

75. As Lee, I want the existing Patrol flows audited, the outdated ones fixed, and the README and runner notes corrected, so that the suite reflects the app as it is.
76. As Lee, I want each scenario's deterministic part added as a Patrol flow and listed in the self-hosted runner, so that it can be rerun later without an agent.
77. As Lee, I want the scenarios that depend on AI output (Vana conversations, Describe) to stay agent-only, with Patrol covering only their stable edges, so that the suite does not flake on model output.
78. As Lee, I want the Patrol signup flow to sign up at a unique plus address each run, so that it never collides with an account left from a failed run.

## Implementation Decisions

- **Feature and home.** The feature is `testing-wave`, in the usual feature folder in the local tracker, with a spec, numbered tickets and a waves log. Findings live in their own folder inside it, one file per Finding, numbered. Per-run evidence (console log, screenshots, RevenueCat and database extracts) lives in a runs folder, one subfolder per ticket run.
- **Runner.** Waves are opened, run and closed by the existing `/implement-lee` machinery: worktrees, simulator claims, merging Patrol flows in ticket order. A test ticket differs from a build ticket in two ways: it ends with Findings plus an optional Patrol flow rather than a feature change, and its criteria list the exact records it expects in RevenueCat and the dev database before the run starts.
- **Parallelism for this feature.** Two tickets at a time, which overrides the general pool of three. One build at a time under a build lock. No full unit-test run while a wave is live. Measured on 09-23: 18 GB machine, about 38% reclaimable. Two running simulator apps with their consoles fit; two concurrent builds do not.
- **Driving the app.** Agents use the mobile MCP to see and tap and fall back to idb for text entry. Each agent launches the dev flavor's debug build with `flutter run` on its claimed simulator and writes the console to its run folder. Every error or exception line becomes a Finding or is noted as known noise.
- **Checking the other systems.** RevenueCat through its v2 API or the RevenueCat MCP, using the secret key already in the secrets folder. The dev database through read-only SQL over the Management API. Edge-function logs for the functions the scenario touched. A browser, through Chrome or computer use, only for something the APIs cannot show, and for App Store Connect in the iPhone sandbox ticket. Nothing writes to prod.
- **Purchases.** On a simulator the dev debug build buys through RevenueCat's Test Store, which is free and instant and has no Apple or Google record. Apple's sandbox is covered by one ready-for-human ticket on Lee's iPhone, with an agent checking.
- **Cancellation rule.** Adopted from the paywall spec, not re-decided: access stays open until the entitlement's end date, then the account is Lapsed. A Lapsed account can sign in and sees its data read-only with the plan-ended bar; edits and AI actions open the paywall sheet. Tests check against this rule and raise an SSOT-conflict Finding if the app disagrees.
- **Findings, not fixes.** No agent fixes anything during a Testing wave, simple or complex. Every problem is a Finding. A Finding stops its ticket only when it makes the rest of the scenario meaningless. The delete-account ticket is a hard stop on failure.
- **Finding shape.** Each Finding records: kind (`bug`, `ssot-conflict`, `followup-test`, `idea`), status (`open`, `triaged`, `fixing`, `closed`, `wontfix`), source ticket and run, screen, steps, expected, actual, evidence links, and for SSOT conflicts the decision id and its quoted text. A script builds the index from the files, grouped by kind and status, and reports whether the loop's exit condition holds.
- **Triage.** In the terminal with Lee after each Testing wave. SSOT conflicts become cards in the feature's decisions file through the existing path, and the newest ruling wins. Bugs become fix tickets in this feature's tracker. Lee picks up to ten Follow-up tests for the next retest wave. Findings are closed only by a retest that passes.
- **Look-around step.** Every ticket's instructions include, per screen visited, a short pass for other paths through the screen and other ways it could break. Each result is a Follow-up test Finding. This is how the scenario list grows between rounds.
- **Accounts.** New accounts sign up at plus addresses on Lee's work mailbox, named by ticket and run time. Codes are read from that mailbox through the Gmail tool. The first harness ticket proves one plus-address code arrives; if not, the fallback is the plain work address, deleted and recreated. Every account created is appended to the credentials file with its state. Agents delete their account through the app at the end of each run. A sweep script deletes any leftover plus-address test accounts on dev.
- **Credentials.** One credentials file in the gitignored secrets folder holds the dev admin (test@test.com), Lee's Kroger shopper login, Apple sandbox testers, and every test account. Agents type these passwords themselves. This departs from the QA repo's rule that Claude never enters a password; it applies to this repo only and the QA repo's skill is unchanged.
- **Cost caps per wave.** At most three new Vana plans and at most five AI logging calls across all agents. A counter in the harness enforces both; an agent that would exceed a cap records a Follow-up test instead of running the step. Every other planning test reuses existing plans on the dev accounts.
- **Kroger.** Runs against Kroger's certification environment with Lee's shopper login. The agent tries the system sign-in sheet through the MCP first, then through Patrol's native layer, and records where it stops. Lee finishes by hand only if both fail.
- **Ticket order.** Harness first: credentials file, Finding template, index, cost counters, build lock, sweep, and the plus-address check. Next come the Patrol audit and the delete-account scenario. Signup and the paywall line follow, since each needs a clean account. Planning, shopping, logging and smoke can run alongside the paywall line. The iPhone sandbox ticket is ready-for-human.
- **Initial scenario list.** Harness (2), Paywall (11), Meal planning (5), Shopping (5), Meal logging (5), Smoke (3), as grilled on 09-23. Tickets split further where a scenario turns out to be more than one. The list grows through Follow-up tests every round.

## Testing Decisions

- **What a good test is here.** It exercises the app the way an athlete would and checks outcomes that can be seen from outside: what the screen shows, what RevenueCat holds, what the dev database holds, and what the console printed. It never checks how the app is built inside. Each ticket writes its expected external records down before the run, so a pass or fail is judged against something fixed in advance.
- **Seam 1: the real app on a simulator against dev.** Nothing is faked. Agents drive it through the MCP and check RevenueCat, the database and the console from outside. Every scenario ticket enters here.
- **Seam 2: Patrol flows through the existing flow launcher.** The same real app and dev backend, driven from inside. New flows join the existing ones and the self-hosted runner's list. Prior art: the pro-gate flow and the onboarding signup flow, both touched on 09-22, and the database probe helper.
- **Seam 3: the harness scripts.** The Finding index, the cost counters, the build lock, and the account sweep each get a Node test fed with hand-written Finding files and fake inputs. Prior art: the decision page's sync script and its tests. This seam tests the scripts only, never the app.
- **No new Dart unit or widget seam.** Fixes that come out of triage are separate fix tickets and use the repo's normal seams, including the rule that every controller write path gets a seam test through the real notifier.
- **Patrol stays deterministic.** Scenarios whose outcome depends on model output are agent-only; Patrol covers only their stable edges (opening the chat, confirming a plan, opening a list).

## Out of Scope

- Prod. No test touches the prod project, prod RevenueCat, or prod `app_config`.
- Fixing bugs during a Testing wave. Fixes happen only in fix waves after triage.
- Android. Simulators here are iOS. Android can be a later round.
- The web coach app.
- Load or performance testing.
- Paywall tickets 05 and 13, which wait for Lee's go on prod.
- Changing the QA repo or its skills.
- Adding a new Codemagic workflow. Patrol runs locally or on the self-hosted runner.

## Further Notes

- The work is meant to repeat. Each round is expected to produce new Follow-up tests and new Findings, and the spec's scenario list is a starting point, not the full set.
- The old bug lists in the test docs (last edited July and August) are superseded by the Findings folder; the Patrol audit ticket marks them as such.
- Memory, measured 09-23: Brave, idle Claude sessions and editor extensions held most of the RAM. Closing them before a wave gives the two simulators headroom.
- Open unknowns the first tickets answer: whether Test Store purchases reach the dev webhook, whether a Test Store subscription can be cancelled, whether plus addresses deliver codes, whether the Kroger sign-in sheet can be driven, and whether barcode logging works on a simulator.
