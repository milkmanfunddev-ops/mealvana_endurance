type: intake
status: unstamped
raised: 2026-09-11 (app coding agent, data-integrations@v1 implementation)

# Findings surfaced while implementing data-integrations@v1

Four observations that need a spec-side look; none block the bundle.

1. **FS/TP intensity z-pcts may not flow at all.** `performance-data.md` P-2
   marks `intensity_z1_z2/z3_z4/z5` "live but partial (TP + FS transformers
   only)", citing transformer lines that populate the TransformResult — but
   the sync services consume only `result.activity`, and neither transformer
   sets `intensityDistribution` on the Activity it builds. If confirmed, the
   engine's F3 zone path always falls back to 70/20/10 for provider
   workouts. Wiring it is a BEHAVIOR change to engine inputs — needs its own
   ruling/vector before fixing (same class as F4a).

2. **`_classifyIntensity` zones refinement has no ratified formula.**
   Q-INT19's consumption half shipped for FTP/CSS display + prefill; the
   "use athlete zones in intensity classification" half (the mapper's "we
   could refine" branches) has no pinned math, so it was NOT implemented.
   Needs a formula ruling (or strike it).

3. **Fingerprint unification (M-6.6) remains.** The matcher tier is now the
   single decision engine for Garmin/keyed matching, but change-detection's
   brick fingerprint and the repository cross-origin dedup still carry their
   own "same session?" keys. Unifying them under one definition is a
   refactor with behavioral edges — propose contracts first.

4. **Capture item 10 (races), FS half.** TP is done (events + Goals[] →
   goalTime prefill already wired). The FS long-horizon race-only scan
   (≤12 mo, chunked, daily clock) stays GATED on the §7 probes (FS
   date-range server cap + 404-fallback). TP `/events/next` horizon check
   likewise a §7 probe. Both on Xuan.

5. **Stage E sim walk (2026-09-11 evening) — four seams the suites missed,
   all fixed + pinned same day (app commit 3e5d11db):**
   (a) Q-INT2 hidden filter existed only on `getAllActivities`; the
   timeline/calendar date-range path and the engine-adjacent reads
   (recent-completed baseline, eaten-today fuel watch) still surfaced
   soft-hidden rows. Lesson for the spec: Q-INT2 says "leaves display and
   the engine" — conformance should enumerate the read paths, not a single
   query. Now pinned through the REAL repository.
   (b) `IntegrationProviderCard` carried two legacy disconnect dialogs that
   stacked in front of the ruled hide-vs-delete dialog (contradictory copy:
   "removes" vs "hidden"). Confirmation is now solely the screen's.
   (c) The D-2 FTP/CSS provenance row was composed on
   `SportSettingsScreen`, which the settings hub does NOT route to (it
   routes to the onboarding-reuse detail screens). Same single component
   now composed on the routed screens; new `sport_details_live_surface_test`
   pins the LIVE surface. Lesson: a golden pins the component, not the
   route — surface conformance needs a routed-screen assertion.
   (d) `EventsService._mapToEventDomain` (a second mapper beside the
   repository's) dropped `origin` — every event card rendered legacy.
   Mapped + pinned through the real service. Lesson: D-2c's "one origin per
   row" needs a mapper-survival vector wherever a parallel mapper exists.

6. **Pre-existing, filed to ops/data/bug-reports 2026-09-11 (not fixed in
   this bundle):** FTP/CSS/gear sport prefs NEVER persist locally (UserDao
   drops them; no local columns — caps D-2 manual-wins durability and the
   tap-to-adopt affordance; needs a schema decision); settings-mode
   cycling/swimming screens overflow at 390 pt; events list buckets on
   `start_time` and silently skips rows carrying only `event_date`.

7. **§7 probes run 2026-09-13 (live, Xuan's dev FS token + client-id):**
   (a) FS completion signals are UNREACHABLE, now by evidence: date-range
   `/API/v1/Workouts` and by-key `/API/v1/Workout/{key}` both 404 (bare IIS
   page) for our tenant while UpcomingWorkouts works — past workouts cannot
   be fetched at all, so a completion could only ever be seen same-day.
   FS-2.1 upgraded from "never observed" to "structurally unobservable";
   t3 rebind executor stays unwired on evidence. Spec impact: any M-row
   contemplating FS completion input should be marked N/A-by-provider.
   (b) Q-INT27: the 404-fallback (UpcomingWorkouts) is the permanent FS
   path for our tenant. NumDays up to 365 and NumWorkouts 99 are accepted
   Success:true — the documented 1–21 caps do not error; silent clamp at
   21 days indeterminate until a planned workout sits >21d out on the
   calendar. 14→28d widening = no error risk, residual clamp risk only.
   (c) TP refresh tokens expire in ≤ ~3 weeks (all dev tokens dead, newest
   22 days; prod+sandbox oauth both return invalid_request, identical to a
   garbage token — TP conflates invalid_grant into invalid_request, so the
   client cannot distinguish "re-auth needed" from "malformed request" by
   error code alone). /events/next horizon probe blocked until a fresh
   connect exists.

8. **Q-INT27 RESOLVED by live bisection (2026-09-13, Xuan dragging one test
   workout while the probe watched):** Final Surge's UpcomingWorkouts is
   server-capped at today + 14 days (15 calendar days counting today as
   day 1). 14-days-out returns (with the off-by-one: a workout N days out
   needs NumDays >= N+1); 15-days-out never returns, even at NumDays=365.
   Propagation is instant, so the cap is real. The documented NumDays 1-21
   range is not honored (silent truncation, no error). RULING REQUEST:
   close Q-INT27 as moot — the shipped 14-day FS window already equals the
   provider ceiling; the 14->28 widening buys nothing and should not ship.
   Doc fix: api-exploration final-surge/endpoints.md "NumDays 1-21" needs
   the observed-cap correction.

9. **Probe B run 2026-09-13 (Lee's TP sandbox account, fresh connect):**
   /v2/events/next horizon >= 34 days observed (next event 2026-10-17
   returned, Goals[] populated); events:read and zones are NOT
   premium-gated (IsPremium=false throughout); /v2/metrics correctly
   absent for non-premium. Combined with the client's 90-day day-scan,
   races <= 90 days out are reliably discoverable; only the beyond-90d
   case still rests on /events/next alone (exact bound unmeasured — needs
   an account whose only event is far out). BUG found live and filed to
   ops (Major, pre-existing): the coordinator/background sync path
   computes the TP eventResult and discards it — races import only via
   manual Sync Now or the connect flow; the only save site is in the
   presentation controller (FOA violation doubling as the root cause).

10. **Background event-drop bug FIXED in-bundle (app 5ee1e318, Xuan's
    direction):** provider-event persistence extracted to the application
    layer (ProviderEventImportService — one save site, dedupe + D-2c rules
    for TP events AND FS race candidates); coordinator now persists what it
    fetches and refreshes events providers. Pinned by a real-repo service
    test and a coordinator wiring test; live-verified via background-only
    re-import on the sim. Spec note: D-2c conformance should include a
    background-path vector, not just the manual-sync path.

11. **Xuan smoke-test ruling 2026-09-13 (implemented, app 43a2b617) — SPEC
    ADDENDUM REQUESTED:** "every data field a provider also carries shows
    its badge" extends ratified D-2 beyond FTP/CSS + D-2b + events:
    (a) body-comp weight gains a TrainingPeaks tap-to-use fallback when
    Garmin has no reading (Garmin remains the D-2b primary — precedence
    should be ratified); (b) Profile & Preferences name/gender/birthday
    gain DIFF-ONLY TP badges (identity fields stay manual-owned; agreement
    renders nothing — this "diff-only" treatment differs from D-2's
    always-chip treatment and should be ratified); (c) OPEN RULING: TP
    birthday is month-precision ("YYYY-MM") — adopt currently keeps the
    manually-set day (or the 15th); day-level semantics need a call.
    Provider facts for the spec: TP basic profile carries NO height, and
    body fat only via the premium /v2/metrics. Also ratified-design nit
    fixed: the TP write-back toggle now renders INSIDE the connected card.
    FTP/CSS chips were confirmed working (smoke test had hit the
    hung-initial-sync window).

12. **Design amendment (Xuan, 2026-09-13, app 1f281a4a):** the tap-to-use
    affordance renders inside the same pill outline as the source chip
    (electrolyte border, radius 100) instead of bare text. Fold into the
    source-chip spec stub + the ftp-source-provenance rendering when the
    addendum from item 11 is ratified; conflict goldens re-pinned.

13. **Multi-source provenance ruling (Xuan, 2026-09-13, app 906fcb3d) —
    SPEC ADDENDUM:** badges are PRESENCE-based, not exclusive — every
    provider with a non-null value shows its badge (primary first), rather
    than the primary suppressing the secondary. Applies to weight
    (Garmin + TP both show) and name (TP + FS both show). A provider value
    equal to manual renders the plain source pill; a differing one renders
    tap-to-use. Provider-coverage fact for the spec: per
    api-exploration/athlete-profile-fields.md, Final Surge carries ONLY
    name among identity/body fields — so name is the sole field with a
    real 3-way manual/TP/FS collision; everything else stays TP-or-Garmin.
    Fold into the D-2 addendum from item 11.

14. **Hub-refresh bug fixed (app 906fcb3d):** cycling/swimming detail
    screens save via the onboarding controller and never invalidated
    settings state, so the Sport Preferences hub summary ("FTP: NNNW")
    showed stale values until a full reload. Both save paths now invalidate
    settingsControllerProvider. Not integration-specific but surfaced by
    the D-2 adopt flow. Also confirmed: the adopt→save→persist loop is
    clobber-free (sentinel FTP held through a 2-min poll; nothing
    reasserts an old value).

15. **Gender/birthday pill persistence (Xuan, 2026-09-13, app 649e5cb9):**
    applying the TP birthday/gender badge hid the pill (builders returned
    empty on value-match, which is the post-adopt state). Now mirror the
    name badge — match renders the plain source pill, differ renders
    tap-to-use. Verified: adopt Jun 1985 → field 6/5/1985 → persistent
    "TrainingPeaks" source pill → persists to DB on Save.

16. **Page-prior refresh (Sport Preferences hub) RE-VERIFIED 2026-09-13 in
    the current build (906fcb3d): baseline 250W → adopt TP 220 on Cycling
    Details → Save → DB=220 AND hub shows "FTP: 220W" both immediately and
    on fresh re-navigation. The settingsControllerProvider invalidation on
    the cycling/swimming save paths is present and working. If the flagged
    staleness persists it is on a build lacking these unpushed commits, or
    a different "page-prior" surface — pending Xuan's confirmation of which.

17. **Running water-bottle NOT SAVED (fixed in-bundle, app 5e7156af) — the
    actual cause behind the "hub doesn't update after editing running"
    report:** saveSportPreferences never threaded runsWithWaterBottle, so
    the settings-mode running toggle was silently dropped (DAO/column
    already supported it). Threaded through all three save layers +
    RunningDetails now invalidates settings state. Filed to ops
    (2026-09-13-running-water-bottle-edit-not-saved, Major). Note: running
    giSensitivity is derived as the inverse of the water-bottle toggle
    (legacy coupling) — flagged for a separate review.

18. **Fresh-brick ungroup data loss FIXED in-bundle (app 9d39a85c, Xuan's
    direction):** ungrouping a brick built in the creator (inline segments,
    no standalone leg rows) tombstoned it and restored nothing — both legs
    lost. ungroupBrick now decomposes inline segments into standalone
    planned activities (inverse of brick creation) when there are no
    archived legs. Pre-existing brick gap, unrelated to integrations;
    folded in at Xuan's request. Pinned + live-verified. Note: the brick
    action menu already distinguishes "Ungroup legs" from "Delete brick",
    so the destructive path remains available explicitly.

19. **Onboarding provenance pills + Garmin primer implemented (app a6f20390):**
    (a) D-2 KyleSourceChip pills now appear on the onboarding Personal Info
    (Name/Email, Gender, Birth year) and Body Composition (Weight) pages when
    a connected platform pre-fills them — replacing the old _AutofillNotice
    text and the Garmin-specific weight badge, matching Settings. This is a
    NEW application of D-2 (onboarding surface) — register it in the D-2
    surface spec / design-sync alongside item 11's addendum.
    (b) Garmin "Historical Data" primer sheet, onboarding-only (gated on
    ConnectedAppsScreen.isOnboarding), shown before Garmin OAuth to prime the
    default-off toggle. Design came from Claude Design; copy tightened for
    glanceability. No settings/post-connect variant (insight is
    onboarding-only, per Xuan 2026-09-13). Both pinned by tests. DESIGN-SYNC
    + D-2 spec addendum still pending ratification.
