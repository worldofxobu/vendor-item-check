# Vendor Item Check

Vendor Item Check is a lightweight, zero-dependency addon for **World of Warcraft: Forever** and **WoW Classic Era** that shows whether the item under your cursor can be purchased from an NPC vendor—preventing you from overpaying on the Auction House for common reagents, crafting materials, class supplies, or recipes.

## Features

- **Compact Tooltip Indicator**: Adds a clean, native-looking `Sold by vendor` line to item tooltips.
- **Dynamic Alt-Key Expansion**: Press and hold `Alt` (or your configured modifier) to expand the tooltip with vendor names, zone locations, and coordinates. Releasing collapses it back instantly without cursor re-hovering.
- **Faction Filtering**: Only shows vendors accessible to your character (Alliance, Horde, or Neutral). If an item is exclusively sold by the opposing faction, the tooltip informs you accordingly.
- **Closest Vendor Priority**: Sorts vendors in your current zone and nearest coordinates to the top of the list.
- **Vendor Purchase Price**: Displays the standard vendor buy price so you can compare prices with the Auction House at a glance.
- **Configurable Limit**: Caps long vendor lists for ubiquitous items (e.g. Refreshing Spring Water, Mild Spices) and displays a clean `+N more` counter.
- **Zero Dependencies**: Includes a pre-bundled, high-performance database covering over 1,900 Classic Era items and 950 vendors.

## Compatibility

A single download works seamlessly across both supported clients:

- **WoW Forever**: `1.60.1` (Build `70685`, Interface `16001`)
- **WoW Classic Era**: `1.15.x` (Interface `11500`–`11509`)

## Installation

1. Download or extract the addon into your client's AddOns directory:
   - For WoW Forever: `World of Warcraft/_forever_/Interface/AddOns/VendorItemCheck`
   - For Classic Era: `World of Warcraft/_classic_era_/Interface/AddOns/VendorItemCheck`
2. Restart the game client or type `/reload` if already running.
3. Ensure **Vendor Item Check** is enabled on the character selection AddOns menu.

## Usage

- Hover over any item (in your bags, character sheet, quest rewards, or Auction House).
- If the item is sold by a vendor, the tooltip shows:
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
- **Show Purchase Price**: Display vendor buy price.
- **Show Faction Tag**: Display `[Alliance]`, `[Horde]`, or `[Neutral]` tags.

## Troubleshooting

If vendor information does not appear:
1. Confirm the addon is enabled: run `/vic status` in chat.
2. Verify you are hovering an item that is sold by a vendor (e.g. Copper Ore is gathered by mining, but Copper Modulator or Coarse Thread is sold by trade vendors).
3. Check if the item is restricted to the opposite faction.

## License

Released under the [MIT License](LICENSE).
