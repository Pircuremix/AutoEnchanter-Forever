# Trade and delivered enchant evidence

1.5.0 uses a conservative read-only transaction observer. This is a release candidate for Forever live acceptance; mocked event ordering is not proof that every live trade produces the same signals.

## Inputs

- TRADE_SHOW: identify trade partner via UnitGUID("npc") (native TradeFrame uses NPC unit for recipient). Only active accepted ledger visit for the same current enchanter qualifies.
- GetTargetTradeMoney / GetPlayerTradeMoney: incoming/outgoing copper.
- GetTradePlayerItemInfo / GetTradeTargetItemInfo: regular slots 1–6 and non-traded enchant slot 7. Native target enchant is return 6; player enchant is return 5. Currency getters are inspected if exposed.
- TRADE_ACCEPT_UPDATE: capture final readable offers when both accept; invalidate when offers change.
- UI_INFO_MESSAGE, UI_ERROR_MESSAGE, CHAT_MSG_SYSTEM: compare readable text to localized ERR_TRADE_COMPLETE / ERR_TRADE_CANCELLED (or CANCELED).
- TRADE_CLOSED: retain snapshot for two seconds to allow explicit success message after closure. Closure alone is not success. If no explicit evidence, save unverified zero-count record. New trade while unresolved makes attribution ambiguous.
- ENCHANT_SPELL_COMPLETED and player UNIT_SPELLCAST_SUCCEEDED: optional trace only, never sufficient to count delivery.

Source evidence: [Forever TradeFrame.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_UIPanels_Game/Mainline/TradeFrame.lua), blob ff8e5416f0d56e007867ec6656498950c3491443; [TradeInfoDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeInfoDocumentation.lua), blob f44c116fc13f2b550e2f49cc1738e771d44c6be9; [MoneyFrame.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_MoneyFrame/Shared/MoneyFrame.lua); [SpellDocumentation.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellDocumentation.lua), blob 9395b8da63a8a49ff073d18a847cb87c1dd235da. Explicit trade-complete signal is a known WoW pattern, but the Forever event sequence must be verified in-game.

## Accounting rules

A verified trade needs a unique tracked partner, final both-accepted readable snapshot and explicit completion message. Never credit based on wallet delta, cast success, both accepts alone or close alone. One snapshot is consumed once. If completion is ambiguous, record zero and unverified; explicit cancellation discards the staging record.

Tip: positive incoming gold and zero outgoing money, no transferred items on either side, no incoming enchant service, no other visible currency. Your enchant service in the target non-traded slot is allowed. Incoming materials plus money, item sales, barter and outgoing change do not count. Separate payment within the active visit is allowed.

Enchant: at most one final nonempty target-slot enchant on a customer's non-traded item per verified completed trade; no count for own gear, scroll crafting, failed casts or canceled trades. Repeated applications before the same completed trade count once. A verified unpaid enchant counts toward the denominator. If live Forever supplies different information, prefer undercounting and flagging uncertainty rather than fabricating income. No manual correction UI is provided in this release; preserve the database for review.

## Live acceptance procedure

Use consenting test players and note known exact amounts. /ae tradetrace on records up to 80 recent event names, relative times and state flags (no names, chat text or money); /ae tradetrace dump prints locally, clear resets, off disables. Open /ae database and compare individual invitation record. Try gold only, materials plus gold, outgoing item, outgoing copper, cancel, both accepted then cancel, separate payment, two completed customer enchants, own enchant and untracked trader. If a completed trade becomes unverified, capture the event trace and client build. Do not loosen completion requirements merely to make totals move. Test after reload and with multiple accepted customers.
