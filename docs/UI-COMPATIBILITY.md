# Dashboard and minimap compatibility

## Dashboard

/ae database or /ae dashboard opens Customers. /ae settings or /ae config opens Settings. The native Blizzard AddOns settings entry is retained, sharing its existing group controls. The independent dark window has Overview, Customers, Settings; status button toggles master AE. Click sortable headings, search full names, cycle customer/date filters, page customer and visit rows. Selected filters feed Overview and TSV export. The window supports title-bar dragging, saved position and +/- scale controls. Fixed logical grid fits UI canvas; no permanent OnUpdate. Visible refreshes are coalesced after ledger mutation. Unverified trade counts are shown per invitation. UI layout is mocked/model-tested but not visually verified in the game.

Delete selected and Reset database are two-click confirmation operations; selection/tab/window close clears confirmation. Export is a local editable TSV field; use Ctrl+A/Ctrl+C. It is not a full backup, and large text may be constrained by client edit-box limits.

## Minimap

AutoEnchanterMinimapButton is a named 30px Button created as a direct child of Minimap, using the existing BLP icon and enabled status dot. It is intentionally not a custom map pin or repeatedly reanchored frame. Left-click toggles dashboard; Shift-left toggles the existing AE master switch; right-click opens precisely Turn AutoEnchanter ON/OFF and Open configuration / database. Native MenuUtil.CreateContextMenu with local two-button fallback. /ae minimap show/hide controls visibility; use slash commands if hidden or an external skin manages visibility. Stock placement is fixed; EllesmereUI manages repositioning/grouping.

Source: [EllesmereUI EUI_Minimap_Buttons.lua](https://github.com/EllesmereGaming/EllesmereUI/blob/main/EllesmereUIMinimap/EUI_Minimap_Buttons.lua), blob d06bd33d5b832fdc1ac3a7a00aa2ae56ee3a53d2. Its discovery scans Minimap and flyout children, named Button frames >=20px initially, and LibDBIcon frames. Its Free Move Buttons hook intercepts Shift-left mouse down and suppresses the original OnClick even without meaningful movement. To use AE Shift-left toggle, disable EllesmereUI Free Move Buttons; right-click and /ae on/off remain alternatives. Do not override its hooks or fight layout ownership. [Flyout source](https://github.com/EllesmereGaming/EllesmereUI/blob/main/EllesmereUIMinimap/EUI_Minimap_Flyout.lua), blob c3893109186c1518ae60d6e54efd7c4d18eb464a. Native menu signature checked against [Forever MenuUtil.lua](https://github.com/Gethe/wow-ui-source/blob/forever/Interface/AddOns/Blizzard_Menu/MenuUtil.lua).

Live verification: stock and EllesmereUI loaded, normal grouping/flyout discovery, hover, left, Shift-left with Free Move off, right menu dynamic labels, reload, hidden/shown. Third-party code can change; no guarantee across every version or skin. No external library dependency.

## 1.6.0

Business Manager adds Blacklist (filter/search/sort, paging, recent history, two-click removal) and Guild settings (accessible from Settings, independent enable checkbox, edit/save, empty disables, restore default, request roster). Existing normal welcome controls are unchanged. Customer table adds Grouped and Busy, and selected customer shows no-trade, offenses, free guild items and current guild status. Layout remains fixed logical canvas with scale controls. No changes to minimap click gestures or EllesmereUI ownership. Live rendering still needs verification.

## 1.6.1

Shared group settings canvas adds five placeholder buttons, an editable-message local preview and marker-change refresh while visible. Both the Business Manager and native addon settings use this canvas. Save/Enter persists the raw template, Escape restores it. Preview uses current marker, not configured marker; icon rendering falls back to native token text if the renderer is unavailable. See WELCOME-MESSAGES.md. No changes to minimap or EllesmereUI.

## 1.6.4

Welcome template editor adds ENCHANTING insertion button and updates local preview on profession/spellbook events while visible. Native hyperlink is generated on expansion; live layout and receiving-player clickability remain unverified.
