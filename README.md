# Vendor Item Check

Vendor Item Check is a lightweight, zero-dependency addon for **World of Warcraft: Forever** and **WoW Classic Era** that shows whether the item under your cursor can be purchased from an NPC vendor—preventing you from overpaying on the Auction House for common reagents, crafting materials, class supplies, or recipes.

## Features

- **Compact Tooltip Indicator**: Adds a clean, native-looking `Sold by vendor` line to item tooltips.
- **Dynamic Alt-Key Expansion**: Press and hold `Alt` (or your configured modifier) to expand the tooltip with vendor names, zone locations, and coordinates. Releasing collapses it back instantly without cursor re-hovering.
- **Faction Filtering**: Filters known faction restrictions. Forever vendors whose access requirements are unrecorded are marked `Access unverified` in the expanded tooltip.
- **Closest Vendor Priority**: Sorts vendors in your current zone and nearest coordinates to the top of the list.
- **Vendor Purchase Price**: Displays historical reference prices on Classic Era. Forever prices are omitted until the source records purchase quantity, currency costs, and discount context.
- **Configurable Limit**: Caps long vendor lists for ubiquitous items (e.g. Refreshing Spring Water, Mild Spices) and displays a clean `+N more` counter.
- **Zero Dependencies**: Includes separate bundled datasets for each client. Classic Era has 1,931 items and 956 vendors; Forever includes only corroborated observations from the live game.

## Forever data coverage

Forever uses [Everloot's public player observations](https://everloot.app/docs/api), with at least three independent reporters required for an item/vendor relation. Classic inventories, coordinates, faction access, and prices are never substituted for missing Forever data.

**The bundled snapshot dated November 5, 2026 contains zero qualifying Forever vendor offers.** The live source had NPC sightings but no vendor inventory reports when checked. Until qualifying reports become available, Forever item tooltips will have no vendor section. This does not mean the item cannot be bought.

Names and locations require their own corroboration. Unknown locations stay unknown; approximate coordinates are marked `~`. Faction access is unrecorded by the source and is not inferred from NPC reaction toward one player. Records expire when fewer than three reports remain within 30 days. The source does not record exact client builds for these observations, so post-launch confirmation does not guarantee a match to the latest hotfix.

Run `/vic status` to see the selected dataset, source date, build information, and bundled item/vendor counts. Fresh data reaches players through addon updates; no companion app or additional addon is required. Updates cannot guarantee current stock or availability to your character.

Data from [Everloot](https://everloot.app), [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Attribution and data terms are included in `DATA_LICENSE.md` inside the addon folder.

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
    Corina Steele - Elwynn Forest (41.5, 65.9) [Alliance]
    Brog Hamfist - Elwynn Forest (44.0, 65.9) [Alliance]
    Kurran Steele - Elwynn Forest (41.4, 65.6) [Alliance]
    +8 more vendors across Azeroth
  ```

## Configuration

Type `/vic` or `/vendorcheck` to open the addon settings.

| Command | Description |
| --- | --- |
| `/vic` | Open addon settings panel. |
| `/vic toggle` | Enable or disable tooltip enhancements. |
| `/vic status` | Show database item/vendor counts and current settings. |
| `/vic max <1-10>` | Set maximum vendors shown in the expanded tooltip. |
| `/vic help` | List available slash commands. |

Options configurable in the settings panel:
- **Enable/Disable**: Toggle the addon without restarting.
- **Modifier Key**: Choose `Alt`, `Shift`, `Ctrl`, or `None` (Always Expanded).
- **Max Vendors**: Set the number of vendors shown (1–10).
- **Closest First**: Sort vendors in your current zone to the top.
- **Show Coordinates**: Display `(x, y)` map coordinates.
- **Show Purchase Price**: Display Classic Era reference buy prices. Forever prices are currently unavailable.
- **Show Faction Tag**: Display `[Alliance]`, `[Horde]`, or `[Neutral]` tags.

## Troubleshooting

If vendor information does not appear:
1. Confirm the addon is enabled: run `/vic status` in chat.
2. On Forever, check the dataset date and counts. Missing confirmed data leaves the tooltip unchanged.
3. On Classic Era, try an indexed supply such as Coarse Thread.
4. Check if the item is restricted to the opposite faction.

## License

Addon code is released under the [MIT License](LICENSE). Forever observation data and its derived database use CC BY-SA 4.0; see [data attribution](VendorItemCheck/DATA_LICENSE.md).
