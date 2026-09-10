# 06: Send once, hand off once

**What to build:** One tap puts the matched items in the shopper's Kroger cart, marked for
delivery, and takes them to Kroger to finish. They do not sign in a second time.

Kroger's cart is add-only: Mealvana cannot read it, confirm a send, or undo one. So the draft
records that it has been sent, the send action is unavailable afterwards, and sending again
requires an explicit confirmation that states plainly what a second send does.

The OAuth step stops requesting an ephemeral browser session, so the sign-in the shopper already
completed is shared with the system browser. The Hand-off then opens the Kroger app if it is
installed, or the system browser where they are already signed in. Mealvana does not embed
Kroger's site and handles no payment.

**Blocked by:** 05

**Status:** built, awaiting device verification (2026-09-10)

- [x] Sending puts every matched line in the Kroger cart tagged for delivery
- [x] A sent draft cannot be sent again without an explicit confirmation
- [x] The confirmation states what sending again will do to the cart
- [x] OAuth no longer requests an ephemeral session
- [x] A shopper who signed in during OAuth is not asked to sign in again at the Hand-off
- [x] The Hand-off opens the Kroger app when installed, otherwise the system browser
- [x] Mealvana never embeds Kroger's site and never handles payment
- [ ] Verified on a real device end to end, against a real Kroger account

Notes for whoever picks up 07, and for the device pass:

- `ready` split three ways. `reviewed` is "what the shopper approved is fit to send"; `ready` is
  `reviewed && !exported`; `resendable` is `reviewed && sent`. The send-again button is the only
  thing that sets `resend: true` on the export body — the one thing that gets past the server's
  existing receipt. A repeated tap, a retried request and a reloaded screen all arrive without it.
- A resend takes the previous receipt row over in place rather than deleting it — claimed by the
  id and status that were read, so `unique(user_id, plan_id, environment)` holds and there is never
  a moment with no durable row. What the first send added stays in the cart; Kroger has no way to
  take it out, and `kroger.send_again_confirm` says exactly that.
- **Only an acknowledged send can be sent again.** A `sending` receipt may still be in flight and
  an `unknown` one cannot say what reached the cart, so `resendable` is `reviewed && sent` and
  neither the button nor the server will act on the other two. That is what keeps `kroger.unknown`
  ("Mealvana will not resend this batch") true, and it is what stopped the first cut of this from
  deleting an ambiguous receipt — the thing `docs/kroger/IMPLEMENTATION.md` has always said never
  to do. Both review axes caught it independently.
- `kroger.send_confirm` lost "Each meal plan can be sent once", which stopped being true here.
- The Hand-off is `externalNonBrowserApplication` first (the Kroger app, via its app link), then
  `externalApplication` (the system browser). Android already queries `VIEW https` in its
  manifest, so nothing was needed there; iOS universal links need nothing either.
- It runs automatically after a `sent` receipt and is gated on `environment == 'production'`:
  certification's cart is not the one at kroger.com. A launch that fails says nothing — the items
  are in the cart either way, and the button stays for another try.
- `krogerAuthOptions` exists so the ephemeral-session decision is a value a test can assert
  rather than an argument buried in a provider. Turning it back on turns that test red.
- **A deliberate deviation from the spec's Testing Decisions**, which said no new seam is
  introduced: `krogerLauncherProvider` is one. The old code called `launchUrl` directly, so
  "which launch mode was tried, in what order" had nowhere to be asserted from. It follows the
  shape `krogerBrowserProvider` already set.
- **Not verified on a device.** The cart write has still never been proven against a real Kroger
  account (spec, Further Notes), and neither has the claim that the OAuth sign-in carries into
  Safari. Both need the production environment; both are one device pass.
