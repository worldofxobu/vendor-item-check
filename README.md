# Vendor Item Check

Vendor Item Check is a lightweight, zero-dependency addon for **World of Warcraft: Forever** and **WoW Classic Era** that shows whether the item under your cursor can be purchased from an NPC vendor—preventing you from overpaying on the Auction House for common reagents, crafting materials, class supplies, or recipes.

## Features

- **Compact Tooltip Indicator**: Adds a clean, native-looking `Sold by vendor` line to item tooltips.
- **Hold to Expand**: Hold `Alt` or your configured keyboard modifier to show vendor names, zones and coordinates. On Forever, a controller trigger or shoulder button can also expand the item tooltip. Release to collapse without re-hovering.
- **Faction Filtering**: Filters known faction restrictions. The browser labels trusted and unknown access separately.
- **Closest Vendor Priority**: Sorts vendors in your current zone and nearest coordinates to the top of the list.
- **Vendor Purchase Price**: Displays historical reference prices on Classic Era and observed quotes from your own Forever merchant visits, including purchase quantities.
- **Configurable Limit**: Caps long vendor lists for ubiquitous items (e.g. Refreshing Spring Water, Mild Spices) and displays a clean `+N more` counter.
- **Zero Dependencies**: Includes separate bundled datasets for each client. Classic Era has 1,931 items and 956 vendors; Forever includes only corroborated observations from the live game.

## Forever data coverage

On Forever, the addon automatically learns from merchants you visit. Open a merchant window, then hover an observed item anywhere to see who sold it. Hold your modifier for locations and qualified prices. Open seller details in the browser for observation dates. Recording stays local and is enabled by default; turn it off with `/vic recording off` or **Learn from merchants I visit** in settings.

Your own observations are usable immediately and expire after 30 days. Prices and observed access apply only to the character that made the observation. Prices are historical quotes, not a promise of today's price or stock; discounts and restrictions may change. Non-integral per-item copper prices are shown as an exact batch cost. Offers with alternate or unknown costs do not get a pure-gold comparison.

