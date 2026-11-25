# Changelog

Detailed version notes are maintained under [docs/releases/](docs/releases/README.md). Dates refer to release history; availability is confirmed by GitHub Releases.

## 1.4.0 — Customer welcome and raid management

- Added confirmed-GUID customer acceptance tracking and editable PARTY/RAID welcome chat.
- Added opt-in self-marker selection with existing-marker preservation.
- Added opt-in automatic raid conversion at 3 total members by default; configurable 2–5.
- Added native Settings panel, persistent options, slash fallbacks and group diagnostics.
- Isolated group and settings modules; preserved existing matcher and saved whitelist.
- Added integration tests, TOC-driven packaging, per-version release notes and maintainer/AI guide.
- New features default off; live-client acceptance pending. [Detailed release notes](docs/releases/v1.4.0.md).

## Unreleased — documentation

- Expanded public-facing README and added a dedicated WowUp integration and troubleshooting guide.
- Corrected outdated private-repository and CI statements. Documentation only; no new addon version.

## 1.3.2 — 2026-11-24 — WowUp update test (release candidate)

- Shortened the release asset to `AutoEnchanter-1.3.2.zip`.
- Added explicit Forever client metadata in the separate `release.json` release asset, matching WowUp's metadata selection format.
- Updated the public-repository installation instructions and synchronized the in-game version.
- No changes to invite behavior, saved settings, matching, icon or category. This version is intended to verify the WowUp update path.
- Published successfully with ZIP and release.json after correcting an initial workflow shell-quoting failure; Lua 5.1 and 5.4 CI passed.

## 1.3.1 — 2026-11-24 (release candidate)

- Added a custom 64×64 BLP2 enchanting icon to the in-game AddOns list.
- Classified Auto Enchanter under Professions via TOC metadata.
- Added versioned Forever release packaging and a tested-before-publish GitHub Actions workflow for WowUp.
- No matching or invite logic changes; live client acceptance remains pending.

## 1.3.0 — 2026-11-24 (release candidate)

- Audited Forever API signatures and removed the legacy invite fallback.
- Corrected log semantics: native call completion does not confirm delivery.
- Fail closed on inaccessible GUID/menu fields and errors or secret returns from available eligibility checks.
- Corrected native right-click menu tags and Forever-specific `contextData.surname` handling.
- Consolidated SavedVariables initialization, sanitize invalid entries, keep original valid entries and flags.
- Added a 2,048-entry ceiling on the 15-minute last-message cache.
- Added diagnostics for build, interface, API availability, simulations, failures and ineligible requests.
- Preserve normalized exact matching, aliases, cooldown, full-name handling and learning while disabled.
- Added regression tests, CI configuration, README, API audit and actual test results.
- Live WoW Forever client acceptance is pending.

## 1.2 — previous port

Full name normalization, stable channel filtering, native party checks, cache expiration, restricted chat handling, test/status commands and action-block detection.
