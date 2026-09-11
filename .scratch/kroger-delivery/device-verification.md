# Kroger delivery: device verification (step 5)

All seven tickets are built. Tickets 02, 03, 04, 06 and 07 are still waiting on device
verification, and one step has never been exercised on a real device: **the cart write**. This file
is the brief for that pass. Written 2026-09-10 so the context could be cleared.

## Launch

The repo's device skills (`verify-app`, `drive-device`, `device-sweep`) were retired to
`.claude/archive/skills/` and don't load. The recipe below comes from them.

- **Simulator:** iPhone 17 Pro, already booted, UDID `6A1CE0B5-9624-477F-9804-8489DE08AB01`.
- **Run:** `scripts/run_dev.sh -d 6A1CE0B5-9624-477F-9804-8489DE08AB01`, in the background (it is
  long-lived). **Never a bare `flutter run`.** Without `--target lib/main_dev.dart` the app loads
  `.env.prod.local`, and dev analytics go to the production Mixpanel project. `run_dev.sh` sets
  the flavor, the target and `IS_INTERNAL`.
- **Sign in: probably not needed, so look before doing anything.** On 2026-09-10 the dev app
  (`com.milkman.mealvanaendurance.dev`) was installed on this simulator and held a dev Supabase
  session (`sb-vlmtsdzpnjnavdgytcmi-auth-token`). `run_dev.sh` keeps app data, so it should open
  signed in. Only if it opens on the login screen, run `scripts/sim-dev-login.sh` yourself. It
  needs the permission rule `Bash(scripts/sim-dev-login.sh:*)`, which doesn't exist yet. Without
  it, ask Lee to add the rule or to type `! scripts/sim-dev-login.sh`. Don't type credentials with
  mobile-mcp: the password lives only in the Keychain, by design, so it never reaches the
  transcript.
- **Drive:** the mobile-mcp tools, all loaded in one ToolSearch call. Screenshots come back in
  pixels and taps go in points, so convert. Downscale a screenshot before reading it
  (`sips -Z 700`).
- **Reload:** `kill -USR1 <flutter pid>` hot-reloads; `-USR2` hot-restarts.

## Get to the screen

1. **Location.** Set the simulator to Homewood, AL 35209 (about 33.47, -86.80). That area is served
   only by the delivery-only Birmingham Spoke found in the 2026-09-08 probe, so it exercises the
   real bug this feature fixes. The screen confirms it by showing "Delivery to 35209".
2. **Food tab → Shopping.** Needs a confirmed meal plan. If the dev account has none, confirm one
   through Vana first.
3. **"Shop with Kroger"** appears above the list once Coverage is answered. It now opens
   `/food/kroger/<planId>` inside the Food tree (ticket 07).

## What to check

| Ticket | On the device |
|---|---|
| 07 | In-body round back button and title, no `AppBar`. Kyle buttons and cards. Postcode and confirm sheets are glass over a dark scrim. Product photos whole, not cropped. Light and dark. **Real fonts**: the goldens use the test font, so type has only been checked here. |
| 03 | The entry point shows **before** Kroger is connected. Coverage needs no customer login. |
| 04 | The area comes from the device, with no Location picker anywhere. "Change" asks only for a postcode. |
| 02 | Find product matches returns products at the Spoke: delivery-first, and no prices anywhere. |
| 06 | Send once. A `sent` receipt offers "Send these items again" behind a warning. Open Kroger cart hands off to kroger.com/cart. |

**Try to trigger the known defect.** Search a product for one line, then quickly for a second line.
`searchLineId` is written and never read (`kroger_controller.dart`), so the product sheet can show
the previous line's results. Not fixed yet. If it reproduces, file it and use `/diagnosing-bugs`.

## Stop gate: the cart write

**Ask Lee before tapping "Add approved items to Kroger cart".** The dev app talks to Kroger
**production**, since Kroger's certification environment can't be reached from outside their
network. Sending puts real items in Lee's real Kroger cart. Kroger's cart only accepts additions,
and Mealvana can't remove anything it sent.

**Check whether Kroger is already connected before assuming a sign-in.** The connection is stored
server-side against the Mealvana account, and customer OAuth has already been completed once on
iOS dev. The screen shows "Disconnect Kroger" when it is connected. Lee is needed only if it has
lapsed ("Connect Kroger" or a reconnect message): the Kroger sign-in uses his personal Kroger
password, which Claude doesn't have and mustn't type.

## Record the result

- Update each ticket's `**Status:**` line: verified on device, with the date, or the defect found.
- Keep screenshots as evidence. A self-report isn't verification.
- Stage only this feature's paths when committing. Other sessions share the working tree, and
  **never `git stash`** in this repo.

## Result of the 2026-09-10 pass (iPhone 17 Pro simulator, dev app, Kroger production)

Partial. Stopped early: a parallel Claude session ran `flutter run` on the same simulator at 20:19
and force-quit the app mid-check. The cart write was not attempted: that stop gate needs Lee.
Screenshots are in `evidence/2026-09-10/`.

