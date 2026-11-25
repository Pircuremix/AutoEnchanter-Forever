# Invitation outcome classification — 1.6.0

C_PartyInfo.InviteUnit(targetName) is a void native request, not a server result. A successful invocation creates a pending ledger record if readable GUID and known prior nonmembership. Own pending requests are suppressed in constant time to prevent overlap; the record expires after 120 seconds. Accepted requires GUID observed in our group, not a system chat alone.

InviteResults.lua matches runtime localized ERR_* templates (literal escaped pattern, strips player links and normalizes full-name space/hyphen), with no hardcoded English in runtime. Uses CHAT_MSG_SYSTEM, UI_INFO_MESSAGE and UI_ERROR_MESSAGE. Explicit named results map to one unambiguous pending target. Synchronous result messages during the native invite are staged until the record exists. Two-field patterns require same normalized names; incoming invite messages are not used. Duplicate results do not create duplicate resolved records.

| Outcome | Evidence | Decline policy |
|---|---|---|
| accepted | GUID joins our group | no; ends escalation |
| declined | ERR_DECLINE_GROUP_S | yes |
| expired | ERR_INVITE_PLAYER_S sent evidence + timeout | yes |
| already_grouped | ERR_ALREADY_IN_GROUP_S | never |
| busy | ERR_PLAYER_BUSY_S; optional named already-invited constants if present | never |
| failed | native call error, named not-found/offline or attributable failure | never |
| unverified | missing/ambiguous result or unconfirmed timeout | never |
| superseded | overlapping historic request consumed without independent result | never |

Known unnamed busy/grouped messages can be attributed only if synchronously raised during a specific native call. Asynchronous unnamed errors or unmatched grouped/busy events invalidate pending sent evidence conservatively, rather than guessing the target. Diagnostics count unattributed events (may duplicate across event channels). An already-grouped or busy outcome is a potential missed opportunity, not proof another enchanter was faster. ERR_INVITE_PARTY_BUSY is our party formation failure, not customer refusal. Preflight ineligibility does not create a customer decline. Actual Forever localization and event ordering still need live testing.

Reference: [Warcraft Wiki UI_ERROR_MESSAGE](https://warcraft.wiki.gg/wiki/UI_ERROR_MESSAGE) documents ERR_INVITE_PLAYER_S, ERR_ALREADY_IN_GROUP_S, ERR_PLAYER_BUSY_S, ERR_DECLINE_GROUP_S, ERR_BAD_PLAYER_NAME_S and ERR_INVITE_PARTY_BUSY. [Forever PartyInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/PartyInfoDocumentation.lua) confirms InviteUnit signature and GROUP_ROSTER_UPDATE. Never broaden ambiguous parsing simply to raise counts.
