# Contributing

Thanks for helping improve Vendor Item Check.

## Reporting bugs

Before opening an issue, confirm that the addon is enabled in your character addons list and test with `/vic status`.

Include:

- Forever or Classic Era client version, build, and interface number.
- The item and vendor involved.
- The first complete Lua error, if one appears.
- Steps that reproduce the problem.
- Whether it still occurs with other addons disabled.

Never upload account credentials, authentication tokens, or private server login details.

## Pull requests

1. Keep changes focused and explain the user-facing behavior they alter.
2. Preserve compatibility with WoW's Lua environment across Classic Era and WoW Forever.
3. Run the automated test suite before opening a pull request:

   ```sh
   python3 tests/run_tests.py
   ```

   When a Lua interpreter is available, you can also run:

   ```sh
   lua tests/smoke.lua
   lua tests/classic_smoke.lua
   lua tests/forever_smoke.lua
   lua tests/merchant_smoke.lua
   lua tests/export_smoke.lua
   lua tests/controller_smoke.lua
   lua tests/browser_smoke.lua
   ```

4. Update `CHANGELOG.md` for user-facing changes under `[Unreleased]`.
5. Avoid adding heavy runtime libraries unless the benefit clearly outweighs the addon size and maintenance cost.

## Style

- Use four spaces for Lua indentation.
- Prefer descriptive names over abbreviations.
- Keep tooltip text concise and consistent with the default WoW interface.
- Guard client API calls that may be absent or temporarily unavailable across client flavors.

## Tooltip expansion inputs

The existing `modifierKey` setting preserves `NONE` as always expanded, with `OFF`
meaning keyboard input disabled. `controllerModifier` defaults to `LT` and accepts
LT/RT/LB/RB/OFF on Forever. Modifier choices are validated without altering unrelated
saved settings or observations.

Controller expansion reads `C_GamePad.GetDeviceMappedState` and resolves each binding
with `ButtonBindingToIndex`; native binding indices are zero based and mapped-state
buttons are one based. API reads are guarded. No bindings, gamepad input capture,
focus settings or CVars are changed. Native keyboard modifier emulation is left to
the game. Unsupported clients/APIs keep keyboard behavior and omit controller hints.

Only tracked, visible item tooltips with a vendor section are polled, at most every
50 ms, and only when a controller choice is enabled. Hide/clear/reuse removes the
tooltip from tracking. Keyboard changes still use `MODIFIER_STATE_CHANGED`; input
settings refresh open tooltips immediately. Tests must cover press/release, multiple
tooltips, remapping, disconnection, missing APIs, controller-only and always-expanded
modes, and preserving normal game controls. Synthetic controller tests do not replace
an in-game controller check.

## Browser and tracking

`Browser.lua` indexes the active dataset and personal observations through
`GetItemVendors(itemID, filters)`. Optional filters select `source` (`personal` or
`bundled`; omitted means both) and `allFactions`; existing tooltip callers retain
their behavior. Browser zone filtering follows offer resolution. Do not bypass
freshness or character-specific quote checks. Search indexes are transient; item
names resolve in bounded batches from guarded client APIs. Merchant scans refresh
an open browser; reopening and periodic visible refreshes recheck freshness.
Keep observed copper and purchase eligibility independent. A fresh same-character
coin price with a known quantity can be shown even when the slot was unavailable
to buy. Access and cheapest-price comparisons require their own evidence.

`Tracking.lua` keeps session-only ownership of the native waypoint. Native waypoints require a
recorded map ID and guarded waypoint APIs; zone strings must never be guessed into
map IDs. Coordinates are stored as percentages and converted to normalized map
coordinates only at the waypoint boundary. Clear only a waypoint that still
matches the addon-owned point. Do not alter native supertracking.

Use the approved frames linked from `docs/UI_IMPLEMENTATION.md` to review layout
changes. Addon-owned frames share the palette and typography in `Browser.lua`.
Static artwork and the Inter and Cinzel fonts ship under `VendorItemCheck/Media/`,
along with their applicable font licenses. Keep that media directory beside the
production TOCs. WoWLua preserves package-relative asset paths and uses its
`X-VIC-Media-Folder` TOC field to resolve the same assets in development builds.

