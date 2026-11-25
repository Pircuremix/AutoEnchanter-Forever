# Architecture and maintenance contracts

Source version: 1.6.0. Forever interface 16001. This document describes actual implementation, not a design proposal.

## Runtime layout and load order

The TOC is authoritative. WoW calls each Lua chunk with addon name and the same private addon namespace table.

| File | Responsibility |
|---|---|
| AutoEnchanter/CustomerPolicy.lua | Persistent restrictions, cached lifetime totals, settlement and offense history |
| AutoEnchanter/Guild.lua | Guild roster cache and independent invite-time whisper |
| AutoEnchanter/InviteResults.lua | Localized named outcome classification and synchronous result staging |
| AutoEnchanter/Performance.lua | Bounded local latency samples |
| AutoEnchanter/Database.lua | Persistent invitation ledger and active visit correlation, exposes ns.Database |
| AutoEnchanter/Trade.lua | Read-only transaction snapshot and completion evidence, exposes ns.Trade |
| AutoEnchanter/Dashboard.lua | Lazy paginated dashboard, sorting, export and confirmed deletion, exposes ns.Dashboard |
| AutoEnchanter/Minimap.lua | Named minimap button, toggle and context menu, exposes ns.Minimap |
| AutoEnchanter/Group.lua | Owns group state, setting validation, pending GUID tracking, roster reconciliation, welcome, marker, raid conversion, counters and slash command handlers; exposes ns.Group |
| AutoEnchanter/Settings.lua | Native Settings canvas, saves through Group:Set; exposes ns.Options |
| AutoEnchanter/AutoEnchanter.lua | Original chat events, normalization, whitelist, invite eligibility, native invite call, right-click learning, DB migration, slash/event dispatch |
| AutoEnchanter/AutoEnchanterIcon.blp | Native 64x64 BLP2 icon, referenced by TOC |
| AutoEnchanter/AutoEnchanter.toc | Load order, interface, version, category and SavedVariables |

No external library, network, OnUpdate or recurring polling. Bounded one-shot callbacks handle conversion, nearest invitation expiration, trade close grace period and coalesced visible dashboard refresh. Modules use local helpers and the private namespace, not new public globals.

## Event and invite contract

Existing hot path remains: filter channel and identity -> normalize -> exact hash lookup -> cooldown -> check party eligibility -> native InviteUnit(raw author). Do not add roster scans or UI updates before this call. Core forwards an invite to Group:TrackInvite only after a successful Lua invocation and an explicitly false pre-invite IsGUIDInGroup result. Native success does not confirm delivery. GUID is authoritative; never substitute first name, surname or normalized name for missing GUID.

Group:TrackInvite stores an entry by GUID only when a welcome or marker is enabled, the addon is active and not debugging. Entries expire 120 seconds after the last recorded real call; at most 128. It reconciles immediately only when membership is already observable (synchronous roster event case). Group:OnRoster processes GROUP_ROSTER_UPDATE, PARTY_LEADER_CHANGED and PLAYER_ENTERING_WORLD. It reads the live ordinary group and unit GUIDs; instance-group or unreadable state is ignored. Party unit tokens: player and party1..N-1; raid: raid1..N. Own GUID is excluded. A matched GUID is removed from pending before any action and stored in a ready queue, so repeated roster events cannot duplicate it. This is correlation, not proof which invitation the player accepted. No new pending is created in debug.

## State machine

- Pending -> accepted/ready: matching GUID appears in current roster within TTL.
- Pending -> expired: next prune after TTL; no action. Clear on master disable, debug, invite block, or when both customer actions are switched off.
- Ready -> consumed: remove from queue before action; recheck current membership; marker then chat are independent. Never requeue on failure.
- Ready -> waiting: if eligible threshold reached, one conversion request is made; queue held until confirmed raid, failed call, next below-threshold roster, or five-second timeout. If no usable group then queued actions are discarded.
- Conversion latch: one attempt per eligible threshold cycle, reset on a below-threshold ordinary party or solo roster. A raid does not auto-convert back. Separate dry-run latch. Session block flags persist until reload. Native conversion may open a confirmation prompt; never invoke ConfirmConvertToRaid.

A conversion request is attempted when auto raid is enabled, the current ordinary party has at least the configured actual member count (2–5, including self), player is group leader, outside an instance and no latch/block. Any roster/leader/world event can trigger it, including manual parties. It is independent of customer welcome settings. Confirmed conversion means observing IsInRaid, not a void API return. Timeout sends remaining eligible welcomes via the current confirmed mode, without retrying conversion. If a customer leaves before flush, no welcome. Pending invites do not count.

## SavedVariables schema

One account-wide AutoEnchanterDB table. No destructive schema replacement.

| Key | Type/default | Introduced |
|---|---|---|
| whitelist | array of strings, empty | original |
| enabled | boolean true | original |
| debug | boolean true | original |
| popupEnabled | boolean true | original |
| welcomeEnabled | boolean false | 1.4.0 |
| welcomeMessage | single-line string, <=255 bytes; Thanks for choosing me for your enchant! | 1.4.0 |
| autoMarkerEnabled | boolean false | 1.4.0 |
| raidMarker | integer 1–8, 1 | 1.4.0 |
| autoRaidEnabled | boolean false | 1.4.0 |
| raidThreshold | integer 2–5, 3 | 1.4.0 |

Validate types/ranges at initialization and via Group:Set. Invalid values get defaults; valid existing values persist. Do not save pending GUIDs, timers, counters or block flags. UI controls and slash commands share validation. Changes to message/marker use current config at action time. Message templates expand only customer/player/zone, validate expanded length and controls, never execute text.

## API safety invariants

