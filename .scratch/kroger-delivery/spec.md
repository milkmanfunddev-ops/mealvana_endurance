# Shop with Kroger: delivery-first

Status: ready-for-agent
Created: 2026-09-09

## Problem Statement

A shopper in Birmingham, Alabama connects their Kroger account, opens Shop with Kroger, and the
feature is inert. It hands them a facility called "Kroger - - Birmingham Spoke" and tells them
they are collecting their groceries there. Tapping "Find product matches" produces a cheerful
"Matches are suggestions" message and changes nothing: every ingredient still reads "Choose a
product", and every "Choose product" button opens nothing.

There is no Kroger in Birmingham. There is a Spoke, and a Spoke only delivers. The draft defaults
to `PICKUP`, the server turns `PICKUP` into Kroger's curbside filter, and a Spoke has no curbside
catalog — so every search returns zero results, every line is skipped, and the run reports
success. This was confirmed against Kroger's production API: the same query at the same Location
returns 0 results under the curbside filter and 5 under the delivery filter, for every term tried.

Three problems sit on top of that one:

- The shopper is asked to choose a Location at all. They do not think in Locations; they think
  "deliver this to me". Being handed a warehouse and told to drive to it is the feature getting
  its own domain wrong in front of them.
- The screen never tells the truth about failure. A Pro-gated shopper, a rate-limited shopper and
  a misconfigured server all see the same words: "Kroger shopping is being set up."
- The screen does not look like Mealvana. It is pushed outside the app shell, so it has none of
  the app's chrome, and it is built almost entirely from raw Material widgets.

## Solution

Modality is the shopper's intent and comes first. Location is an API parameter they never see.

The shopper opens their shopping list and taps Shop with Kroger. The screen says "Delivery to
35209". There is no Location to choose, no address, no pickup-or-delivery segmented control on the
critical path. One tap matches their ingredients against the delivery catalogue. They see what
matched — each ingredient beside the real Kroger product name — and what did not. One tap sends
the matches to their Kroger cart, tagged for delivery. Kroger then opens in the Kroger app, or in
Safari where they are already signed in, and they add the few things Mealvana missed, choose a
delivery slot and pay. That is the Hand-off; Mealvana's involvement ends there.

Where Kroger cannot deliver, the feature does not appear at all. Coverage is answerable with an
app-level token, before the shopper is asked to connect anything.

The shopper signs in to Kroger exactly once, during the existing OAuth step.

## User Stories

1. As a shopper in a delivery-only market, I want Shop with Kroger to find products that actually
   exist for me, so that the feature does something at all.
2. As a shopper, I want the app to assume delivery, so that I am not asked to pick a shop I cannot
   visit.
3. As a shopper, I never want to see a Location list, so that I am not asked to make a choice I do
   not understand and did not ask for.
4. As a shopper, I want the screen to say where my groceries are going ("Delivery to 35209"), so
   that I can tell at a glance the app understood where I am.
5. As a shopper, I want my delivery area determined from my device's location, so that the common
   case costs me nothing.
6. As a shopper who declines location permission, I want to type my postcode once, so that
   refusing a permission does not lock me out of the feature.
7. As a shopper who has moved or is travelling, I want to change my delivery area, so that I can
   shop for where I actually am.
8. As a shopper, I want Mealvana never to store my coordinates or my postcode for Kroger purposes,
   so that using the feature does not mean being tracked.
9. As a shopper in an area Kroger does not serve, I want Shop with Kroger not to be offered, so
   that I am not sold a feature I cannot use.
10. As a shopper in an area Kroger does not serve, I want to learn that before I connect my Kroger
    account, so that I do not authorize an app for nothing.
11. As a shopper, I want to sign in to Kroger once, so that the integration does not feel like a
    chore.
12. As a shopper, I want the Kroger sign-in I already completed to carry over to Kroger's website,
    so that the Hand-off does not ask me to sign in a second time.
13. As a shopper, I want one tap to match my whole list, so that I do not have to search for
    fifteen ingredients by hand.
14. As a shopper, I want to see which real Kroger product each ingredient matched to, so that I can
    catch a bad match before it reaches my cart.
15. As a shopper, I want the ingredients that could not be matched listed plainly, so that I know
    what I still have to add myself.
