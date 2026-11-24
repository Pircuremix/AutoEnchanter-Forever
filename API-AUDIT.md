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
