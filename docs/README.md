# AutoEnchanter documentation

Current published addon: **1.6.3** · Forever interface 16001 · customerLedger schema 2.

Start here if maintaining the project, troubleshooting it, or handing it to another developer or AI. The actual code and TOC are authoritative for implementation; the documents below explain the intended contracts. Historical release notes are not current implementation instructions.

## Player and configuration guides

| Document | Purpose |
|---|---|
| [Main README](../README.md) | Install, settings, commands, behavior and examples |
| [Manual invitations](MANUAL-INVITES.md) | Native invite observation, identity and ledger attribution |
| [Welcome message templates](WELCOME-MESSAGES.md) | Placeholders, current marker and local preview |
| [WowUp](WOWUP.md) | Installation, automatic updates and release metadata |
| [Customer policy](CUSTOMER-POLICY.md) | Cooldown, decline and non-tipping rules; guild exemptions |
| [UI compatibility](UI-COMPATIBILITY.md) | Dashboard, minimap, EllesmereUI and settings |
| [Live checklist](verification/LIVE-CHECKLIST.md) | Controlled in-game verification |

## Engineering references

| Document | Purpose |
|---|---|
| [AGENTS.md](../AGENTS.md) | Required contributor workflow and invariants |
| [Architecture](ARCHITECTURE.md) | Runtime modules, lifecycle and event contracts |
| [Database](DATABASE.md) | Schema 2, migration, persistence and accounting |
| [Trade tracking](TRADE-TRACKING.md) | Strict completion evidence and tip/enchant qualification |
| [Invite outcomes](INVITE-OUTCOMES.md) | Native result classification and ambiguous cases |
| [Performance](PERFORMANCE.md) | Hot path, timing and benchmark methodology |
| [API audit](../API-AUDIT.md) | Forever API sources and limitations |

## Release history and evidence

| Document | Purpose |
|---|---|
| [Changelog](../CHANGELOG.md) | Chronological summary of changes |
| [Release notes](releases/README.md) | Version-specific notes; release body from 1.4.0 onward |
| [Verification records](verification/README.md) | Post-publication evidence, CI links and remaining live checks |
| [GitHub releases](https://github.com/Pircuremix/AutoEnchanter-Forever/releases) | Published installation assets |

Historical local test output: [TEST-RESULTS.txt](../TEST-RESULTS.txt) (1.3.0 only). Current reproducible suites are in [tests/](../tests), package and test scripts in [scripts/](../scripts). Never treat mock success as live client confirmation.
