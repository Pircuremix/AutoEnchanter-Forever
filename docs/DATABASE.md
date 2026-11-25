# Customer database — schema 2

Introduced in 1.5.0; migrated to schema 2 in 1.6.0. Saved locally in account-wide AutoEnchanterDB.customerLedger; no remote service and no backfill.

## Schema

```lua
customerLedger = {
  schema = 2,
  nextID = 2,
  customers = {
    ["Player-example"] = {
      name = "Example Surname",
      visits = {
        {
          id = 1, name = "Example Surname",
          owner = "Player-enchanter", enchanter = "Example Enchanter",
          invited = 1700000000, localTime = "2023-11-14 15:13:20",
          status = "accepted", resolved = 1700000004,
          closed = 1700000120, tipCopper = 150000, enchants = 3,
          unverified = 0, trades = { -- individual evidence entries
            -- at, copper, enchants, incoming/outgoing (if verified),
            -- reason, unverified
          },
        },
      },
    },
  },
}
```

Example only; values are fictional. The numeric timestamp uses GetServerTime (fallback time); localTime uses the client's local date() at recording time. It is kept unchanged if the timezone later changes. Full character name is retained; GUID is the authoritative identity. If GUID or pre-invite membership is unavailable, a record is unverified and cannot receive a trade. Monotonic IDs remain unique across deletion/reset. Currency is integer copper, displayed in gold (10,000 copper = 1g).

## Lifecycle

| Status | Evidence | Aggregate |
|---|---|---|
| pending | real native request, readable GUID and known not in group | pending only |
| accepted | pending GUID observed in group before 120s deadline | accepted |
| declined | matching localized ERR_DECLINE_GROUP_S system message, unambiguous full-name match | declined |
| expired | confirmed sent evidence and no observed acceptance within 120s | declined |
| already_grouped | named native already-grouped result | separate missed opportunity |
| busy | named native busy/pending result | separate missed opportunity |
| failed | call error, false result, or attributed native block | separate |
| superseded | earlier overlapping same-GUID request when newest is accepted | separate |
| unverified | unavailable identity or prior membership | separate |

No record for cooldown, preflight denial, debug simulation or manually invited player without a prior AE request. An accepted visit closes when the GUID is observed no longer in group. Pending state is saved, restored and reconciled on roster events, with a nearest-expiry timer. Native acceptance causation cannot be proved; manual invitations to a pending customer may be correlated. A late or ambiguous block is not falsely attributed. The current enchanter GUID scopes active visit correlation. An accepted visit can be restored after reload if membership still observed. If UI is off/debug, previously recorded visits can finish passively; no new simulated data.

Average tip per item = sum of qualifying copper / sum of completed item enchants. Zero-tip enchants count; zero denominator displays —. Period filters select by invite timestamp, not payment timestamp. Pending/failed/superseded, grouped, busy and unverified do not enter acceptance-rate denominator. Legacy expired records without sentConfirmed remain historical but are excluded from verified declines.

## Persistence and safety

Existing whitelist and settings are unchanged. Missing ledger initializes schema 2; schema 1 migrates in place. A nonmatching schema is kept untouched and ledger disabled. Never upload account SavedVariables, customer names or logs to public GitHub. SavedVariables are persisted on normal logout/reload; a crash can lose unsaved activity. There is no automatic retention deletion. Dashboard export is tab-separated filtered visits (copy manually); it does not include GUIDs or every raw trade field. For complete backup, close WoW and copy the account SavedVariables file. Deleting a customer or resetting all requires confirmation, removes pending and active indexes, and does not alter the whitelist. A full ledger can grow over time; keep backups.

## Maintainer rules

Do not infer acceptance from InviteUnit return, infer a decline from a native failure, double-count overlapping attempts, or change historical local timestamps. Maintain schema migrations, explicit uncertainty and integer copper accounting. See tests/business.lua and TRADE-TRACKING.md.

## Schema 2 additions

Each customer gains policy = {accepted, declines, tips, uncertain, grouped, busy, noTrade, freeEnchants, offenses, declineBans, history, days, dayCount, cooldownUntil, cooldownReason, declineUntil, tipUntil}. Cached counts are rebuilt from records on init; deadlines/offense history persist. Each visit may have sentConfirmed, policyEligible, guildAtInvite (true/false/nil), guildWhisper (API call status, never proof of delivery), exchanged, unpaidDays, freeGuildEnchants, closureUncertain, policyFinalized, noTrade. Verified trade entries gain exchanged and guild. No new raw player chat stored. Guild settings are account-wide guildWhisperEnabled (true default), guildWhisperMessage (default literal; valid empty stays empty). Guild roster cache is session-only. Migration never retroactively issues bans from old ambiguous or unpaid records. See CUSTOMER-POLICY.md for authoritative rules.

## 1.6.2 manual visits (schema 2)

Optional visit.source is auto or manual (historical absent treated as auto). Manual includes observed external native calls. An unresolved name-only manual visit has identityUnverified=true, provisional manual:<normalized full name> key and policyEligible=false. It can resolve named results and show in statistics, but cannot create identity-based bans or trades. On exact unique ordinary roster match, move only that pending visit into the GUID customer, set policyEligible, then accept once. Prior unresolved outcomes stay separate rather than assuming identity. Manual pending owner/name index rebuilt on login. Manual calls are not prevented by auto restrictions. Known GUID outcomes use normal policies and trade accounting.
