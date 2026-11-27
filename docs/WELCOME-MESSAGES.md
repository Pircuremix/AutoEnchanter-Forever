# Welcome message templates — 1.6.1

Open /ae settings, edit Welcome message, click placeholder buttons to insert at the cursor, and Save or press Enter. The shared native addon settings canvas has the same controls.

| Token | Value |
|---|---|
| {CUSTOMER} | Full name recorded from the customer's original chat message |
| {MARKER} | Native raid icon token {rt1} through {rt8} from actual current player mark |
| {MARKER_NAME} | English name: Star, Circle, Diamond, Triangle, Moon, Square, Cross, Skull |
| {PLAYER} | Your character name from UnitName |
| {ZONE} | Current zone |

Example: `/ae message Hey {CUSTOMER}, find me at {MARKER}. Please open trade when you're ready.`

Tokens are case-insensitive and require braces; plain words remain literal. Old lowercase templates still work. Unknown tokens, including native raid icon tokens, remain unchanged. Substitution is single-pass, not script execution. Saved and expanded messages must each be single-line, at most 255 bytes and free of control characters. Invalid expanded output is skipped rather than truncated. Empty text suppresses welcome.

After observed acceptance (and any existing raid conversion wait), Group:Flush first attempts safe optional marking. From 1.6.3, an incomplete roster can defer the first call by 0.35 seconds and a native call without observed marker can defer the welcome up to one second, ending early on RAID_TARGET_UPDATE. Group:SendWelcome then reads current player marker through GetRaidTargetIndex. Existing/manual marks are preserved. If nil/zero, use (no marker); if unavailable, secret, error or invalid index, use (marker unavailable). Never claim an unobserved mark. Native chat receives the numeric token, not texture markup. No retries or extra work before InviteUnit.

Settings preview uses unsaved edit text, sample name Example Customer, and current actual marker, updating on text edits and visible RAID_TARGET_UPDATE. /ae preview [customer name] uses the saved template and optionally a supplied sample name. Both are local only; native ReplaceIconAndGroupExpressions renders icons where available, otherwise shows the raw token. Preview never sends chat, marks, invites, or changes settings. Normal guild whisper is independent and unchanged.

Live test: set a welcome with CUSTOMER/MARKER/MARKER_NAME, preview, then invite a consenting customer with no mark and auto-marker enabled. Confirm actual icon in PARTY; manually change to Skull and invite another, confirm Skull remains. Turn marking off and remove mark: verify fallback. Confirm RAID routing after conversion. Native marker rendering may differ by client/chat settings; mock tests verify outgoing token only.
