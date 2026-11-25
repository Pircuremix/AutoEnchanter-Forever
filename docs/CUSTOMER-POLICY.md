# Customer policy — 1.6.0

## Declines and temporary restrictions

All durations are elapsed seconds persisted as epoch deadlines: 30 minutes = 1800 seconds, one day = 86400 seconds. The 7-second session anti-spam remains. Only verified declines (explicit localized decline or confirmed sent timeout) enter policy totals. Pending, already_grouped, busy, failed, unverified, superseded and legacy unconfirmed expirations do not. No retroactive ban on upgrade; historic explicit declines count toward the threshold. A first new threshold ban is 30 days, subsequent verified declines 10 days each while lifetime acceptance count is zero. Acceptance clears the decline ban and disables future threshold bans. Normal 30-minute cooldown still applies to subsequent declines.

A real accepted visit that closes without any verified exchange receives a 30-minute cooldown from observed departure. A verified exchange is any nonzero money, transferred item, currency, or delivered enchant on either side. It need not qualify as a tip. Canceled trades do not count; unverified, ambiguous or still-open trades prevent penalties. Five-second grace allows completion evidence to settle, temporarily suppressing another invitation. Visits restored from reload with uncertain departure and unsettled visits on reload are not penalized. Historical visits lack policyEligible and cannot trigger new penalties.

## Non-tipping policy

Only policy-eligible accepted visits with verified delivered enchant(s), no lifetime positive qualifying tip and no unverified trade history can contribute. Dates are captured using local calendar date at verified trade completion, not the invite date. A guild member at invite or service receives exemption; unknown membership at either stage cannot contribute an unpaid day. Current guild members/unknown membership are not subjected to a non-tipping ban. When an accepted visit closes, settle for five seconds before evaluating; a separate qualifying tip during the visit prevents penalties. First ban requires two unique unpaid dates. After a ban expires or is manually removed, one new qualifying visit triggers the next ban: 30, 90, 180, then repeated 180 days. Used days are cleared and historical offense entries retained. Same-day repeated visits count once before the initial ban. A positive lifetime tip removes the active tip restriction and prevents future tip bans. No policy uses an unconfirmed spellcast or wallet delta.

Current guild members remain subject to decline and no-trade policies. Their previous tip ban is suspended while membership is confirmed or uncertain, not erased. Leaving the guild restores a still-active restriction once the roster confirms nonmembership. Past free guild services never become offenses. Guild identity is scoped to current character's guild; account-wide customer history and restrictions persist.

## Blacklist UI

/ae blacklist: filter All/Active/History/Suspended, search and sort. Select a row to see recent history, click removal twice to clear restrictions. No permanent bans. Manual removal preserves decline and non-tipping offense history, but clears current deadlines and accumulated unpaid days. Customer deletion/reset is destructive and deletes policy history as well. Multiple restrictions use the latest applicable deadline; guild exemption affects tip restriction only. No extension for suppressed attempts. Expiry occurs automatically on next lookup; history is retained.

Trade evidence and live invite messages remain subject to Forever client behavior. If a legitimate transaction is unverified, the conservative policy may under-enforce. Use /ae ledgerstatus, /ae tradetrace and manual restriction removal as appropriate. Never fabricate evidence.
