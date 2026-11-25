# Architecture and maintenance contracts

Source version: 1.4.0. Forever interface 16001. This document describes actual implementation, not a design proposal.

## Runtime layout and load order

The TOC is authoritative. WoW calls each Lua chunk with addon name and the same private addon namespace table.

| File | Responsibility |
|---|---|
| AutoEnchanter/Group.lua | Owns group state, setting validation, pending GUID tracking, roster reconciliation, welcome, marker, raid conversion, counters and slash command handlers; exposes ns.Group |
| AutoEnchanter/Settings.lua | Native Settings canvas, saves through Group:Set; exposes ns.Options |
| AutoEnchanter/AutoEnchanter.lua | Original chat events, normalization, whitelist, invite eligibility, native invite call, right-click learning, DB migration, slash/event dispatch |
| AutoEnchanter/AutoEnchanterIcon.blp | Native 64x64 BLP2 icon, referenced by TOC |
| AutoEnchanter/AutoEnchanter.toc | Load order, interface, version, category and SavedVariables |

No external library, network, OnUpdate or recurring timer. A single conversion timeout is the only new scheduled callback. Modules use local helpers and the private namespace, not new public globals.

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
