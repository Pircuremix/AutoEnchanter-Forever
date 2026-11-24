# Changelog

## 1.3.2 — WowUp update test (release candidate)

- Shortened the release asset to `AutoEnchanter-1.3.2.zip`.
- Added explicit Forever client metadata in the separate `release.json` release asset, matching WowUp's metadata selection format.
- Updated the public-repository installation instructions and synchronized the in-game version.
- No changes to invite behavior, saved settings, matching, icon or category. This version is intended to verify the WowUp update path.

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
