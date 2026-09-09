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

**Status:** ready-for-agent

- [ ] Sending puts every matched line in the Kroger cart tagged for delivery
- [ ] A sent draft cannot be sent again without an explicit confirmation
- [ ] The confirmation states what sending again will do to the cart
- [ ] OAuth no longer requests an ephemeral session
- [ ] A shopper who signed in during OAuth is not asked to sign in again at the Hand-off
- [ ] The Hand-off opens the Kroger app when installed, otherwise the system browser
- [ ] Mealvana never embeds Kroger's site and never handles payment
- [ ] Verified on a real device end to end, against a real Kroger account
