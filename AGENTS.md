# Maintainer and AI contributor instructions

Read README.md, docs/ARCHITECTURE.md, API-AUDIT.md, docs/WOWUP.md, CHANGELOG.md and the most recent file under docs/releases/ before changing code. Inspect the current GitHub branch and actual code, not only old conversation summaries. The source repository is the source of truth.

## Nonnegotiable contracts

- Preserve normalized exact whitelist semantics and existing account-wide SavedVariables. Do not add broad fuzzy/substring matching without approval.
- Keep invite hot path event-driven and fast. Do not delay the native invite for unrelated features.
- Keep customer acceptance correlation GUID-based and bounded; never send a welcome on invite alone, never duplicate a welcome for repeat roster events.
- Only use native allowed APIs. Do not bypass chat/secret-value/protected action restrictions, force confirmation, remove existing markers or convert raids back automatically.
- Keep new optional automation off by default unless explicitly requested otherwise. Debug/master off suppress real actions. Preserve all existing settings on upgrades.
- No real player data, credentials, tokens, SavedVariables or chat logs in this public repository. Do not choose a redistribution license without owner authorization.

## Implementation workflow

1. Check the exact current branch, API source for the Forever client, and existing tests. Update docs/ARCHITECTURE.md if contracts or modules change.
2. Use a short-lived branch for nontrivial changes. Write regression tests for positive, negative and restriction paths; include settings migration and live-vs-mock distinctions.
3. Run bash scripts/test.sh 5.1, bash scripts/test.sh 5.4 and bash scripts/package.sh, locally if available or in branch CI. Inspect actual results. Never claim a live game test from mocks.
4. For an addon release, bump TOC and Lua version strings together, update README, CHANGELOG.md, API-AUDIT.md as appropriate, and create docs/releases/vX.Y.Z.md with summary, migration, defaults, tests, limitations and affected files. Update docs/releases/README.md index. Keep existing notes historical, do not silently rewrite history.
5. Fast-forward/merge to main only once checks pass. Release workflow uses that exact version note as GitHub release body, packages all runtime modules and attaches release.json. Verify both assets and workflow completion; don't claim published until GitHub confirms. Documentation-only changes do not require version bump.
6. Verify WowUp release detection when possible and separately verify in-game behavior with consenting players. Record actual acceptance results and failures with version/build. A failed release workflow must be corrected and rerun; don't edit or overwrite published assets for the same version without a justified explicit decision.

## Documentation map

README.md = player guide. docs/ARCHITECTURE.md = implementation and invariants. API-AUDIT.md = source evidence and uncertainty. docs/WOWUP.md = distribution. CHANGELOG.md = concise chronological history. docs/releases/vX.Y.Z.md = detailed immutable version notes and release body. tests/ = reproducible evidence. TEST-RESULTS.txt = historical 1.3.0 offline run only. Current CI results are linked from GitHub Actions.
