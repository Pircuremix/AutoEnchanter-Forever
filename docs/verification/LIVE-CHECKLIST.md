# Live acceptance checklist — v1.6.1

Status: **not yet verified in the live client**. Use consenting test players, back up SavedVariables, and record the installed version/client build from /ae diagnostics. Keep names, GUIDs, account data and trade/chat logs private. Use debug for dry runs, then turn debug off only for controlled live tests.

| Area | Test | Expected |
|---|---|---|
| Installation | WowUp refresh/update, restart WoW, /ae diagnostics | 1.6.1; whitelist and settings preserved |
| Dashboard | Minimap left/right/Shift-left, Settings and Blacklist tabs, search/sort | Correct interaction; EllesmereUI Free Move off for Shift-left |
| Matching | Valid whitelist requests, wrong phrases, full surnames, General/Trade | Only exact normalized matches; correct native invite |
| Acceptance | Accepted invite, repeated roster events | One accepted record and normal configured welcome |
| Decline | Explicit decline, repeat request during cooldown | Verified decline, 30-minute suppression |
| Availability | Already grouped, busy/pending invite, unnamed async failure | Separate grouped/busy where attributable; never a decline from ambiguous evidence |
| Expiry | Confirmed sent vs no delivery proof, wait 120 seconds | Confirmed expires; ambiguous becomes unverified |
| Guild | Login with valid guild roster, member departure, roster refresh | Cache updated; former guild member not exempt |
| Whisper | Configured guild text, empty field, disabled toggle | Invite first; exact configured whisper if permitted; no whisper when blank/off; normal welcome unchanged |
| Welcome templates | Insert tokens; preview; accept while unmarked, marked skull, and after raid conversion | Actual current marker; full customer name; preview local only; no false icon |
| Group | Party at 3, raid conversion, existing marker | Correct channel and preserved marker; native restrictions respected |
| Trades | Gold-only, gold+materials, outgoing items/gold, cancellation, delivered enchant, separate tip | Correct qualifying totals, uncertain events flagged |
| No-trade departure | Leave/kick without trade; repeat with confirmed materials exchange | 30-minute cooldown after settlement only for no verified exchange |
| Policy | Inspect blacklist deadlines, history, confirmed removal | Applicable deadline and history retained |
| Persistence | Reload/logout after controlled records | Schema 2, tips/history/settings retained |
| Performance | /ae performance after real calls | Local timing samples; no network-latency claim |

The long-duration 30/90/180-day penalties and 10-day repeat decline bans are covered by simulated clock regression tests; do not alter the system clock or live player history to force them. Confirm live evidence classification and review actual restrictions when naturally applicable. If a legitimate trade is unverified, use /ae tradetrace on/dump/off and /ae ledgerstatus before relying on non-tipping bans. No bypass of Blizzard restrictions.

## Recording a result

- Addon version and client build:
- UI (default/EllesmereUI version):
- Test and expected behavior:
- Observed result (pass/fail/unverified):
- Redacted diagnostics:
- Date tested:

Save live observations separately, e.g. verification/live-v1.6.1.md. Update the verification index only after results are observed.
