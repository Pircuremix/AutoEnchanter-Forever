# Forever API audit — 2026-11-24

Target: 1.60.1 / interface 16001. Release candidate 1.3.0. Reviewed v1.2 archive source and original supplied TBC source. Reviewed Blizzard-generated Lua documentation as mirrored in Gethe/wow-ui-source's `forever` branch, including the actual file contents retrieved through GitHub. Blob identifiers below identify the inspected file snapshots, not a pinned client build or a commit. No direct game-client access.

## Source evidence and conclusions

| Call or event | Evidence / decision |
|---|---|
| `C_PartyInfo.InviteUnit(targetName)` | PartyInfoDocumentation: string argument, no success return, `RequiresValidInviteTarget`. Preserve raw author; use native API only; report calls, not delivery. |
| `C_PartyInfo.CanInvite()` | PartyInfoDocumentation: boolean return; no arguments. |
| `C_PartyInfo.IsPartyFull([category])` | PartyInfoDocumentation: optional category, boolean return. Omit category for active party. |
| `C_PartyInfo.IsGUIDInGroup(guid[, category])` | PartyInfoDocumentation: WOWGUID and optional category, boolean return. Never pass secret or empty GUID. |
| `CHAT_MSG_CHANNEL`, `CHAT_MSG_SAY`, `CHAT_MSG_YELL` | ChatInfoDocumentation: args 1=text, 2=playerName, 7=zoneChannelID, 8=channelIndex, 12=guid. All three are marked SecretInChatMessagingLockdown. Guard message, name, channel ID and GUID before access. General/Trade IDs 1/2 remain a live acceptance item. |
| `UnitFullName`, `UnitName`, `UnitGUID` | UnitDocumentation: unit token input, name/server and GUID outputs; identity-related secrecy annotations. Community Forever reports second name value is surname; preserve both rather than discard it. |
| `Menu.ModifyMenu(tag, callback)` | Blizzard_Menu/Menu.lua: callback receives ownerRegion, description and contextData. UnitPopupShared.lua builds the tag as MENU_UNIT_ plus the registered menu type and sets contextData.name and contextData.surname on Forever; UnitPopupSharedMenus.lua registers PLAYER, CHAT_ROSTER, PARTY, RAID, RAID_PLAYER, FRIEND, ENEMY_PLAYER, TARGET and FOCUS. The addon registers these tags and reads surname first; live dispatch is not proven. `CreateButton` follows modern menu interface. |
| `issecretvalue`, optional `canaccesstable` | Secret-value guard; optional function checked before calling. Mock tests verify control flow, not the engine's true secret-value behavior. |
| `CreateFrame`, RegisterEvent, SetScript, UnregisterEvent, SlashCmdList, DEFAULT_CHAT_FRAME:AddMessage, GetTime, GetBuildInfo, ADDON_LOADED, PLAYER_LOGIN, PLAYER_ENTERING_WORLD, ADDON_ACTION_BLOCKED/FORBIDDEN | Standard WoW UI infrastructure; exercised via mocked API. Not all individual definitions independently inspected in the Forever source. |
| TOC and folder | Interface 16001 corroborated by current Forever addon guides/source reviews. Folder `_forever_` is the live install directory, verify with Battle.net. |

### Inspected source files (Forever branch)

- [PartyInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/PartyInfoDocumentation.lua) — blob `39fc3adc4c7d8699e7be954c5dc641426bc4d22b`.
- [ChatInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua) — blob `0767f5042a47b9fd03621044cc94f26390e08e2b`.
- [UnitDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua) — blob `620b28ad0cc57c13501a196a42c37b8398703a84`.
- [Menu.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Menu/Menu.lua) — blob `ab0d377568c2c3f037d07cdd0d7df9b3b5492bf4`.
- [UnitPopupMenus.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UnitPopup/Mainline/UnitPopupMenus.lua) — blob `9680db8a7b2d692ed1d5fa1e75d3a22d800d0f00`; inspected menu entry definitions, not full tag routing.

- [UnitPopupShared.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UnitPopupShared/UnitPopupShared.lua) — blob `58f9090db32c07cb88bce2d420fd9be887c7e4db`.
- [UnitPopupSharedMenus.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UnitPopupShared/UnitPopupSharedMenus.lua) — blob `9719a3445530b67e0b26e88181086ed3e6fecc4f`.
- [Camelot/UnitPopupMenus.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UnitPopup/Camelot/UnitPopupMenus.lua) — blob `39e6dcc575fbd34aa521534358d13f7ecc9dae1a`; Forever-specific menu overrides.

