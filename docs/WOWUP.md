# WowUp installation and release integration

AutoEnchanter targets **World of Warcraft: Forever** (client interface 16001 as of v1.5.0). The GitHub repository is public, so a personal access token is not needed for ordinary installation.

## Install with WowUp

1. Install or update WowUp to a build supporting Forever and GitHub release metadata (the integration was reviewed against [WowUp v2.25.5 source](https://github.com/WowUp/WowUp/blob/v2.25.5/wowup-electron/src/app/addon-providers/github-addon-provider.ts)).
2. Select the Forever installation in WowUp. Use the correct game folder, not Anniversary or Classic Era.
3. Open **Get Addons > Install from URL** and paste the repository URL:

   ```text
   https://github.com/Pircuremix/AutoEnchanter-Forever
   ```

4. Click **Import**. In My Addons, right-click AutoEnchanter and enable **Auto Update**.
5. Close and restart WoW after installing or updating. Enable Auto Enchanter under Professions in the game's AddOns list. Run `/ae diagnostics` to verify the installed version and `/ae list` to check your whitelist.

[Official WowUp guide](https://wowup.io/guide/get-addons/overview)

## How updates work

WowUp reads GitHub **published releases**, not arbitrary commits on main. An update requires a new versioned release with a compatible downloadable asset. Refresh WowUp to check sooner, or allow its normal update cycle. With Auto Update enabled and the addon recognized, WowUp should install an available update without manual ZIP extraction. The actual update cycle and behavior depend on the installed WowUp build and settings.

The v1.3.1 release used the suffix convention `AutoEnchanter-1.3.1-forever.zip`. Starting with v1.3.2, releases attach both:

- `AutoEnchanter-1.3.2.zip`: installable package.
- `release.json`: metadata mapping the package to the Forever client.

Example metadata for v1.3.2:

```json
{
  "releases": [
    {
      "filename": "AutoEnchanter-1.3.2.zip",
      "nolib": false,
      "metadata": [
        { "flavor": "forever", "interface": 16001 }
      ]
    }
  ]
}
```

The asset filename must exactly match the metadata entry. WowUp v2.25.5 first attempts metadata-based selection, then falls back to client-specific filename matching. It maps the Forever client to flavor `forever` and displays the asset's name as its version label. Consequently the expected display is `AutoEnchanter-1.3.2.zip`, not just `1.3.2`. This is not an incorrect addon version. Older builds may require the legacy suffix; update WowUp if necessary.

## Verify the update

- Check [latest release](https://github.com/Pircuremix/AutoEnchanter-Forever/releases/latest) and note the tag and attached assets.
- Close WoW; in WowUp, confirm Forever is selected, Auto Update is enabled, and refresh.
- Confirm installed version changes to match the latest available asset. If auto-update is off, use the Update button.
- Restart WoW and run `/ae diagnostics`. It should report the same numeric version as the tag, without the ZIP suffix.
- Run `/ae list` to confirm settings survived. Use debug mode before testing actual invite behavior.

The addon itself never contacts GitHub or WowUp. The account-wide SavedVariables file is stored separately from the installation directory, so ordinary updates do not replace it. Back it up before migration or troubleshooting.

## Troubleshooting

| Symptom | What to check |
|---|---|
| No new update shown | Check that a new release exists, refresh WowUp, verify the Forever client and GitHub provider, and check the addon is not ignored. |
| Missing compatible asset | Update WowUp to a Forever/metadata-capable build. Check the release has both the ZIP and valid release.json. |
| 403/404 or rate limit | Verify repository URL, provider connectivity and GitHub rate limits. The repository is public; do not embed tokens in the URL. |
| Latest version includes .zip | Expected for WowUp's GitHub provider. Verify the actual numeric version with /ae diagnostics. |
| Addon missing in WoW | Confirm the ZIP extracted directly to Interface/AddOns/AutoEnchanter, not a nested folder. Restart WoW and enable it. |
| Icon missing | Confirm AutoEnchanterIcon.blp is beside the TOC and Lua file, and fully restart WoW. |
| Update installed but invites fail | Use /ae diagnostics and /ae status, then follow the README live acceptance checklist. Distribution success does not prove server invite delivery. |

Manual fallback: download the named addon ZIP from Releases and extract it into the Forever AddOns directory. Do not install GitHub's Source code archives or release.json. From 1.4.0 the addon ZIP additionally contains Group.lua and Settings.lua; restart the game after updating to load the new TOC. Do not delete SavedVariables to fix an update issue.

## Maintainer release checklist

1. Make and test changes; update CHANGELOG.md and relevant documentation.
2. Increment the TOC version and the Lua startup/diagnostic version strings together.
3. Commit to main. The [release workflow](../.github/workflows/release.yml) runs when the TOC or release workflow changes, or via manual workflow dispatch.
4. scripts/test.sh and scripts/package.sh centralize tests and TOC-driven packaging. The workflow executes syntax checks and regression tests using Lua 5.1 and 5.4, builds a ZIP containing all TOC-listed Lua modules, the TOC and BLP under AutoEnchanter/, checks the ZIP, and generates metadata from the TOC interface and ZIP filename.
5. Create docs/releases/v<version>.md before publishing; the workflow uses that file as the GitHub release body. The workflow publishes a release named AutoEnchanter <version> tagged v<version>, unless that version already exists. It does not overwrite existing releases. Documentation-only commits do not publish another version.
6. Check both assets and the workflow result, then perform the WowUp verification above. Record live results separately from automated CI results.

For v1.3.2 the corrected [release run](https://github.com/Pircuremix/AutoEnchanter-Forever/actions/runs/45490266550) and [regression run](https://github.com/Pircuremix/AutoEnchanter-Forever/actions/runs/45490266585) completed successfully; [the published release](https://github.com/Pircuremix/AutoEnchanter-Forever/releases/tag/v1.3.2) contains both assets. An earlier release attempt failed due to shell quoting and was corrected. The owner subsequently confirmed the v1.3.2 WowUp automatic update worked. Live game behavior is still a separate acceptance test.

From 1.5.0 the package also contains Database.lua, Trade.lua, Dashboard.lua and Minimap.lua. TOC-driven packaging includes all runtime files. Customer ledger is local SavedVariables and is not part of a release asset. Back up SavedVariables before migration, restart WoW after update, and verify /ae diagnostics. Do not delete SavedVariables as an update troubleshooting step.

From 1.6.0 the TOC also includes CustomerPolicy.lua, Guild.lua, InviteResults.lua and Performance.lua. Schema 1 customerLedger migrates to schema 2 automatically. Preserve SavedVariables and back up before upgrading. Restart WoW; no historical data upload. See docs/releases/v1.6.0.md.