**Found before any check could run: dev was on the pre-ticket-03 backend.** The dev `kroger`
function was v5, deployed 08:34 CDT, before tickets 03, 04 and 06 were committed. Setting a ZIP
returned 400 `invalid_action`, which the app shows as "Kroger could not be reached" (screenshot
03). Redeployed from HEAD with Lee's approval (now v6), and the 30 server tests pass. **Whoever ships
this must deploy `kroger` along with the app. Nothing checks that the two match.**

| Ticket | Result |
|---|---|
| 07 | Dark: in-body round back button and title, no AppBar; Kyle buttons and cards; ZIP and product sheets are glass over a dark scrim; product photos whole; real fonts render. Light: the screen renders on cream with white cards (screenshot 15). Sheets in light were **not** seen, because the app was killed first. |
| 03 | Entry point shows (screenshot 01). **Coverage never got an answer for this account**: the app calls `coverage` with no ZIP, the server falls back to `users.home_lat/lon`, which are null here, and returns 400 `invalid_zip`, so the answer is "unknown" and the entry point shows by default. "Shows before Kroger is connected" was **not** exercised: Kroger was already connected, and disconnecting needs Lee's Kroger password to reconnect. |
| 04 | Typed path verified: "Delivery to 35209", no Location name or address anywhere, and the draft stores the Location with no ZIP or coordinates (screenshot 05). **Device path fails: defect below.** "Change" was not tapped; "Set delivery area" opens the same postcode-only sheet. |
| 02 | Matching verified at the Birmingham Spoke under delivery: 11 of 13 lines matched with real products, no prices anywhere, and the price note shows. With no Location, the match and choose buttons are not drawn. An empty search says "No matching products found". Weak match worth knowing about: white beans became Bush's White *Chili* Beans. **Cart write not done** (stop gate). |
| 06 | **Cart write proven** (Lee approved; see below). After the send the review is read-only, "Open Kroger cart" shows, and "Send these items again" sits behind the warning, which says the cart only accepts additions and Mealvana cannot remove anything. Cancelling it sends nothing. The hand-off opened Safari (Kroger app not installed) at **login.kroger.com**, so the no-second-sign-in claim is untested: the account's OAuth predates ticket 06's non-ephemeral session. |
| `searchLineId` | Did not reproduce by hand. The body's `AbsorbPointer` serializes searches, so a second search can't start while the first is in flight. The stale-results path still exists in code: it needs `search()` to no-op on `busy` while another `_run` (the shopping-list listener, say) holds it. |

### Defects found

1. **Device location never resolves an area in most US places (ticket 04).** LocationIQ reverse
   returns `osm_type: null, osm_id: null` for address-point matches, and `location_iq` 1.1.4
   declares both as non-null `String`, so `LocationRepository.reverseGeocode` throws
   `type 'Null' is not a subtype of type 'String'` even though the response has
   `postcode: "35209"`. 4 of 6 US coordinates probed return the nulls (all three in Birmingham,
   plus Cincinnati). The Kroger area finder is the only caller. The shopper falls back to typing a
   postcode, on every load.
2. **A draft saved before ticket 02 can never deliver (tickets 02 and 04).** The draft on this
   simulator was `modality: PICKUP` with the Spoke from the old Location picker. `location` sends
   `draft.modality`, the server probes curbside (0 results) and answers "Kroger does not deliver
   to that ZIP code". Ticket 04 removed the Location picker, which was the only thing that ever
   reset the Modality, so nothing in the app can recover the draft. Pre-release data only. Worked
   around by rewriting the local draft to `DELIVERY` with no Location (backup kept in the session
   scratchpad), and the app uploaded it.
3. **Before a matching run, every line reads "Kroger's delivery catalogue has no match for these"**
   (screenshot 02). `unmatched` means "no product yet", so the note claims a search that has not
   happened.
4. **A failure that is not a `KrogerException` reads as "Kroger could not be reached"**, including
   a 400 `invalid_action`, which is our own version mismatch, not Kroger's.

### The cart write, 20:47 CDT

Lee approved it. To keep what reached his cart to a minimum, every matched line except Quinoa was
skipped and Quinoa set to one package. The stored draft was checked before sending: one line, UPC
0001111091238 (Simple Truth Organic Quinoa 16 oz) × 1, `DELIVERY`, store 540FC242. After
confirming, `kroger_exports` holds one row, `sent`, `production`, with exactly that payload.
`sent` is written only after Kroger answers 204 to `PUT /cart/add`. The send also refreshed the
customer token (`kroger_connections.updated_at` moved), so the refresh path works too.
Screenshots 16 to 22. **Still open: Lee to confirm the quinoa shows in his cart at kroger.com.**

### Left for the next pass
- Lee: confirm the item is in the Kroger cart; delete it there if unwanted.
- Ticket 06's "not asked to sign in again": disconnect, reconnect (Lee's Kroger password), send a
  new plan, and watch the hand-off.
- Ticket 03 before connecting, and a Coverage answer from a real area.
- Ticket 07: the product sheet in light (the confirm sheets were seen in light).
- Put the app theme back to **Dark** (Settings → Appearance). This pass set it to Light.