- All group queries/actions use protected calls with secret-value checks. If the group mode/identity/permissions/current marker are unavailable, fail closed. Ordinary PARTY/RAID only; no SAY, YELL, CHANNEL or INSTANCE_CHAT fallback.
- MarkSelf checks player mark before scanning group markers and again immediately before native SetRaidTarget. Never pass 0, call RemoveRaidTargets or use the toggling SetRaidTargetIcon. If the chosen marker is visible on another member, skip. Cannot guarantee uniqueness on units outside the observable group or against concurrent changes.
- RAID marking requires leader or assistant; in ordinary parties defer to the native API. Chat and marker block flags are independent, and do not stop invite matching.
- ADDON_ACTION_BLOCKED/FORBIDDEN attributed to this addon routes named actions to their block flags. Errors and false returns skip the action. No retry loop or protection bypass. A native call can be silently rejected; counters are requests, not server receipts.
- Disable/debug suppress real actions and clear pending; simulation of conversion is logged once per eligible cycle. Debug sends no actual invite and cannot simulate a genuine customer acceptance.
- No polling or cross-client communications. Do not speed up by bypassing native restrictions.

## Testing / release

tests/regression.lua retains original matching, invite and menu behavior; tests/group.lua exercises real module/core callbacks against mocked APIs, including native Settings controls. scripts/test.sh validates every runtime/test Lua file then runs both suites. scripts/package.sh reads the TOC to include every Lua module plus the TOC and BLP, rejects unlisted Lua files, validates ZIP and writes explicit Forever release.json. Workflows run tests on both Lua 5.1 and 5.4; release publishes from main only on versioned changes, with notes from docs/releases/v<version>.md. See AGENTS.md for update policy. Live client tests remain required for restrictions, UI layout and server delivery.


## 1.5.0 durable business ledger contracts

The core calls Database:Record **after** the native invite, independently of the session-only Group:TrackInvite used for optional welcome and marker actions. Do not put history scans or UI work before InviteUnit. The ledger uses one pending index by invitation ID and one active visit per GUID for the currently logged-in enchanter, reconstructed on first roster reconciliation. Overlapping requests may only yield one acceptance; older ones are superseded rather than falsely declined. Explicit system declines resolve the newest unambiguous pending full-name match. Failed calls and unknown identity/prior membership remain distinct. Expiration uses a single nearest-deadline timer (120 seconds); no recurring poll. Native delivery and causation are not proven by the Lua call.

Group events reconcile both modules independently. Master-off/debug disables new requests and all group automation but existing ledger outcomes and passive trade observations continue. No synthetic records for debug or suppressed invitations. See [DATABASE.md](DATABASE.md) for schema, state transitions, privacy, and migration.

Trade observes TRADE_SHOW, offer changes, both-accepted snapshots, explicit localized completion/cancel messages and TRADE_CLOSED (two-second grace). The trade's captured NPC GUID and active visit reference are the only attribution keys. No target-name guess or wallet delta. No trade interaction is automated. The final non-traded target-slot enchant (return #6) contributes at most one service on confirmed trade. Ambiguous snapshots are recorded with zero totals. See [TRADE-TRACKING.md](TRADE-TRACKING.md).

Dashboard builds only when opened, reuses settings controls, pages eight customers/six invitations, sorts computed rows and coalesces visible refresh on mutations. No database scan on unrelated public chat. Named 30px minimap button is a direct child of Minimap; third-party layouts can reparent it. All enable/disable operations route through the existing slash handler. See [UI-COMPATIBILITY.md](UI-COMPATIBILITY.md).

The new SavedVariables fields are customerLedger (schema 1), minimapHidden (false), dashboardPosition (x/y/scale). Unknown future ledger schemas are preserved and not modified. Tests/business.lua covers database, trade, dashboard model and minimap dispatch; runtime tests also validate original core/group behavior. Real trade event ordering and visual layout require live testing.

## 1.6.0 policy, guild and fast-path contracts

Schema 2 supersedes schema 1 expiration classification and adds customer policy state. Preserve all historical records and lifetime positive tips; old unconfirmed expired records are not verified declines. New invite attempts store policyEligible, guildAtInvite and optional guildWhisper call status. No retroactive bans based on old unpaid visits. Read [CUSTOMER-POLICY.md](CUSTOMER-POLICY.md), [INVITE-OUTCOMES.md](INVITE-OUTCOMES.md) and [PERFORMANCE.md](PERFORMANCE.md) before editing.

Core pre-invite path: chat eligibility, normalized exact lookup, seven-second anti-spam, cached GUID guild membership, constant-time restriction and own pending checks, native eligibility and InviteUnit. No history scan, guild roster request, chat-cache pruning or dashboard rendering before invite. Synchronous native result events are buffered until ledger record exists; the guild whisper follows the native call and queued results. A native call is not delivery confirmation. Optional normal welcome remains independent and uses Group.lua after observed join. Trade ledger finalization and UI refresh are post-invite/event-driven.

Policy:Init reconstructs accepted, verified decline, tip, unverified, grouped, busy and no-trade totals once at login. Outcomes and completed trades increment cached totals. Pending keys are indexed by enchanter GUID and customer GUID. Restrictions are absolute epoch deadlines; no timer per ban. A close callback settles for five seconds; restored/ambiguous visits are not penalized, including logout during settlement. Group departure is observed absence, not blame. Unverified trades prevent non-tipping enforcement. Guild roster membership is tri-state; no uncertain tip restriction enforced. Guild membership at invitation and service is used conservatively, and guild whispers may be blocked; empty text never calls chat API. No change to original configured welcome. Blacklist removal clears active deadlines and accumulated unpaid days, retains offense history.
