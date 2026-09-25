# Ticket 22 stopped

- Finding: `22-001-lee-s-kroger-shopper-login-is-refused-by-the-certification-s.md`
- Why: dev now runs Kroger certification (screen line and `login-stage.kroger.com` confirm it), but the certification sign-in refuses Lee's shopper login (twice). With no certification connection there is nothing to send to, and the lead's instruction for ticket 22 was to stop on a refused certification sign-in. No Match, no Send, no store set.
- Resume from: the reconnect step (Connect Kroger on certification with a shopper account certification knows), then criterion 3 (match every line, record matches) and the send. 22-004 lists a way to run matching before a connection exists. Criterion 4 (hand-off opens the cart) needs production and Lee's say-so (22-002).