16. As a shopper, I want to be told when a matching run matched nothing, so that the app never
    congratulates itself for doing nothing.
17. As a shopper who has already ticked items off my list, I want those skipped, so that I am not
    sent things I already own.
18. As a shopper whose entire list is already ticked, I want to be told that nothing was selected,
    so that an empty run is distinguishable from a failed one.
19. As a shopper, I want to correct a single bad match, so that one wrong product does not spoil
    the whole order.
20. As a shopper, I want to remove an ingredient from the Kroger order entirely, so that I keep
    control over what gets bought.
21. As a shopper, I want to adjust how many packages of something I am buying, so that I get the
    quantity I actually need.
22. As a shopper, I want one tap to send the matched items to my Kroger cart, so that the whole
    exercise takes seconds.
23. As a shopper, I want my items to arrive in Kroger's cart already marked for delivery, so that
    Kroger's own checkout starts from the right assumption.
24. As a shopper, I want the app to stop me sending the same list twice, so that I do not end up
    with two weeks of groceries.
25. As a shopper who genuinely wants to send again, I want to be able to, after being told what
    that means, so that a safety guard is not a dead end.
26. As a shopper, I want to be taken to Kroger once my items are sent, so that I can finish the
    order without hunting for it.
27. As a shopper with the Kroger app installed, I want the Hand-off to open that app, so that I am
    already signed in and my cart is waiting.
28. As a shopper, I want Mealvana to stay out of payment entirely, so that I am buying from Kroger
    and know it.
29. As a shopper, I want my unmatched ingredients still visible in Mealvana when I come back, so
    that I can work through them while I shop on Kroger's site.
30. As a shopper in a delivery-only market, I do not want to see prices Kroger will not give,
    so that I am not shown blanks or invented numbers.
31. As a shopper, I want to understand why prices are missing if I wonder, so that their absence
    reads as a fact about Kroger rather than a bug in Mealvana.
32. As a shopper without Pro, I want to be told this needs Pro, so that I know what to do about it.
33. As a shopper hitting Kroger's rate limit, I want to be told to try later, so that I do not think
    the feature is broken.
34. As a shopper whose Kroger authorization has expired, I want to be asked to reconnect, so that a
    recoverable state is recoverable.
35. As a shopper, I never want a failure explained as "Kroger shopping is being set up" unless that
    is genuinely what happened, so that the app does not lie to me about its own state.
36. As a shopper, I want buttons that do nothing to not be shown, so that I am not left tapping a
    dead control.
37. As a shopper, I want every button to be labelled with what it does rather than with an error
    message, so that I can tell an action from a refusal.
38. As a shopper, I want Shop with Kroger to look like the rest of Mealvana, so that it does not
    feel like a different app bolted on.
39. As a shopper, I want the screen to keep the app's normal navigation, so that I am not stranded
    on a page with only a back arrow.
40. As a shopper, I want product names shown exactly as Kroger supplies them, so that what I approve
    is what I get.
41. As a screen-reader user, I want every control labelled, so that the feature is usable without
    sight.
42. As a developer, I want the delivery/pickup mapping proven against real Kroger payloads, so that
    this class of bug cannot return silently.
43. As a developer, I want a failing matching run to be visible in tests, so that "reported success,
    did nothing" is caught before a device does.
44. As a developer, I want to know whether a Location can be trusted about its own fulfillment, so
    that availability is derived from something true.
45. As Mealvana, we want to comply with Kroger's branding and data terms, so that the integration
    survives review.

## Implementation Decisions

### Modality determines Location, not the reverse

`DELIVERY` is the default Modality for a new draft. The Location is resolved from the shopper's
area and the Modality together, and is never presented as a choice. Pickup remains representable
in the model and on the wire, but is not on the critical path in this spec; a Location that cannot
serve the requested Modality must never be selected.

The screen presents the delivery area, not the Location: "Delivery to 35209". The Location's name
and address do not appear.

### Area resolution

The delivery area comes from the existing shared location service on first use, with a typed
postcode as the fallback when permission is refused or resolution fails, and as the manual
correction path. Mealvana persists the resolved Location on the draft. It does not persist the
shopper's coordinates or postcode for Kroger purposes: Kroger's acceptable-use terms for the
Locations API prohibit storing data about a customer's location.

