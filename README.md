# AutoEnchanter — WoW Forever

**Version 1.3.0 (release candidate)** • Target: World of Warcraft: Forever 1.60.1, Interface 16001 • Original author: Sleepy

AutoEnchanter monitors public chat for customer requests that match your manually curated enchant whitelist, then immediately calls the native party invite API when enabled and eligible. It does not perform enchants, inspect your recipe book, advertise, send whispers, confirm dialogs, or guarantee delivery of invitations. It does not attempt to bypass Blizzard's restrictions.

## Install or upgrade

1. Exit WoW. Back up your old addon folder and account SavedVariables file.
2. Extract the installation ZIP so the folder `AutoEnchanter` is directly inside `World of Warcraft/_forever_/Interface/AddOns/`. The actual game directory can be found via Battle.net > WoW Forever > Show in Explorer.
3. The layout must be `AddOns/AutoEnchanter/AutoEnchanter.toc` and `AddOns/AutoEnchanter/AutoEnchanter.lua`.
4. Launch Forever, enable Auto Enchanter in the addon list, and enter `/ae diagnostics`.
5. Use `/ae list` to verify your whitelist. Start with `/ae debug on` and `/ae on`, test a known phrase, and only then use `/ae debug off` for real invite calls.

### Preserve your TBC whitelist

The global SavedVariables table remains `AutoEnchanterDB` with `whitelist`, `debug`, `enabled`, and `popupEnabled`. In your old client's `WTF/Account/<account>/SavedVariables/`, locate `AutoEnchanter.lua` (not the addon source). With both clients closed, copy it to the equivalent directory under `_forever_`. Back up any existing Forever file first; copying replaces its contents. Your actual saved whitelist was not supplied for this audit. Existing valid string entries and boolean settings are preserved; malformed or empty-normalized entries are discarded, and existing duplicate valid strings are retained. Settings are account-wide, not character-specific. A fresh install starts enabled, with debug simulation and right-click learning enabled, but an empty whitelist.

## Commands

Both `/ae` and `/autoenchanter` work.

| Command | Behavior |
|---|---|
| `/ae on`, `/ae enable` | Enable matching and invite processing. |
| `/ae off`, `/ae disable` | Disable invite processing; learning may continue. |
| `/ae add <phrase>` | Store original phrase; reject empty or duplicate normalized keys. |
| `/ae remove <index or phrase>` | Remove one entry and rebuild lookup. |
| `/ae list` | Display original entries and their normalized keys. |
| `/ae test <phrase>` | Show MATCH or NO MATCH and normalized key; never invites. |
| `/ae debug on` | Dry run; logs matching and nonmatching phrases, no real calls. |
| `/ae debug off` | Call the native invite API when eligible. |
| `/ae debug` | Toggle debug. |
| `/ae popup on/off` | Enable or disable learning menu; without argument toggles. |
| `/ae status` | Counters and switches for this session. |
| `/ae diagnostics` or `/ae diag` | Client version/build/interface, available APIs, block state, simulations, failed and ineligible calls. |

## System design

```text
CHAT_MSG_CHANNEL / CHAT_MSG_SAY / CHAT_MSG_YELL
    -> Reject protected payloads, non-General/Trade channels, self messages
    -> Cache most recent eligible message for right-click learning (if enabled)
    -> Check master switch and nonempty whitelist
    -> Normalize incoming text
    -> Exact hash lookup against normalized whitelist
    -> Per-name cooldown (7 seconds; no global delay)
    -> Debug simulation OR native party eligibility checks
    -> C_PartyInfo.InviteUnit(original chat author)
    -> Log API call, never claim delivery confirmation
```

The addon has no polling loop, external dependencies, background service, web connection, or extra delay before the invite call. Normalization is proportional to message length; hash lookup is expected O(1), independent of whitelist size. A periodic cache cleanup occurs on chat events, not via a timer. The last-message cache keeps at most 2,048 names for up to 15 minutes (older entries can be evicted earlier at capacity). Cooldown records are also pruned. Counters reset on UI reload. Debug logging can be noisy in active chat; turn debug off for ordinary use only after the controlled test.

### Matching rules

* Expand readable `|Henchant:...|h[...]|h` links into visible text, remove color markers, and strip an `Enchanting:` prefix inside those links.
* Lowercase; remove complete gold amounts such as `30g`, `30 gold`, `30gold` and `2.5g`; split glued numeric/stat tokens such as `15agi`.
* Strip punctuation, canonicalize explicit aliases (e.g. `enchater` -> `enchant`, `agi` -> `agility`, `wrist` -> `bracer`), and discard existing filler tokens such as `my`, `mats`, `tip` and `pst`.
* Concatenate remaining tokens without spaces, preserving their order; compare the whole resulting key against stored keys.

For a whitelist of `LF enchanter 15 agility gloves`, `LF enchater 15agi glove my mats 20g tip` matches; `LF enchanter 7 agility gloves` and `LF enchanter 15 agility weapon` do not. `LF` and `looking for` are not currently interchangeable. Different word orders are not automatically equivalent. Whitelist variants explicitly. No fuzzy or substring matching was added, and no general WTS ban was introduced: a sale phrase would match if you explicitly whitelist its normalized key. Space removal can create collisions between differently tokenized phrases; inspect `/ae test` before adding ambiguous entries. Alias and filler rules are English-oriented. The whitelist, not known recipes, is authoritative.

