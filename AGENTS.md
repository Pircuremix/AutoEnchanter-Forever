# Maintainer and AI contributor instructions

Start with docs/README.md and the latest docs/verification/ record. Read README.md, docs/ARCHITECTURE.md, API-AUDIT.md, docs/WOWUP.md, CHANGELOG.md and the most recent file under docs/releases/ before changing code. Inspect the current GitHub branch and actual code, not only old conversation summaries. The source repository is the source of truth.

## Nonnegotiable contracts

- Preserve normalized exact whitelist semantics and existing account-wide SavedVariables. Do not add broad fuzzy/substring matching without approval.
- Keep invite hot path event-driven and fast. Do not delay the native invite for unrelated features.
- Keep customer acceptance correlation GUID-based and bounded; never send a welcome on invite alone, never duplicate a welcome for repeat roster events.
- Only use native allowed APIs. Do not bypass chat/secret-value/protected action restrictions, force confirmation, remove existing markers or convert raids back automatically.
- Keep new optional automation off by default unless explicitly requested otherwise. Debug/master off suppress real actions. Preserve all existing settings on upgrades.
- No real player data, credentials, tokens, SavedVariables or chat logs in this public repository. Do not choose a redistribution license without owner authorization.

## Business ledger invariants (1.5.0)

Read docs/DATABASE.md, docs/TRADE-TRACKING.md and docs/UI-COMPATIBILITY.md before touching ledger/UI modules. Never infer money from wallet delta, count accept/close alone as completed trade, or count spellcast alone as delivered enchant. Keep the final explicitly confirmed trade snapshot and single-use attribution to active GUID/owner visit. Never count failures as declined or one acceptance twice. Keep numeric copper and weighted averages, preserve schema and local timestamp history. No real player data in fixtures. Do not override EllesmereUI layout hooks. Test both Lua runtimes and distinguish model/dispatch mocks from real UI rendering. /ae tradetrace is bounded and local; no raw chat/name/money. Add a version note for every release.

## Customer policy invariants (1.6.0)

Read docs/CUSTOMER-POLICY.md, INVITE-OUTCOMES.md and PERFORMANCE.md. Never classify already grouped/busy or unconfirmed timeout as a decline. Confirm sent evidence before expiry penalty; no retroactive legacy bans. Preserve independent absolute restriction deadlines and offense history. Guild roster complete replacement, tri-state identity, guild exemption only for non-tipping. Empty/whitespace guild whisper never sends; native invite first and normal welcome remains separate. Never issue penalties on ambiguous trade evidence, incomplete restored visits or historical unpaid visits. Lifetime positive tips exempt from non-tipping policy. No scans/UI/guild requests before native invite. Run policy suite/benchmarks, preserve real-player privacy and document limitations.

## Implementation workflow

1. Check the exact current branch, API source for the Forever client, and existing tests. Update docs/ARCHITECTURE.md if contracts or modules change.
2. Use a short-lived branch for nontrivial changes. Make each buildable commit self-contained: new runtime Lua modules, TOC load-order entries, and affected test fixtures belong in the same commit. Before pushing, run syntax/test/package checks locally if available; otherwise use branch CI as the gate. Never disable packaging validation to avoid notification noise. Write regression tests for positive, negative and restriction paths; include settings migration and live-vs-mock distinctions.
3. Run bash scripts/test.sh 5.1, bash scripts/test.sh 5.4 and bash scripts/package.sh, locally if available or in branch CI. Inspect actual results. Never claim a live game test from mocks.
4. For an addon release, bump TOC and Lua version strings together, update README, CHANGELOG.md, API-AUDIT.md as appropriate, and create docs/releases/vX.Y.Z.md with summary, migration, defaults, tests, limitations and affected files. Update docs/releases/README.md index. Keep existing notes historical, do not silently rewrite history.
5. Fast-forward/merge to main only once checks pass. Release workflow uses that exact version note as GitHub release body, packages all runtime modules and attaches release.json. Verify both assets and workflow completion; don't claim published until GitHub confirms. Documentation-only changes do not require version bump.
6. After publication, create docs/verification/vX.Y.Z.md and update its index with tested commit, exact counts, run URLs, assets, benchmarks where relevant, resolved CI failures and live acceptance status. Preserve published release notes and package bytes; post-release evidence belongs in verification records. Verify WowUp release detection when possible and separately verify in-game behavior with consenting players. Record actual acceptance results and failures with version/build. A failed release workflow must be corrected and rerun; don't edit or overwrite published assets for the same version without a justified explicit decision.

## Documentation map

docs/README.md = documentation navigation and source-of-truth map. docs/verification/ = release evidence and live checklist. README.md = player guide. docs/ARCHITECTURE.md = implementation and invariants. API-AUDIT.md = source evidence and uncertainty. docs/WOWUP.md = distribution. CHANGELOG.md = concise chronological history. docs/releases/vX.Y.Z.md = detailed immutable version notes and release body. tests/ = reproducible evidence. TEST-RESULTS.txt = historical 1.3.0 offline run only. Current CI results are linked from GitHub Actions.