### Coverage gates the feature

Coverage is checked with the app-level token before any shopper authorization. Where no Location
serves the area at `DELIVERY`, the entry point into Shop with Kroger is not shown.

### Catalog reads move to the application token

Location and product reads move from the customer's token to `client_credentials`. Kroger requires
no scope for Locations and only `product.compact` for Products; only cart writes require the
customer. This is what makes the coverage check possible before authorization, and it removes the
dependency that has kept the feature untested — Kroger's certification environment is unreachable
outside their network, so customer OAuth can only be exercised against production.

The customer token remains required for the cart write, and for nothing else.

### Fulfillment mapping and availability

The server maps Modality to Kroger's fulfillment filter: `DELIVERY` to delivery-to-home, `PICKUP`
to curbside. Availability is derived from whether the filtered search returned the product, not
from the per-item fulfillment booleans in the payload. Those booleans are not Location-truthful: a
Spoke returns `curbside: true` on items for which the curbside filter returns nothing at all.

### Price is optional data

A Location may return no price for any product. This is normal for a Spoke and is not an error
state. Price is absent, never zero and never invented. The cost estimate is removed from the
delivery experience rather than shown as a column of unknowns, and a price from a different
Location is never substituted — Kroger's terms forbid altering returned data and forbid
comparative price analysis.

### Matching and the review step

One action matches every list line that is neither ticked nor excluded, taking the top-ranked
candidate for each. The outcome is reported honestly:

- lines matched, presented as ingredient beside the Kroger product name and package size
- lines with no match, listed plainly
- a run in which nothing was eligible reports that nothing was selected, and is distinguishable
  from a run in which nothing matched

Per-line correction — choose a different product, change quantity, exclude — remains available but
is no longer the primary path.

### Sending, and the write-only cart

Kroger's public cart API is add-only: no read, no delete, no quantity replacement. Mealvana cannot
observe the cart, confirm a send, or undo one. The draft therefore records that it has been sent,
the send action is unavailable afterwards, and sending again requires an explicit confirmation
that states what a second send does.

Cart lines carry `DELIVERY`.

### Hand-off

After a successful send the shopper is taken to Kroger via the system browser or the installed
Kroger app. Mealvana does not embed Kroger's site, does not host checkout, and handles no payment.

The OAuth step stops requesting an ephemeral browser session, so that the shopper's Kroger sign-in
is shared with the system browser and the Hand-off does not require a second sign-in.

The unmatched-items list remains on the Mealvana screen after the Hand-off, so a shopper switching
back has it waiting.

### Failure reporting

The state's message must survive every state transition, including the initial load. Today the
copy-with drops it, so every first-load failure — Pro required, rate limited, reconnect required,
not configured — renders as "Kroger shopping is being set up". Each distinct cause gets its
distinct message, and the existing unused content keys for these cases are used.

Controls that cannot act are not rendered, rather than rendered disabled and silent. No control is
labelled with error copy.

### Content keys

Kroger's content keys are declared in the shared content key registry like every other feature,
rather than interpolated from bare strings at call sites. The pattern of comparing a returned
value against its own key as a way of detecting a missing key is removed.

### Design

The screen is presented inside the app shell rather than pushed outside it, and is rebuilt from
the existing design-system components — buttons, cards, quantity control, segmented control, input
field — with sheets using the glass sheet surface and scrim, and typography from the token
registry. No new component is invented for this screen; where the design system lacks something,
that gap is raised rather than filled locally.

Kroger appears only as the integration logo, never the primary Kroger mark: Kroger licenses the
primary logo for add-to-cart use only when the integration is not monetized, and this feature sits
behind Pro. Product names, descriptions and prices are displayed exactly as returned, and product
images are shown uncropped with no overlays.

## Testing Decisions

A good test here asserts what a shopper experiences — what the screen offers, what it says when
something fails, what reaches the cart — and never how the controller reaches that state.

Three seams, all of which already exist. No new seam is introduced.

**The controller through the real notifier**, with the existing fake remote standing in for the
edge function. This is the primary seam and carries most of the coverage: delivery is the default
and no Location is offered; coverage-zero hides the feature; a run that matched nothing says so;
a run with nothing eligible says something different; each failure cause produces its own message
and survives the initial load; the send guard prevents a second send and the confirmation lifts it.
Prior art: the existing Kroger flow and repository tests, and the seeded-controller pattern used
by the hydration check controller test.

