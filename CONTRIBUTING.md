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
   ```

4. Update `CHANGELOG.md` for user-facing changes under `[Unreleased]`.
5. Avoid adding heavy runtime libraries unless the benefit clearly outweighs the addon size and maintenance cost.

## Style

- Use four spaces for Lua indentation.
- Prefer descriptive names over abbreviations.
- Keep tooltip text concise and consistent with the default WoW interface.
- Guard client API calls that may be absent or temporarily unavailable across client flavors.

## Vendor data pipeline

The addon ships separate Classic Era and Forever datasets. Runtime code selects the
dataset using guarded client version/interface APIs. Unsupported or unknown clients
receive an empty dataset. Saved settings remain compatible.

### Forever source and confidence

Source: [Everloot public corpus](https://everloot.app/docs/api), filtered to `vendor`
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
and caps a refresh at 25 pages to stay below the anonymous hourly allowance. A fresh
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

The workflow refreshes the source, updates the README coverage block and one
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
- Compare vendor identity and location to the merchant in game. Confirm unknown
  faction access and approximate locations are labelled accurately.
- Confirm Forever never shows Classic-only vendors or ambiguous prices. When a
  future source supplies unit prices, verify purchase quantities, alternate costs,
  reputation discounts and vendor-specific differences before enabling display.
- Verify Classic faction filtering, price references and legacy tooltip hooks.

Live source availability alone does not verify in-game behavior. Until the Forever
feed has qualifying offers, populated Forever rendering is tested with synthetic
fixtures only.

Importer tests use fixed observation times for reproducibility and current source
timestamps when exercising network-refresh freshness checks. Keep these separate
so scheduled checks remain valid after the fixture dates have passed.