### Supplemental sources

- [Forever API change notes](https://warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes/notes)
- [Forever invite function signature and flags](https://wowlua.dev/api/C_PartyInfo/InviteUnit)
- [Secret-value restriction descriptions](https://warcraft.wiki.gg/wiki/Secret_value)
- [Community in-game surname observations](https://github.com/xIGBClutchIx/ForeverPlusPlus/blob/main/docs/forever-api.md)
- [Live install location/interface](https://elitegrindlab.com/warcraft-forever/addons/)

## Risks and decisions

A successful `pcall` cannot prove invite delivery. The engine may silently decline invalid targets; confirmation can be needed in some cases. Existing public chat and modern menu support do not guarantee every chat author is inviteable. The implementation does not try to change invite permissions or circumvent restrictions. Existing normalized exact-match semantics were intentionally retained, including aliases and filler tokens; no recipe-specific whitelist data was provided. Known matching collisions, English-only aliases and last-message learning semantics are documented. A 7-second cooldown applies to matches even when eligibility later fails, retaining the original anti-spam design. Offline tests are necessary but not sufficient to validate this addon; run the live checklist before relying on it.


## 1.4.0 group automation extension

Reviewed actual Forever branch source snapshots (same mirrored Blizzard-generated API source used in the original audit).

| API | Evidence and implementation |
|---|---|
| GROUP_ROSTER_UPDATE, PARTY_LEADER_CHANGED, C_PartyInfo.ConvertToRaid() | [PartyInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/PartyInfoDocumentation.lua), blob 39fc3adc4c7d8699e7be954c5dc641426bc4d22b. Roster event carries no member payload; inspect units. ConvertToRaid is restricted, may prompt, no success return. Never use ConfirmConvertToRaid. |
| C_ChatInfo.SendChatMessage(message, chatType, languageID?, target?), InChatMessagingLockdown() | [ChatInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua), blob 0767f5042a47b9fd03621044cc94f26390e08e2b. Chat call is restricted, no delivery return; check lockdown and only PARTY/RAID. |
| GetRaidTargetIndex(target), SetRaidTarget(target,userIndex) | [RaidMarkersDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/RaidMarkersDocumentation.lua), blob 70f01983b6b644eabf75a43f6b17b13b6a621607. Getter may return secret; setter restricted. Check existing marker, use index 1–8 only. |
| UnitGUID, UnitName, UnitIsGroupLeader, UnitIsGroupAssistant | [UnitDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/UnitDocumentation.lua), blob 620b28ad0cc57c13501a196a42c37b8398703a84. Identity/permissions may be secret. |
| IsInGroup, IsInRaid, GetNumGroupMembers | [UnitPopupSharedButtonMixins.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UnitPopupShared/UnitPopupSharedButtonMixins.lua). Native group UI uses IsInRaid, IsInGroup(LE_PARTY_CATEGORY_INSTANCE), UnitIsGroupLeader for conversion visibility. |
| Settings.RegisterCanvasLayoutCategory, RegisterAddOnCategory, OpenToCategory | [Blizzard_Settings.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua), blob d3412da0be76c1fd965d7ac26413fa9967eda740. Native settings canvas and category ID. Slash fallback if panel registration fails. |

The marker selector uses native raid-target texture helper when present (otherwise 4x4 texture coordinates). C_Timer.After supplies one bounded conversion wait, not polling. Ordinary group APIs are checked at runtime. A confirmation prompt or a successful void call is not proof of action completion. Only readable roster state establishes customer membership and observed raid conversion. Tests emulate secret values, errors, blocked actions, permission changes and synchronous/asynchronous roster updates; they cannot reproduce actual client restrictions, protected native menu behavior or server delivery. In-game acceptance of these additions remains pending.


## 1.5.0 ledger, trades and minimap source review

- [PartyInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/PartyInfoDocumentation.lua): GROUP_ROSTER_UPDATE and IsGUIDInGroup used to observe acceptance. PARTY_INVITE_CANCEL has no outgoing customer identity; localized ERR_DECLINE_GROUP_S via CHAT_MSG_SYSTEM is best-effort and matched only to a unique pending full name. No native invite delivery proof.
- [SystemTimeDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SystemTimeDocumentation.lua), blob 818872a04c98bff1564409efa55c12928139fc72: GetServerTime numeric epoch; local date() formatting at invite.
- [TradeInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeInfoDocumentation.lua), blob f44c116fc13f2b550e2f49cc1738e771d44c6be9: TRADE_SHOW/CLOSED, offer changes, both acceptance flags; no documented completed-trade event in this system.
- [TradeFrame.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/TradeFrame.lua), blob ff8e5416f0d56e007867ec6656498950c3491443: NPC recipient, six tradable slots, seventh enchant slot, player and target info return positions. MoneyFrame shared code calls both money getters.
- ENCHANT_SPELL_COMPLETED (SpellDocumentation.lua) returns successful and optional ItemLocation; UNIT_SPELLCAST_SUCCEEDED (UnitDocumentation.lua) supplies unit/castGUID/spellID, can be secret. Neither is alone evidence of delivery. Require explicit localized ERR_TRADE_COMPLETE and valid final both-accepted snapshot; actual Forever message delivery/order unverified.
- [MenuUtil.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Menu/MenuUtil.lua) CreateContextMenu(ownerRegion,generator,...). EUI discovery and Shift-left hook reviewed directly: see docs/UI-COMPATIBILITY.md. No live client access.

See trade and database documents for evidence semantics, privacy and acceptance procedure.

## 1.6.0 native results, guild and performance

- [Forever PartyInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/PartyInfoDocumentation.lua): InviteUnit takes only targetName; IsGUIDInGroup observes our own group, not unrelated parties. Use runtime localized ERR_* messages through CHAT_MSG_SYSTEM, UI_INFO_MESSAGE, UI_ERROR_MESSAGE for named outcomes. [Warcraft Wiki UI_ERROR_MESSAGE](https://warcraft.wiki.gg/wiki/UI_ERROR_MESSAGE) lists ERR_INVITE_PLAYER_S, ERR_ALREADY_IN_GROUP_S, ERR_PLAYER_BUSY_S, ERR_DECLINE_GROUP_S. Other optional constants used only when present. Native event ordering and exact localization are not proven in Forever.
- [Forever GuildInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/GuildInfoDocumentation.lua), blob 311103f57a2b43f56b9a366ede3cd6a6a09123eb: C_GuildInfo.GuildRoster and GUILD_ROSTER_UPDATE. [GetGuildRosterInfo](https://warcraft.wiki.gg/wiki/API:GetGuildRosterInfo) includes member GUID at return 17. Runtime validates full roster and own GUID; no assumptions if unreadable. PLAYER_GUILD_UPDATE and explicit membership-change system messages request fresh cache.
- [Forever ChatInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua): C_ChatInfo.SendChatMessage(message, chatType, languageID?, target?) permits target argument for WHISPER, restricted and no delivery return. Check lockdown and session block, never retry or bypass. Synchronous attributed whisper block does not disable group welcome. Async generic blocks cannot be reliably attributed and may conservatively disable group chat. Blank/whitespace skips call.
- debugprofilestop used if available for local timing, not network latency. See PERFORMANCE.md and policy test logs. Live client testing required for invite messages, guild refresh, whisper restrictions and trade completion.

## 1.6.1 welcome templates

[Forever RaidMarkersDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/RaidMarkersDocumentation.lua) declares GetRaidTargetIndex secret-capable. Use safe read at send time; never assume configured marker was applied. [Forever ChatInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua) declares C_ChatInfo.ReplaceIconAndGroupExpressions(input, noIconReplacement?, noGroupReplacement?) -> string, AllowedWhenTainted. Preview uses (false,true) locally, falling back to raw tokens on unavailable/secret/error. Outgoing chat uses native numeric {rt1}–{rt8} tokens ([chat substitutions](https://warcraft.wiki.gg/wiki/Chat_substitutions)), not local texture markup. Live rendering and server delivery remain to be verified.

## 1.6.2 manual invite evidence

[Forever SlashCommandsOverrides.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_ChatFrameBase/Mainline/SlashCommandsOverrides.lua) routes /invite to C_PartyInfo.InviteUnit(msg). [Forever UnitPopupUtils.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UnitPopup/Mainline/UnitPopupUtils.lua) routes ordinary INVITE/SUGGEST_INVITE to the same API; REQUEST_INVITE and Battle.net paths differ. [PartyInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/PartyInfoDocumentation.lua) documents InviteUnit and ConfirmInviteUnit, no delivery return. Use hooksecurefunc post-hooks if available, never overwrite native functions; ignore our own call queue and fall back only on localized outgoing sent evidence. Post-hooks can miss native internal calls and cannot identify another addon's caller; label manual/external. Actual hook execution, event ordering, full surnames and live chat restrictions need validation. Do not intercept, confirm or resend an invite.