**The edge-function service**, with fetch doubles, in the existing Deno suite. Modality maps to the
correct fulfillment filter; availability follows the filtered result and not the per-item
fulfillment booleans; a product with no price round-trips as absent rather than zero; catalog
reads use the application token and cart writes use the customer token.

**The screen**, as a widget test with goldens, following the meal-planning golden pattern.

Fixtures are producer-shaped, per the repo's seam rule at `docs/test/README.md` — "feed the seam
producer-shaped data, never the local engine's own output". Real Kroger production payloads
captured on 2026-09-08 replace the hand-written product fixture:

- a Spoke response: `inventory.stockLevel: HIGH`, `size: "1 ct"`, `fulfillment.curbside: true`,
  `fulfillment.delivery: true`, `fulfillment.inStore: false`, and **no `price` field**
- a Store response for the same item: the same item id, `size: "1 lb"`, `soldBy: "WEIGHT"`, and
  `price.regular: 2.19`
- a Locations response for a delivery-only market: exactly one Location, zero departments
- an empty Locations response, for the coverage-zero case

The current fixture — a hand-written product with a price and `available: true` — is the fixture
shape that hid this bug, and is replaced rather than extended.

The migration and secret-boundary tests stay as they are.

## Out of Scope

- **An in-app browser showing Kroger's site.** Considered at length and rejected: an embedded
  webview has its own cookie jar, so it would require a second Kroger sign-in, and its value —
  seeing the cart as Kroger holds it — is a confirmation rather than a correction. Revisit only if
  real use shows the miss rate is high enough to justify it.
- **Checkout, payment, delivery slots, order status.** Kroger's public API cannot place an order;
  their own documentation requires redirecting the shopper to Kroger to check out. Mealvana never
  sees an order.
- **Pickup as a first-class experience.** It stays representable and stays working; it is not
  designed for here.
- **Prices in delivery-only markets.** Not deferred — not available.
- **Any retailer other than Kroger.**
- **Rate-limit strategy.** Kroger's per-endpoint daily limits and the sequential per-line search
  are a known scaling concern, explicitly deferred.
- **Reading or modifying the Kroger cart.** Not offered by the public API.

## Further Notes

**OAuth status, corrected 2026-09-09.** `docs/kroger/DEPLOYMENT.md` records that no customer
OAuth had ever been completed. That is now out of date: it has been completed on iOS dev against
Kroger Production, evidenced by a device session showing a connected account and a resolved
Location — both of which require a customer token. Kroger's certification environment remains
unreachable outside their network, so production is the only place this can be exercised.

What remains unproven is the **cart write**: no items have ever reached a real Kroger cart from
this app. That is the one genuinely unknown step, and it should be attempted early rather than
discovered at the end. Android additionally needs its dev redirect URI registered with Kroger
before the flow will work there at all.

**Confirmed by probe, 2026-09-08**, against Kroger production with an application token: postcode
35209 returns exactly one Location, a Spoke with zero departments. The identical product query at
that Location returns 0 results under the curbside filter and 5 under the delivery filter, for
broccoli, cabbage and milk alike. The same item at a real Store returns a price; at the Spoke it
returns none.

**Untracked file.** A Kroger production document holding a live application id sits untracked
while its sibling documents are staged. Whether it belongs in the repository is a decision someone
should make deliberately.

**Vocabulary** for this work is defined in `CONTEXT.md`: Location, Spoke, Store, Modality,
Hand-off, Coverage, Match. The conflation of Spoke with Store is what produced this bug, and the
spec uses these words precisely.

**Sequencing.** Seven tickets in `issues/`, blockers first. Content keys are a prefactor because
every later ticket edits that copy. The delivery fix and honest failure reporting are one ticket:
neither is verifiable without the other. The application-token move runs in parallel with the
delivery fix rather than behind it — they touch the same server code but neither gates the other.
The design pass comes last, because until matching runs against a real Spoke nobody knows what the
screen has to display.

The cart write is proven by hand in ticket 02 rather than reached in ticket 06, because it is the
only genuinely unknown step and everything after it assumes it works.