### Channels, identities, and learning

`CHAT_MSG_CHANNEL` argument 7 is the zone channel ID (General=1, Trade=2); argument 8 is the user's local channel slot, not a stable type. SAY and YELL are also monitored. Custom channels, whispers, guild and party chat are not monitored. The full incoming author string is passed unchanged to the invite API. For cache/cooldown keys, the string is lowercased and spaces/hyphens are treated equivalently, never truncating a surname. Own GUID/name are used to exclude self messages. Real-client formatting and channel IDs should be checked during acceptance.

When enabled, right-click learning adds the most recently cached eligible chat message from that full name, not necessarily the exact historical line clicked. The text is captured when the menu opens, and the entry is only offered for recent cached messages. This can work even with `/ae off`. If a client menu tag or identity format differs, use `/ae add <phrase>`; no invite depends on the menu. The Menu.ModifyMenu callback contract, registered unit menu tags, and Forever surname context field were source-checked; actual right-click behavior still needs live verification.

### Invitation restrictions and diagnostics

Native `C_PartyInfo.InviteUnit(targetName)` has a valid-target restriction and no return value confirming success. Party checks use `CanInvite()`, `IsPartyFull()` and `IsGUIDInGroup(guid)` where available. Errors and inaccessible values from available eligibility checks suppress invites; secret chat fields are never parsed. No legacy InviteUnit fallback or automatic confirmation is used. An explicit invite-related `ADDON_ACTION_BLOCKED` or `ADDON_ACTION_FORBIDDEN` attributed to AutoEnchanter disables further invite attempts for that UI session. A silent server rejection may not generate an observable block event. Use the game's native player menu or manually type `/invite` if appropriate; respect game restrictions. A matching chat author is not necessarily an eligible invite target. Debug mode cannot validate the actual invite call.

`scanned` counts messages evaluated while enabled with a nonempty whitelist; `matches` counts matching evaluations before cooldown; `invite API calls` counts attempted native calls (including failures); `cooldown skips` counts repeated matches inside the per-name cooldown; `restricted` counts unreadable message/name/GUID payloads. Diagnostics additionally reports simulated, failed and ineligible counts. A blocked event may occur without an exception. None of these counters confirm receipt or acceptance.

## Test and release procedure

From the source repository root, run `lua5.1 tests/regression.lua` (or `lua5.4 tests/regression.lua`). CI runs both versions on pushes and pull requests. This audit executed the suite with Lua 5.4 in an offline mocked client, not Blizzard's runtime. See `API-AUDIT.md` and `TEST-RESULTS.txt`. CI is supplied but has not yet executed on GitHub. The mock covers event flow, aliases, price parsing, negative matches, duplicate entries, secret fields, channel numbering, name preservation, cooldown, full party, permission failure, existing members, debug, disabled mode, menus, missing APIs, errors and blocked invites. It also processes a 10,000-message unrelated workload. The mock does not reproduce Blizzard's protected runtime, native menu tag dispatch, real server responses, or network latency.

### Live acceptance checklist (not yet performed)

1. `/console scriptErrors 1`, `/reload`, `/ae diagnostics`. Record the version/build/interface and verify native invite API and menu API are functions. Run `/ae list` and confirm expected entries.
2. `/ae on`, `/ae debug on`. With a consenting second player, post an exact whitelisted request in Trade (including when Trade is not slot 2); repeat in General, Say and Yell. Verify the simulation log. Try a wrong enchant and a custom channel; neither should match.
3. Check a two-part name, another player with the same first name if feasible, and right-click learning while disabled. Test `/ae test` and remove the temporary whitelist entries afterwards.
4. `/ae debug off` with a consenting second player, outside restricted content. Wait over seven seconds after the previous match. Confirm **on the recipient's client** that the invitation arrives, not merely the API call log. Test a repeat inside the cooldown and a different player. Test full party, existing member, and lack of invite permission if feasible.
5. If a game block occurs, verify the addon stops further attempts. Do not attempt to bypass it. Record `/ae status`, `/ae diagnostics`, exact error text, and the chat channel/name format (redact personal data as needed). Use debug on or disable until resolved.
6. Logout/reload and confirm whitelist/settings survive. Restore your preferred settings.

## Project layout

- `AutoEnchanter/`: only files required by the game.
- `README.md`: documentation, commands, behavior and acceptance checklist.
- `API-AUDIT.md`: source-backed interface review and remaining uncertainties.
- `tests/regression.lua`: reproducible offline regression test.
- `TEST-RESULTS.txt`: actual local run output.
- `CHANGELOG.md`: release changes.
- `.github/workflows/tests.yml`: automated checks for future changes.

Keep the source repository private. Do not commit the `WTF` directory, actual account SavedVariables, credentials, or chat logs. No public distribution license was assigned to your original code.
