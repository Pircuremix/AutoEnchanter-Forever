# AutoEnchanter — WoW Forever

[![Latest release](https://img.shields.io/github/v/release/Pircuremix/AutoEnchanter-Forever)](https://github.com/Pircuremix/AutoEnchanter-Forever/releases/latest) [![Lua regression tests](https://github.com/Pircuremix/AutoEnchanter-Forever/actions/workflows/tests.yml/badge.svg)](https://github.com/Pircuremix/AutoEnchanter-Forever/actions/workflows/tests.yml) [![Publish Forever release](https://github.com/Pircuremix/AutoEnchanter-Forever/actions/workflows/release.yml/badge.svg)](https://github.com/Pircuremix/AutoEnchanter-Forever/actions/workflows/release.yml)

AutoEnchanter is an independent enchanting customer-management addon for **World of Warcraft: Forever** (target interface 16001). Original author: Sleepy. Current source version: **1.5.0**.

[Download latest release](https://github.com/Pircuremix/AutoEnchanter-Forever/releases/latest) · [WowUp guide](docs/WOWUP.md) · [Changelog](CHANGELOG.md) · [Version notes](docs/releases/README.md) · [Architecture](docs/ARCHITECTURE.md) · [API audit](API-AUDIT.md) · [Report an issue](https://github.com/Pircuremix/AutoEnchanter-Forever/issues)

## Features

- Local customer database with individual invite history, accepted/declined/expired counts, verified gold tips and delivered enchant counts.
- Searchable, sortable customer dashboard, weighted average per item, date filters, TSV export, and confirmed deletion/reset.
- Minimap button: left-click dashboard, Shift-left toggle AE, right-click two-option menu. EllesmereUI-compatible discovery; Free Move Buttons can intercept Shift-left.

- Event-driven General, Trade, Say and Yell monitoring; conservative normalized exact matching against a manually maintained whitelist.
- Immediate native party invite requests, full Forever names, seven-second per-player cooldown and right-click whitelist learning.
- Optional welcome message **only after an addon-invited customer's GUID is observed in the group**; automatically uses PARTY or RAID at send time.
- Optional configurable self-marker, preserving any existing marker on yourself and not deliberately taking a selected marker from another observable group member.
- Optional automatic conversion of an ordinary party to a raid at a configurable threshold (default three total players including yourself).
- Native in-game settings panel, account-wide persistence, debug mode and diagnostics.
- Custom enchanting icon, Professions category, tested versioned releases and WowUp distribution.

The addon does not cast enchants, inspect your recipe book, advertise, send whispers, guarantee delivery of invitations or bypass Blizzard restrictions.

## Install or upgrade

**Recommended — WowUp:** select Forever, import `https://github.com/Pircuremix/AutoEnchanter-Forever` and enable Auto Update. The repository is public; no token is required. See [WowUp setup and troubleshooting](docs/WOWUP.md).

Manual: download the named addon ZIP from [Releases](https://github.com/Pircuremix/AutoEnchanter-Forever/releases/latest), not the source archive. Close WoW, back up your old addon and SavedVariables, and extract the AutoEnchanter folder into the Forever client's Interface/AddOns directory. The runtime files are:

```text
Interface/AddOns/AutoEnchanter/
  AutoEnchanter.toc
  Database.lua
  Trade.lua
  Group.lua
  Settings.lua
  Dashboard.lua
  Minimap.lua
  AutoEnchanter.lua
  AutoEnchanterIcon.blp
```

Do not install release.json or the test/docs folders. Start WoW and enable Auto Enchanter under Professions. Run `/ae diagnostics` and `/ae list`.

### Set up the new features

Open **Escape > Options > AddOns > Auto Enchanter**, or type `/ae settings` (also `/ae config`) to open the new dashboard's Settings tab. All three new features default to **off**, including when upgrading from 1.3.x. Existing settings are preserved.

| Setting | Default | Behavior |
|---|---|---|
| Send welcome message | Off | A single message per observed matching pending customer |
| Welcome text | Thanks for choosing me for your enchant! | Edit and press Save or Enter; single line, max 255 bytes |
| Self-marker | Off | Only attempt if currently unmarked; never clears an icon |
| Selected marker | 1 (Star) | Choose any of the eight native raid target icons |
| Auto raid conversion | Off | Ordinary party, leader only; never converts a raid back to party |
| Conversion threshold | 3 | Select 2–5 total players, including yourself |

Message placeholders: `{customer}` (original chat name), `{player}` (character's first/name API value), `{zone}` (current zone). Unknown placeholders remain literal. Expanded text over 255 bytes is skipped, not truncated. Empty/whitespace-only text disables sending but not marking. Channel selection is automatic; no public-chat or whisper fallback.

Example: `Welcome {customer}! Please come to me in {zone} and open trade when ready.`

Checkboxes and marker/threshold choices save immediately. The welcome text is saved explicitly. If the Settings API is unavailable, the slash commands below configure the same database. Settings changes take effect on subsequent roster events; disabling the addon or entering debug clears pending customer actions. Start with `/ae debug on` and use the live checklist before enabling real actions with `/ae debug off`.

### Group behavior

An invite request is not proof of acceptance. The addon records only a real, nonfailed invite call with a readable GUID and a prior negative membership check. On roster events it matches that GUID to another group member. Pending records expire after 120 seconds and are bounded to 128. A customer who declines, never joins, or joins after expiry is not welcomed. A manual invite to someone with an existing matching pending request cannot be distinguished from that request. No name-only fallback is used.

For example, with all three features enabled and threshold 3:

1. First customer joins: welcome in PARTY and request self-marker only if safe.
2. Second customer joins: party reaches three actual members; request conversion once. Hold the welcome until raid membership is observed or five seconds elapse.
3. If conversion is observed, welcome in RAID; otherwise send through the current confirmed group type, provided the customer is still present. Subsequent customers in the raid receive RAID messages.
4. When people leave, the addon never converts a raid back to a party.

Automatic conversion also applies to ordinary parties with manually invited members if the feature is enabled, including on entering the world or a leader change. It is not limited to an enchanting session. It is not attempted inside an instance or in instance groups, or by nonleaders. The welcome system skips instance groups; it never uses INSTANCE_CHAT. Native confirmation prompts are respected; conversion may interrupt ordinary quest progress. An outstanding conversion is not repeatedly requested. See [architecture](docs/ARCHITECTURE.md) for state and timing details.

### Saved settings and TBC migration

Account-wide `AutoEnchanterDB` remains the only SavedVariables table. New fields are initialized without replacing valid old whitelist/settings. Pending requests, timers, block flags and counters are session-only. To copy a TBC whitelist, close both clients, back up the destination, and copy the old account's SavedVariables/AutoEnchanter.lua into the equivalent Forever account directory. Do not confuse it with addon source. Copying replaces the destination table. Never upload real SavedVariables or chat logs.

## Customer database and business dashboard (1.5.0)

Click the minimap icon or type `/ae database` to open the Business Manager. The customer table has clickable sort headings, case-insensitive search, customer filters, and date filters (lifetime, today, last 7/30 days). Select a row to see individual invitation history; use Prev/Next to page. Overview summarizes the selected filters. Settings reuses the native automation controls and adds whitelist, debug and minimap controls. The title bar can be dragged; +/- adjusts the window scale. Export TSV opens a local copyable text field; no network or clipboard write is performed. Delete selected and Reset database require a second click.

The ledger automatically records actual AE invitation requests while AE is enabled and not in debug mode, independently of welcome/marker options. It continues observing the outcomes and trades of previously tracked visits even after AE is switched off; no new invite is created while off. The history stores a local date/time string at invitation, a numeric epoch, enchanter identity and customer GUID. Accepted requires observed membership; localized decline or 120-second expiry counts toward declines. Failed, unverified and overlapping superseded requests are visible separately, not counted as customer rejections. Pending invites persist if SavedVariables is successfully saved and are reconciled on reload. An offline acceptance not observable by the client cannot be reconstructed.

Only a confirmed completed trade with a tracked, active accepted customer can contribute tips and items. Positive incoming money, no outgoing money, no transferred items in either direction, no incoming enchant/currency: count the gold. Your outgoing enchant on the customer's non-traded slot 7 is a service, not an outgoing item. Each explicitly completed final enchant in that slot contributes one item, including unpaid enchants. Separate qualifying payments in the same visit are added. A canceled trade or an ambiguous final snapshot never increases totals. Trade closure or both players clicking Accept alone is insufficient; if the live client doesn't provide explicit completion evidence, an unverified entry is recorded and excluded from statistics. Average is total integer copper divided by completed items, not by visits; display — if no items.

Use `/ae tradetrace on` and `/ae tradetrace dump` to investigate event order locally. No player names, chat text or monetary details are included in the trace. The customer database is stored only in account SavedVariables, not uploaded to GitHub. There is no historical backfill. See [database schema](docs/DATABASE.md), [trade evidence](docs/TRADE-TRACKING.md), and [UI compatibility](docs/UI-COMPATIBILITY.md).

**EllesmereUI:** the 30px named Minimap child can be discovered by its normal addon-button scan/flyout. If Free Move Buttons is enabled, its Shift-left gesture takes precedence. Disable that setting to use Shift-left toggle, or use the right-click menu / slash commands. Actual visual compatibility still requires live testing.

## Commands

Both `/ae` and `/autoenchanter` are supported.

| Command | Behavior |
|---|---|
| `/ae on`, `/ae enable` | Enable addon |
| `/ae off`, `/ae disable` | Disable live actions and clear pending welcomes |
| `/ae add <phrase>` | Add an exact normalized whitelist phrase |
| `/ae remove <index or phrase>` | Remove an entry |
| `/ae list` | List phrases and normalized keys |
| `/ae test <phrase>` | Inspect match without inviting |
| `/ae debug [on/off]` | Simulation mode; no actual invites, chat, markers or conversion |
| `/ae popup [on/off]` | Right-click whitelist learning |
| `/ae settings`, `/ae config` | Open native settings |
| `/ae welcome on/off` | Enable or disable welcome chat |
| `/ae message <text>` | Save welcome text (empty clears it) |
| `/ae marker on/off/1-8` | Toggle or enable/select self-marker |
| `/ae raid on/off/2-5` | Toggle or enable/set conversion threshold |
| `/ae database`, `/ae dashboard` | Open customer database |
| `/ae ledgerstatus` | Ledger and trade-evidence counters |
| `/ae tradetrace on/off/dump/clear` | Bounded local event-order diagnostics |
| `/ae minimap show/hide` | Show or hide minimap icon |
| `/ae groupstatus` | Group settings, pending records and action counters |
| `/ae status` | Original matching/invite counters |
| `/ae diagnostics`, `/ae diag` | Client build, invite availability and group diagnostics |

## Matching and restrictions

### Matching rules

* Expand readable `|Henchant:...|h[...]|h` links into visible text, remove color markers, and strip an `Enchanting:` prefix inside those links.
* Lowercase; remove complete gold amounts such as `30g`, `30 gold`, `30gold` and `2.5g`; split glued numeric/stat tokens such as `15agi`.
* Strip punctuation, canonicalize explicit aliases (e.g. `enchater` -> `enchant`, `agi` -> `agility`, `wrist` -> `bracer`), and discard existing filler tokens such as `my`, `mats`, `tip` and `pst`.
* Concatenate remaining tokens without spaces, preserving their order; compare the whole resulting key against stored keys.

For a whitelist of `LF enchanter 15 agility gloves`, `LF enchater 15agi glove my mats 20g tip` matches; `LF enchanter 7 agility gloves` and `LF enchanter 15 agility weapon` do not. `LF` and `looking for` are not currently interchangeable. Different word orders are not automatically equivalent. Whitelist variants explicitly. No fuzzy or substring matching was added, and no general WTS ban was introduced: a sale phrase would match if you explicitly whitelist its normalized key. Space removal can create collisions between differently tokenized phrases; inspect `/ae test` before adding ambiguous entries. Alias and filler rules are English-oriented. The whitelist, not known recipes, is authoritative.

### Channels, identities, and learning

`CHAT_MSG_CHANNEL` argument 7 is the zone channel ID (General=1, Trade=2); argument 8 is the user's local channel slot, not a stable type. SAY and YELL are also monitored. Custom channels, whispers, guild and party chat are not monitored. The full incoming author string is passed unchanged to the invite API. For cache/cooldown keys, the string is lowercased and spaces/hyphens are treated equivalently, never truncating a surname. Own GUID/name are used to exclude self messages. Real-client formatting and channel IDs should be checked during acceptance.

When enabled, right-click learning adds the most recently cached eligible chat message from that full name, not necessarily the exact historical line clicked. The text is captured when the menu opens, and the entry is only offered for recent cached messages. This can work even with `/ae off`. If a client menu tag or identity format differs, use `/ae add <phrase>`; no invite depends on the menu. The Menu.ModifyMenu callback contract, registered unit menu tags, and Forever surname context field were source-checked; actual right-click behavior still needs live verification.

### Invitation restrictions and diagnostics (existing matcher)

Native `C_PartyInfo.InviteUnit(targetName)` has a valid-target restriction and no return value confirming success. Party checks use `CanInvite()`, `IsPartyFull()` and `IsGUIDInGroup(guid)` where available. Errors and inaccessible values from available eligibility checks suppress invites; secret chat fields are never parsed. No legacy InviteUnit fallback or automatic confirmation is used. An explicit invite-related `ADDON_ACTION_BLOCKED` or `ADDON_ACTION_FORBIDDEN` attributed to AutoEnchanter disables further invite attempts for that UI session. A silent server rejection may not generate an observable block event. Use the game's native player menu or manually type `/invite` if appropriate; respect game restrictions. A matching chat author is not necessarily an eligible invite target. Debug mode cannot validate the actual invite call.

`scanned` counts messages evaluated while enabled with a nonempty whitelist; `matches` counts matching evaluations before cooldown; `invite API calls` counts attempted native calls (including failures); `cooldown skips` counts repeated matches inside the per-name cooldown; `restricted` counts unreadable message/name/GUID payloads. Diagnostics additionally reports simulated, failed and ineligible counts. A blocked event may occur without an exception. None of these counters confirm receipt or acceptance.

Group automation separately checks readable roster identity, chat lockdown, existing marks, raid permissions and native API outcomes. It never uses force-confirm conversion, automatically accepts a dialog, clears a raid marker, or retries blocked actions in a loop. Native calls are attempts, not proof of chat delivery, marker visibility or conversion; only a later observed raid state confirms conversion. Debug mode logs simulated invite and eligible conversion actions; because it sends no invites, it creates no real pending welcomes.

## Test and release procedure

Run `bash scripts/test.sh 5.1` and `bash scripts/test.sh 5.4` from the repository root (Lua and luac installed). Run `bash scripts/package.sh` with zip, unzip and jq installed. GitHub Actions executes both versions and validates the exact install archive before publication. The historic v1.3.0 local run remains in TEST-RESULTS.txt; current CI status is linked at the top. Offline mocks validate control flow, not Blizzard's protected runtime or server delivery.

### Live acceptance checklist

1. Restart WoW, enable Auto Enchanter and run `/console scriptErrors 1`, `/ae diagnostics`, `/ae list`. Verify the settings panel opens and saves; reload to confirm persistence.
2. With consenting test players, verify whitelist match/debug behavior in General/Trade (including moved slots), Say/Yell, wrong requests and two-part names. Test right-click learning. Switch debug off only for the controlled live test.
3. Enable welcome and self-marker. Send a valid invite but delay acceptance: no message or mark until the customer joins. Verify actual receipt on their client. Try unrelated/manual join, duplicate roster events, expired request and two different customers.
4. Start unmarked; verify selected self-marker. Then manually set a different icon and invite another customer: it must remain unchanged. Check another party member holding the chosen icon. Test raid leader/assistant and nonleader behavior.
5. Enable auto raid at 3. Invite two customers: at two total remain in a party, at three total request conversion once; confirm the raid appears before the second welcome is sent in RAID. Test an already formed raid, decline/confirmation cases, a threshold of 4, nonleader and group shrinking. Do not force-confirm or bypass a blocked action.
6. If any action is blocked, record version, build, diagnostics, groupstatus and exact error (redact names). Disable the affected feature until resolved. Verify WowUp updates independently from in-game behavior.

7. Test v1.5.0 with a consenting customer: invite/decline/expire, successful gold-only payment, canceled trade, gold plus materials, outgoing item or money, and two completed non-traded enchants followed by separate payment. Verify exact database totals and trace the event sequence if any completed trade is unverified. Test reload, customer sorting, export, and all three minimap gestures in default UI and EllesmereUI (Free Move Buttons off).

**Live client acceptance of 1.4.0 group automation and 1.5.0 trade/UI behavior is not yet independently verified.** The API and mock checks are necessary but not sufficient.

## Project documentation

- [Architecture and contracts](docs/ARCHITECTURE.md)
- [Database schema](docs/DATABASE.md) · [Trade tracking](docs/TRADE-TRACKING.md) · [UI compatibility](docs/UI-COMPATIBILITY.md)
- [WowUp integration](docs/WOWUP.md)
- [Version notes](docs/releases/README.md) — one file per published version
- [Changelog](CHANGELOG.md) — chronological summaries
- [API audit](API-AUDIT.md) — verified source and restrictions
- [Maintainer / AI contributor guide](AGENTS.md)
- `tests/`, `scripts/` and `.github/workflows/` — test and release tooling

Public visibility does not assign a license. No redistribution license has been selected. Never commit real SavedVariables, credentials or private chat logs. Not affiliated with Blizzard or WowUp.
