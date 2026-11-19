# Vendor Item Check UI implementation

[Approved Figma specification and screen index](https://www.figma.com/design/1zE9AwAqZWXlYUIPnWtpXX/Vendor-Item-Check?node-id=51-1172)

## Visual review

Capture the current addon at its standard viewport with
`python3 tests/run_wowlua.py --screenshots .cache/wowlua-review`. Add `--compact`
for the synthetic 480 × 800 viewport. The anonymized account replay uses its recorded
viewport and checks Accurate Slugs prices, quote privacy, and full contribution selection.

| Figma frames | WoWLua screenshots |
| --- | --- |
| Items `15:183`, Vendors `15:23` | `item-sellers`, `vendor-inventory` |
| Zone `16:2`, Filters `51:1214` | `zone-picker`, `advanced-filters` |
| No results `50:724`, Unnamed item `50:912` | `no-results`, `unnamed-item` |
| Waypoint set `50:1325`, Unavailable `50:1100` | `waypoint-set`, `waypoint-unavailable` |
| Native tooltip `50:477`, Settings `50:586`, Hint `65:997` | `collapsed-tooltip`, `expanded-tooltip`, `minimal-tooltip`, `settings`, `settings-help` |
| Overview `56:952`, Status `56:1027`, Zero state `61:952` | `data-overview`, `data-status`, `data-empty` |
| Generate `56:1100`, Copy `74:952` | `contribute-generate`, `contribute-copy` |

Compare the addon-owned layout, rendered textures, text placement, and controls
against each frame. Item art, merchant portraits, prices, stock, and counts are
runtime values. A shop glyph fills the portrait slot when the client has no matching
merchant available. Blizzard supplies the outer Options panel and item tooltip chrome.

## Live client acceptance

Check both live clients at common UI scales. Record the client build, dataset date,
map and controller support, tooltip coexistence, combat behavior, and large JSON
selection. WoWLua covers the states in the table and exercises the compact browser.

Verify reputation and promotion evidence on the target APIs before enabling
**REP PRICE** or **SALE** badges. Enable the CurseForge contact actions when a
verified project contact URL is configured.