The bundled Forever database combines eligible [Everloot observations](https://everloot.app/docs/api) with reviewed player contributions. At least three independent reporters are required for a shared item/vendor relation. Classic inventories, coordinates, faction access, and prices are never substituted for missing Forever data.

<!-- forever-coverage:start -->
**Bundled Forever coverage:** 2 confirmed items and 2 vendors. Source observations as of `2026-11-09T08:20:14.478Z`.
<!-- forever-coverage:end -->

Missing data does not mean the item cannot be bought.

Bundled names and locations require their own corroboration. Unknown locations stay unknown; approximate coordinates are marked `~`. Bundled faction access is unrecorded and is not inferred from NPC reaction toward one player. Bundled records expire when fewer than three reports remain within 30 days. The external source does not record exact client builds for these observations, so post-launch confirmation does not guarantee a match to the latest hotfix.

Run `/vic status` to open the status view and see the selected dataset, source date, build information, and bundled item/vendor counts. Data refreshes are proposed weekly for maintainer review; accepted data reaches players through addon updates. No companion app or additional addon is required. Updates cannot guarantee current stock or availability to your character.

Data from [Everloot](https://everloot.app), [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Attribution and data terms are included in `DATA_LICENSE.md` inside the addon folder.

## Share observations

Run `/vic export` to open the contribution window. It explains what will be shared
and the CC BY-SA 4.0 terms. If you agree, press **Generate contribution data**, then **Select JSON to copy** and Ctrl+C. You can share it manually through CurseForge when a project contact is available.
Nothing is uploaded automatically.

The export includes NPC/item facts, quoted prices and quantities, approximate NPC
locations, observation dates/builds, faction and discount context when available,
and a stable installation pseudonym. Character names, character GUIDs, realm/account
names, and unrelated settings are excluded. You do not need to share your whole
SavedVariables file. Your local data works without exporting or contributing.

Contributions are reviewed before publication. Repeated exports, alts, or multiple
installations belonging to the same person do not count as independent reports.

## Compatibility

A single download targets both clients:

- **WoW Forever**: `1.60.1` (Interface `16001`)
- **WoW Classic Era**: `1.15.x` (Interface `11500`–`11509`)

## Installation

1. Download or extract the addon into your client's AddOns directory:
   - For WoW Forever: `World of Warcraft/_forever_/Interface/AddOns/VendorItemCheck`
   - For Classic Era: `World of Warcraft/_classic_era_/Interface/AddOns/VendorItemCheck`
2. Restart the game client or type `/reload` if already running.
3. Ensure **Vendor Item Check** is enabled on the character selection AddOns menu.

## Usage

- Hover over any item (in your bags, character sheet, quest rewards, or Auction House).
- If the selected dataset has a vendor record, the tooltip shows the following (Classic Era example):
  ```text
    Sold by vendor: 10s  (Hold ALT for locations)
  ```
- Press and hold **Alt** while looking at the tooltip:
  ```text
  Sold by vendors (closest first) - 10s
    Corina Steele - Elwynn Forest (41.5, 65.9)
    Brog Hamfist - Elwynn Forest (44.0, 65.9)
    Kurran Steele - Elwynn Forest (41.4, 65.6)
    +8 more vendors across Azeroth
  ```

On narrow screens, the expanded tooltip shows each seller's location and price
below their name.

On Forever, **LT / L2** also expands a visible item tooltip by default. Holding the
trigger continues its normal action-bar behavior; the addon only observes it while
a vendor item tooltip is showing. Release it to collapse, or keep holding Alt to
stay expanded. With a supported controller connected and enabled, the default hint
is `Hold ALT or LT for locations`.

## Browse items and vendors

Run `/vic browse`, or click **Browse vendors and items** in settings, to open the
browser. The **Items** tab searches known items by name or item ID and lists their
sellers. The **Vendors** tab searches names or NPC IDs and shows each vendor's
**known items**. Click a seller or inventory item to move between the two views;
hover an item for its tooltip. Sellers are ordered by proximity when **Prioritize nearby vendors**
is enabled, or by name when it is off. Scroll either list with the mouse wheel or drag its scrollbar.

Filter by source (**All**, **Personal**, or **Bundled**), zone, or faction access.
Open the zone menu to select a zone or All zones. Long menus support scrolling and Up/Down buttons. Access defaults
to your faction plus unverified vendors; choose all factions to include known opposing
vendors. A second search field filters the selected inventory or seller list.
Item names load from the client cache; unavailable names appear as `Item #ID` and
remain searchable by ID. They update when the client supplies the name.

Prices retain their context: Classic values are historical references, and Forever
quotes apply only to the observing character. Inventory tiles show price and recorded
stock on separate lines. Hover a tile for the full item name, or hover a seller's
**Details** button for the complete offer information. Approximate positions, observation
dates and recorded stock are labelled. Known inventories may be incomplete;
recorded stock and prices are not live availability. Forever records expire after
30 days, and its browser initially fills from merchants you visit while bundled
coverage is empty. Classic has no personal merchant journal.

Select **Set Waypoint** when a vendor has fresh coordinates and your client supports native waypoints. **Remove Waypoint** clears only the matching point created by Vendor Item Check. Closing the browser leaves it in place.

Use **Data** in the browser or **Data & sharing** in settings to see coverage and open the status and contribution views. The tooltip toggle and merchant learning can be enabled separately.

Only one vendor is tracked at a time, for the current login session. **Stop
tracking** or the panel's close button clears it; an expired location also clears
tracking. The addon removes its waypoint only if it still matches the one it
placed, preserving a different waypoint you set afterward. Choosing **Show on map**
replaces the current native waypoint.

The browser's **Back** button restores your previous selection, searches, filters,
and scroll positions after following an item or vendor link. Each tab remembers
its own browsing state during the session. **Clear filters** keeps your search.
Seller rows provide **Track** directly; **Details** shows observation and source
information. **Help** explains navigation and **Data details** explains coverage.
Item icons use client information; uncached names remain searchable by ID.

On smaller screens the browser shows results and details on separate pages.
Use **Back** to return to results. The search clear button removes the query without changing filters. The window fits the available screen and
remains clamped to its edges.

## Configuration

Type `/vic` or `/vendorcheck` to open the browser. Use `/vic settings` for addon settings.

| Command | Description |
| --- | --- |
| `/vic` | Open the item and vendor browser. |
| `/vic settings` | Open addon settings. |
| `/vic browse` | Search known items and browse vendor inventories. |
| `/vic toggle` | Enable or disable tooltip enhancements. |
| `/vic status` | Show database item/vendor counts and current settings. |
| `/vic max <1-10>` | Set maximum vendors shown in the expanded tooltip. |
| `/vic recording on\|off` | Enable or disable learning from Forever merchants; existing observations are preserved. |
| `/vic export` | Prepare an optional manual observation contribution. |
| `/vic help` | List available slash commands. |

Options configurable in the settings panel:
- **Enable/Disable**: Toggle the addon without restarting.
- **Keyboard Expansion Modifier**: Choose `Alt`, `Shift`, `Ctrl`, **Keyboard off**, or **Always expanded**. Existing always-expanded settings are preserved.
- **Controller Expansion Modifier** (Forever): Choose **LT / L2**, **RT / R2**, **LB / L1**, **RB / R1**, or **Controller off**. The hint follows your selection. This observes the held button without changing its normal game function.
- **Max Vendors**: Set the number of vendors shown (1–10).
- **Closest First**: Sort vendors in your current zone to the top.
- **Show Coordinates**: Display `(x, y)` map coordinates.
- **Show Purchase Price**: Display Classic Era reference prices and personal Forever quotes.
- **Show Faction Tag**: Display `[Alliance]`, `[Horde]`, or `[Neutral]` tags.

Open `/vic settings` and select a modifier from its menu. Keyboard and
controller inputs work independently: either selected input can expand the tooltip.
Choose **Keyboard off** for controller-only expansion, or **Always expanded** to
show details without holding anything. These modifier settings apply immediately and survive reloads.
If the game already makes a controller button emulate Alt/Shift/Ctrl, that also
activates the corresponding keyboard choice. Classic Era retains keyboard expansion.
Unavailable controller APIs fall back to keyboard input and a keyboard-only hint.

Settings scroll within the native options panel and are grouped into tooltips, controls, and merchant learning/data. A sample tooltip updates when settings change. Reset settings requires confirmation and preserves observations. Sharing remains optional and manual.

## Troubleshooting

If vendor information does not appear:
1. Confirm the addon is enabled: run `/vic status` in chat.
2. On Forever, visit a merchant with recording enabled, then check the separate personal and bundled counts in `/vic status`. Missing data leaves the tooltip unchanged.
3. On Classic Era, try an indexed supply such as Coarse Thread.
4. Check if the item is restricted to the opposite faction.

## License

Addon code is released under the [MIT License](LICENSE). Shared Forever observation exports and the derived bundled database use CC BY-SA 4.0; see [data attribution](VendorItemCheck/DATA_LICENSE.md).
