# Vendor Item Check

Vendor Item Check is a lightweight, zero-dependency addon for **World of Warcraft: Forever** and **WoW Classic Era** that shows whether the item under your cursor can be purchased from an NPC vendor—preventing you from overpaying on the Auction House for common reagents, crafting materials, class supplies, or recipes.

## Features

- **Compact Tooltip Indicator**: Adds a clean, native-looking `Sold by vendor` line to item tooltips.
- **Hold to Expand**: Hold `Alt` or your configured keyboard modifier to show vendor names, zones and coordinates. On Forever, a controller trigger or shoulder button can also expand the item tooltip. Release to collapse without re-hovering.
- **Faction Filtering**: Filters known faction restrictions. Forever vendors whose access requirements are unrecorded are marked `Access unverified` in the expanded tooltip.
- **Closest Vendor Priority**: Sorts vendors in your current zone and nearest coordinates to the top of the list.
- **Vendor Purchase Price**: Displays historical reference prices on Classic Era and observed quotes from your own Forever merchant visits, including purchase quantities.
- **Configurable Limit**: Caps long vendor lists for ubiquitous items (e.g. Refreshing Spring Water, Mild Spices) and displays a clean `+N more` counter.
- **Zero Dependencies**: Includes separate bundled datasets for each client. Classic Era has 1,931 items and 956 vendors; Forever includes only corroborated observations from the live game.

## Forever data coverage

On Forever, the addon automatically learns from merchants you visit. Open a merchant window, then hover an observed item anywhere to see who sold it. Hold your modifier for the observation date, approximate location, and a price quote when available. Recording stays local and is enabled by default; turn it off with `/vic recording off` or **Learn from merchants I visit** in settings.

Your own observations are usable immediately and expire after 30 days. Prices and observed access apply only to the character that made the observation. Prices are historical quotes, not a promise of today's price or stock; discounts and restrictions may change. Non-integral per-item copper prices are shown as an exact batch cost. Offers with alternate or unknown costs do not get a pure-gold comparison.

The bundled Forever database combines eligible [Everloot observations](https://everloot.app/docs/api) with reviewed player contributions. At least three independent reporters are required for a shared item/vendor relation. Classic inventories, coordinates, faction access, and prices are never substituted for missing Forever data.

<!-- forever-coverage:start -->
**Bundled Forever coverage:** 2 confirmed items and 2 vendors. Source observations as of `2026-11-09T08:20:14.478Z`.
<!-- forever-coverage:end -->

Missing data does not mean the item cannot be bought.

Bundled names and locations require their own corroboration. Unknown locations stay unknown; approximate coordinates are marked `~`. Bundled faction access is unrecorded and is not inferred from NPC reaction toward one player. Bundled records expire when fewer than three reports remain within 30 days. The external source does not record exact client builds for these observations, so post-launch confirmation does not guarantee a match to the latest hotfix.

Run `/vic status` to see the selected dataset, source date, build information, and bundled item/vendor counts. Data refreshes are proposed weekly for maintainer review; accepted data reaches players through addon updates. No companion app or additional addon is required. Updates cannot guarantee current stock or availability to your character.

Data from [Everloot](https://everloot.app), [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Attribution and data terms are included in `DATA_LICENSE.md` inside the addon folder.

## Share observations

Run `/vic export` to open the contribution window. It explains what will be shared
and the CC BY-SA 4.0 terms. If you agree, press **Prepare CC BY-SA export**, copy the
selected text with Ctrl+C, and save it as a `.json` file to share with a maintainer.
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
    Corina Steele - Elwynn Forest (41.5, 65.9) [Alliance]
    Brog Hamfist - Elwynn Forest (44.0, 65.9) [Alliance]
    Kurran Steele - Elwynn Forest (41.4, 65.6) [Alliance]
    +8 more vendors across Azeroth
  ```

On Forever, **LT / L2** also expands a visible item tooltip by default. Holding the
trigger continues its normal action-bar behavior; the addon only observes it while
a vendor item tooltip is showing. Release it to collapse, or keep holding Alt to
stay expanded. With a supported controller connected and enabled, the default hint
is `Hold ALT or LT for locations`.

## Configuration

Type `/vic` or `/vendorcheck` to open the addon settings.

| Command | Description |
| --- | --- |
| `/vic` | Open addon settings panel. |
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

Open `/vic` and click either modifier selector to cycle its choices. Keyboard and
controller inputs work independently: either selected input can expand the tooltip.
Choose **Keyboard off** for controller-only expansion, or **Always expanded** to
show details without holding anything. These modifier settings apply immediately and survive reloads.
If the game already makes a controller button emulate Alt/Shift/Ctrl, that also
activates the corresponding keyboard choice. Classic Era retains keyboard expansion.
Unavailable controller APIs fall back to keyboard input and a keyboard-only hint.

## Troubleshooting

If vendor information does not appear:
1. Confirm the addon is enabled: run `/vic status` in chat.
2. On Forever, visit a merchant with recording enabled, then check the separate personal and bundled counts in `/vic status`. Missing data leaves the tooltip unchanged.
3. On Classic Era, try an indexed supply such as Coarse Thread.
4. Check if the item is restricted to the opposite faction.

## License

Addon code is released under the [MIT License](LICENSE). Shared Forever observation exports and the derived bundled database use CC BY-SA 4.0; see [data attribution](VendorItemCheck/DATA_LICENSE.md).
