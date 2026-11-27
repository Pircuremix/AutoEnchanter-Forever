# Release verification records

These records supplement historical release notes with actual CI and publication evidence after a release. They do not change the published ZIP or its release body. Only report confirmed results. Record live client evidence separately from mocked test results, and do not upload personal player data or SavedVariables.

| Release | Automated verification | Publication | Live status |
|---|---|---|---|
| [1.6.4](v1.6.4.md) | 295 checks per Lua runtime; package verified | Confirmed | Pending |
| [1.6.3](v1.6.3.md) | 275 checks per Lua runtime; package verified | Confirmed | Pending |
| [1.6.2](v1.6.2.md) | 258 checks per Lua runtime; package verified | Confirmed | Pending |
| [1.6.1](v1.6.1.md) | 230 checks per Lua runtime; package verified | Confirmed | Pending |
| [1.6.0](v1.6.0.md) | 201 checks per Lua runtime; package verified | Confirmed | Pending |
| [1.5.0](../releases/v1.5.0.md) | [CI](https://github.com/Pircuremix/AutoEnchanter-Forever/actions/runs/45543016703), 150 per runtime | [Release workflow](https://github.com/Pircuremix/AutoEnchanter-Forever/actions/runs/45543071779) | Pending |
| [1.4.0](../releases/v1.4.0.md) | [CI](https://github.com/Pircuremix/AutoEnchanter-Forever/actions/runs/45540445595), 101 per runtime | [Release workflow](https://github.com/Pircuremix/AutoEnchanter-Forever/actions/runs/45540540070) | Pending |
| [1.3.2](../releases/v1.3.2.md) | [CI](https://github.com/Pircuremix/AutoEnchanter-Forever/actions/runs/45490266585) | [Release workflow](https://github.com/Pircuremix/AutoEnchanter-Forever/actions/runs/45490266550) | Owner reported successful WowUp update; game behavior not established |
| [1.3.1](../releases/v1.3.1.md) | [CI](https://github.com/Pircuremix/AutoEnchanter-Forever/actions/runs/45489427568) | [Release workflow](https://github.com/Pircuremix/AutoEnchanter-Forever/actions/runs/45489427373) | Pending |
| [1.3.0](../releases/v1.3.0.md) | [Historical local test log](../../TEST-RESULTS.txt), 49 checks | Source history | Pending |

For future releases, create vX.Y.Z.md with tested commit, CI runs, test counts, package assets, benchmark details if relevant, failed intermediate attempts and fixes, known limitations, and live acceptance status. Use [LIVE-CHECKLIST.md](LIVE-CHECKLIST.md) for the current in-game test plan.
