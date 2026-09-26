# 118-002 · A network error during the TrainingPeaks token refresh overwrites requires_reauth with error: Reconnect disappears from Connected Apps until the next online sync

- kind: bug
- status: open
- ticket: 118
- run: w36-20260926T0031Z
- screen: Settings → Connected Apps (TrainingPeaks)
- decision: 

**Steps.**
1. Retest of 64-001's network leg. test@test.com, whose TrainingPeaks refresh the API refuses:
   server and local rows are `requires_reauth` "Token refresh refused. Please reconnect." after
   the sign-in sync (00:40:51Z); Connected Apps shows Reconnect.
2. `netcut.sh launch`, then `netcut.sh on --relaunch` (00:52:21Z): the app starts with its network
   cut and runs the integration sync.
3. Settings → Connected Apps while still offline. Read the app's local `integrations` rows
   (sqlite, read-only).
4. `netcut.sh off` (00:54:05Z); later relaunch online (00:56:31Z).

**Expected.**
Fix ticket 76: a network error during refresh is an ordinary, retryable error that never escapes
the sync, and a connection is never marked by mistake. A connection that already needs signing in
again keeps saying so: a network error tells nothing new about the token.

**Actual.**
The network error did not escape: the console shows "Token refresh failed: no answer
(ClientException with SocketException ... Network is unreachable)" and "Integration sync reported
failure for training_peaks", no unhandled exception. But the sync wrote the local row as
`last_sync_status = error`, `last_sync_error` = the raw exception text (address, port and URI
included), `needs_upload = 1`. Connected Apps then showed TrainingPeaks as a healthy connection:
Sync Now, "Last synced: 1 minute ago" and the "Write fuel plan to TrainingPeaks" switch on, no
Reconnect. V.O2 in the same sync kept Reconnect ("No internet connection" left its
`requires_reauth` alone). After the network came back the card still showed Sync Now (00:55Z); the
server row stayed `requires_reauth` (the deferred upload had not run), and only the next online
launch's refused refresh put the local row back to `requires_reauth`. Had the deferred upload run
first, the server would have held the raw exception as the athlete-facing error.

**Evidence.**
- runs/118/local-integrations-after-offline.txt: local rows after the offline sync (tokens not read).
- runs/118/68-connected-apps-offline.png: TrainingPeaks with Sync Now and the write switch, V.O2 with Reconnect.
- runs/118/69-connected-apps-back-online.png: still Sync Now after the network came back.
- runs/118/db-integrations-while-offline.txt, runs/118/integrations-after-online-relaunch.txt: server and local rows.
- runs/118/console-redacted.log: 19:52:26 local, "Token refresh failed: no answer".

**Decision quote.**
> 

**Triage.**