Run `lua tests/browser_smoke.lua` for synthetic cross-link navigation, filtering,
name loading, expiry, quote privacy and waypoint ownership checks. In each supported
client, also inspect layout at common UI scales, long/localized names, item hover,
search/paging, live merchant refresh, and map/coordinate fallback behavior. Verify closing the browser, replacing destinations, and preserving user waypoints.

### WoWLua UI tests and debugging

Install [WoWLua 0.13.15](https://wowlua.dev/docs/guide/install), add `wowlua` to
`PATH`, and run these commands from the repository root:

```sh
wowlua check --locked
wowlua test --locked
wowlua build --locked
```

The root `wowlua.json` reads the current files in `VendorItemCheck/` and writes
development builds under `.cache/wowlua/`. Keep its load order, interface numbers,
dependencies, and addon metadata in sync with the production TOCs. WoWLua checks and builds
Forever and Classic Era. The UI tests run on Forever with Blizzard's UI. WoWLua may
need network access to initialize its Blizzard UI cache. Set `WOWLUA_HOME` to its data
directory if it cannot find the cache, and set `WOWLUA_WOW_PATH` if it cannot find your
World of Warcraft installation. A local Forever installation provides textures and fonts
for screenshots and the debugger UI.

Open the repository root in VS Code with the `wowlua.wowlua` extension installed.
Start **WoWLua: Run Addon** for a fresh character or **WoWLua: Forever Account Replay**
to open Edna Mullby's 37-item saved inventory on login. Open **wowlua: UI** from the
Command Palette to interact with the emulated UI. Restart the debug session after
saving source edits to rebuild the addon.

The account replay uses anonymized saved observations and an item catalog in
`tests/profiles/account-replay.json`. The replay mock pins the observations to the
capture date. The fixture exercises the browser and quote privacy using historical
observations. Keep private SavedVariables and account files outside the tracked fixture.

Select **WoWLua: My SavedVariables** to open the browser on login with a local
Forever account snapshot. With `python3` and Lua 5.2 or newer available on `PATH`,
VS Code reimports `NTHEOTHER/SavedVariables/VendorItemCheck.lua` on each launch.
To use another copy or the game's file, set `VIC_SAVED_VARIABLES` to the path to
`VendorItemCheck.lua` before opening VS Code. WoW writes SavedVariables when you
log out or run `/reload`. You can also generate the profile from a terminal:

```sh
python3 scripts/import_wowlua_savedvars.py /path/to/VendorItemCheck.lua
```

The importer reads `VendorItemCheckDB` and writes the ignored
`tests/profiles/account-local.json`. Debugger changes live in the emulator for
that session. The replay uses the most recently observed character's GUID for
personal quotes and the latest observation as its replay time. Set
`VIC_REPLAY_CHARACTER` before opening VS Code (or pass `--character` for a manual
import) to replay another saved character's quotes.

Use `python3 tests/run_wowlua.py --wow PATH_TO_WORLD_OF_WARCRAFT` to supply an
installation path on the command line. Add `--screenshots .cache/wowlua-review` to
render the approved browser, settings, tooltip and data states and the Accurate
Slugs replay. Add
`--compact` to exercise the synthetic UI at 480×800. The account replay uses its
recorded viewport in either mode.

Use the BigWigs packager for release ZIPs. The WoWLua manifest, lockfile, editor
configuration, and replay fixtures are development files excluded from release ZIPs.

## Vendor data pipeline

The addon ships separate Classic Era and Forever datasets. Runtime code selects the
dataset using guarded client version/interface APIs. Unsupported or unknown clients
receive an empty dataset. Saved settings remain compatible.

The base TOC supports both clients. `_Vanilla.toc` and `Interface-Vanilla` must list
only Classic Era interfaces; `_Camelot.toc` and `Interface-Camelot` must list only
Forever interfaces. The multi-client fallback header is not a reason to mix flavor
numbers in the specialized manifests. All three manifests load the same Lua files
in the same order. Verify the package using the standard BigWigs packager with
uploading disabled (`-d`); contributor/source-audit docs, tests and build inputs
must be excluded, and addon files and data attribution must sit directly under
`VendorItemCheck/` in the installable ZIP. Do not change versions, tag or upload as
part of a packaging check.

### Forever source and confidence

Personal observations are a separate layer from the corroborated bundled database.
`Merchant.lua` records positive merchant-slot evidence while the window is open,
using guarded modern APIs or legacy fallbacks. Pending links retry only for the
same merchant session. Missing/filtered slots never prove an inventory removal.
Check unit GUIDs and names for secret values before parsing, comparing, or storing
them. A restricted GUID skips the scan. Require a readable player GUID to show
character-specific quotes or access from saved observations.
The latest offer per NPC/item/character is saved under the versioned
`VendorItemCheckDB.observations` subtree; existing flat settings remain compatible.
Unknown future observation schemas are preserved and recording stays unavailable.

Recording is on by default on Forever and stops when the recording setting is disabled. Indexes are rebuilt and stale observations pruned at
startup, login and merchant opening. Personal records expire after 30 days; no
current clock means no personal evidence is used. Character GUIDs stay local.
Other characters can see observed inventory, but never inherit a personal price or
an access guarantee. Merchant quotes retain quantity, stock, alternate costs,
discount context when exposed, and the exact observed build. Unknown price context
is never promoted to a standard buy price. A newer personal offer supersedes an
overlapping older bundled offer for the observing character.

External source: [Everloot public corpus](https://everloot.app/docs/api), filtered to `vendor`
and `npc_sighting`. This is a community observation feed, not Blizzard's vendor
database. [Record schemas](https://everloot.app/schema/index.json) define the fields.
Data from Everloot (https://everloot.app), CC BY-SA 4.0. Keep its credit and licence
with the source snapshot, generated data, documentation, and installable package.
See `VendorItemCheck/DATA_LICENSE.md`.

Require three distinct public install pseudonyms; repeated observations from one
install do not count as corroboration. For merchant inventory, use the latest
snapshot from each reporter for each NPC. Conflicting tied snapshots are withheld.
Names and approximate map-coordinate cells require independent corroboration.
Player-only positions never become vendor pins. NPC reaction does not establish
Alliance/Horde/neutral accessibility. Missing fields remain unknown.

Exclude records before launch (2026-11-04 23:00 UTC), observations older than 30 days
relative to the source snapshot, explicit beta channels, and explicit non-Forever
builds. The current feed does not include build/channel fields: post-launch times
in this Forever-only feed are the available evidence, not exact-build verification.
Do not describe it as a complete or authoritative current inventory.

The current vendor schema exposes `priceCopper` but no purchase quantity, currency
costs, or discount context. Corroborated raw price evidence stays on each vendor/item
offer with `priceContext = "unknown"`; runtime must not display it as a unit price.
Do not infer prices from sell prices, Classic data, or Informant on Forever.

Offers, names and locations expire independently when fewer than three reporters
remain within the 30-day window. Runtime checks use the client clock when available.
Unknown items have no vendor section; absence is never proof that no vendor exists.

### Reproduce or refresh Forever data

Python standard library only; no runtime addon dependencies are added.

```sh
# Default: reproduce DataForever.lua from the committed source snapshot, offline.
python3 scripts/build_data.py
# Verify exact deterministic output without writing.
python3 scripts/build_data.py --check
# Explicit network refresh, validation, change summary, and regeneration.
python3 scripts/build_data.py --refresh
# Synchronize player coverage and the Unreleased data snapshot entry.
python3 scripts/update_data_docs.py
```

Review and commit the source snapshot and generated Lua together. The generated
metadata includes source date, confidence policy and SHA-256 of the canonical
snapshot; each page retains its source URL and attribution. Raw public observations
remain under CC BY-SA 4.0. `--snapshot PATH` and `--output PATH` support isolated
review and experiments. Do not commit synthetic test records as addon data.

The importer validates every page and rejects changing snapshot dates/totals,
incomplete pagination, missing attribution, unavailable storage and malformed
records. It follows only the public corpus host/path, respects rate-limit failures,
and caps an anonymous download at 25 pages to stay below the anonymous hourly allowance.
Bulk API refreshes require a free Everloot key under the provider's terms. Set
`EVERLOOT_API_KEY` in the environment for authenticated downloads of up to 250
pages with 5,000 records per page. The key is sent only in the authorization header,
never in snapshot URLs or generated data; redirects are rejected. Offline builds
and checks need no key and reproduce both anonymous and authenticated snapshots.
Keep the key out of shell history, source files and logs. A fresh
network import must have a source date within two days. Failures before validation
leave existing files untouched. A populated-to-empty refresh requires manual review;
reproduce a separately reviewed snapshot offline if that removal is intentional.
Unchanged vendor data leaves the existing snapshot and generated file unchanged.
The existing generated file must still match its snapshot; reproduce it offline if
the refresh reports a mismatch.

Initial source check (2026-11-05, data as of 03:10:11.401 UTC): 449 NPC sightings,
zero vendor reports, zero qualifying item/vendor offers. Keep coverage statements
in README accurate when new datasets are accepted.

### Weekly data review PRs

`.github/workflows/refresh-forever-data.yml` runs on Mondays at 06:23 UTC and can be
started manually with **Run workflow**. It becomes active after reaching the
repository's default branch. GitHub Actions must be enabled, with **Allow GitHub
Actions to create and approve pull requests** enabled in repository workflow
permissions. No personal token is required; the job requests contents and PR write
permissions for the built-in token.

Set the repository Actions secret `EVERLOOT_API_KEY` to an Everloot API key before
running the workflow. It is exposed only to the refresh step. An absent or expired
key fails the refresh and preserves the last validated dataset. Rotate the secret
when the provider key expires; this credential is separate from GitHub's built-in
token. Everloot associates the key with its account and may contact bulk users
about their projects; see https://everloot.app/docs/api/keys.

The workflow refreshes the external source, combines accepted contributions, updates the README coverage block and one
Unreleased snapshot entry, runs all checks and smoke tests, and proposes only those
data/documentation changes. It maintains one PR on the reserved
`automation/forever-vendor-data` branch. Do not add manual work to that bot-owned
branch; changes there may be regenerated by the PR action. Review the source diff,
removals, price evidence and freshness before merging. The workflow never merges,
changes addon versions, creates tags, or publishes releases.

Source failures fail the run visibly and do not update a PR. Unchanged vendor data
creates no commit or empty PR. If anonymous feed pagination exceeds the request
budget, review the provider's bulk-export/API options before changing the importer;
never accept a truncated result. API or licence changes also require importer review.

`python3 scripts/update_data_docs.py --check` verifies documentation without writing.
Keep `scripts/build_data.py --check` passing in every data update. Since PRs created
with the built-in token may not trigger other workflows, all required checks run
inside the refresh job before it creates a PR. In-game verification is separate.

### Review and accept contributions

Players use `/vic export` and explicitly prepare a CC BY-SA 4.0 export before
copying JSON. Exports use `vic.observations/1`, with a stable random installation
pseudonym, export time, and a list of positive offers. Each offer includes NPC/item
IDs, observation time, exact build/interface, channel when known, quantity, copper
quote, and available stock/cost/discount/location context. Unknown fields are not
inferred. Character GUIDs and unrelated settings are local only. Do not request a
player's entire SavedVariables file.

Before accepting a file, establish that its author is an independent contributor
and its observations came from the live Forever game. Installation pseudonyms are
deduplication aids, not proof of identity or independence. Assign one opaque
`contributor-...` identity per person and reuse it across that person's installs,
alts and exports. Keep the independence assessment outside the public data; the
ledger needs only an opaque identity and a suitable review reference, without
account names or other private details. Never upload or contact anyone automatically.

```sh
python3 scripts/import_contribution.py /path/to/export.json \
    --identity contributor-001 --reference "Reviewed contribution reference" --confirm-live
python3 scripts/build_data.py
python3 scripts/update_data_docs.py
python3 tests/run_tests.py
```

`--confirm-live` records a human review, not an automated inference. A client may
not expose `IsTestBuild`; its export then says `channel: "unknown"` and needs live
provenance established independently. Explicit test/beta records are rejected.
JSON imports never execute Lua. Unknown schema versions/private fields, invalid
costs/coordinates/builds, future export dates, oversized files and checksum/path
violations are rejected before acceptance. Identical accepted files are a no-op.

The importer stores canonical JSON and a SHA-256 in
`scripts/data/contributions/index.json`, together with the reviewed identity,
reference and live confirmation. Commit accepted JSON, the index, rebuilt Lua and
coverage docs together after review. `--root PATH` supports isolated tests; initialize
an isolated index with `{"schema":1,"asOf":null,"files":[]}` before importing.

Compilation requires three independent reviewed contributors for each vendor/item
relation and separately for names, approximate locations and quote contexts.
Repeat files and multiple installations assigned to one contributor count once.
Tied conflicting observations are withheld. Missing items never prove removal.
Records expire after 30 days, retaining the original observation dates. Reviewed
contributions and Everloot must each qualify independently; their reporter counts
are not pooled, because cross-source identities cannot be established automatically.

Prices and quantities remain reported quote evidence, not a generally applicable
purchase price. A matching amount from three players does not establish that a
different character gets the same discount or access. Bundled prices stay hidden;
the observing character's own local quotes remain available.

The builder reads accepted contributions automatically, includes a review-index
checksum and source attribution, and selects newer qualifying offers without
modifying Classic data. The documentation generator reports combined bundled
coverage. Unreviewed submissions do not enter the scheduled workflow.

### Alternative source audit

The [source audit](docs/DATA_SOURCES.md) records inspected revisions, published
contracts, dates, licences and rejection reasons. Merchant Map publishes an
observed-data table, but the inspected vendor observations were all pre-launch and
lacked independent reporter evidence. Polestar's inspected item-source contract is
not a merchant-offer feed. No rows from either project are bundled. Re-audit when
fresh live provenance becomes available rather than importing an inherited baseline.

### Classic Era reference data

`Data.lua` retains the original 1,931-item/956-vendor historical registry. Its exact
source date/build was not recorded; its prices are reference values, not exact
merchant quotes. The legacy generator is retained as `scripts/build_classic_data.py`
and uses `scripts/.cache`. It is not part of the Forever refresh. Rebuilding Classic
requires separately reviewing the upstream data, licences, cached inputs and diff;
do not silently rebuild it while updating Forever.

### In-game acceptance checklist

Automated checks do not constitute in-game verification. Record client version,
build, interface and dataset date when performing these checks on each client:

- Confirm loading, `/vic status`, settings changes and saved-settings persistence.
- Hover indexed items in bags, item-link tooltips and the Auction House; hold and
  release each configured modifier and check for one compact/expanded section.
- On Forever, hold/release the selected controller trigger or shoulder while an
  item tooltip is visible. Confirm both vendor expansion and the normal action-bar
  behavior. Change the two modifier settings, disconnect/reconnect the controller,
  and confirm hidden or unrelated tooltips never reopen.
- Compare vendor identity and location to the merchant in game. Confirm unknown
  faction access and approximate locations are labelled accurately.
- Confirm Forever never shows Classic-only vendors or ambiguous prices. Check
  personal quotes against merchant purchase quantities, alternate costs, reputation
  discounts and vendor-specific differences. Switch characters and confirm quotes
  do not transfer. Disable recording and confirm existing observations survive.
- Verify Classic faction filtering, price references and legacy tooltip hooks.

Live source availability alone does not verify in-game behavior. Populated Forever
rendering and merchant events are tested with synthetic fixtures until the in-game
checklist is performed.

Importer tests use fixed observation times for reproducibility and current source
timestamps when exercising network-refresh freshness checks. Keep these separate
so scheduled checks remain valid after the fixture dates have passed.
Client-isolation smoke tests must use synthetic Classic-only records rather than
assuming a real item never gains independently corroborated Forever vendors.

### UI redesign checks

Browser navigation stores session-only snapshots of searches, filters, selections,
and list offsets. Exercise explicit menu choices, Back after cross-links, tab
restoration, wheel/slider bounds, direct seller tracking, and record expiry.
Check compact results/detail navigation and viewport fitting on both clients.
Check the native AddOns settings panel at wide and narrow viewport widths. Keep the preview and footer clear of all input controls and check that the narrow layout scrolls. Settings reset must require a choice and preserve observations. Preview content is
labelled example data; it must never enter the vendor index. Price qualification
and unknown access remain visible in summary rows. Inspect long names, row actions,
icons, and the embedded contribution view in-game at common UI scales.

Synthetic browser tests exercise compact drill-in, direct seller tracking, slider
bounds, and filter reset preserving the search. Synthetic settings tests select
explicit menu entries while tooltips remain open and confirm reset before applying it.
