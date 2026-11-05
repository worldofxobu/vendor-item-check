# Forever vendor source audit

Reviewed 2026-11-05. Eligibility requires live Forever observations, usable
per-record provenance, three independent reports for shared facts, reproducible
inputs, and redistribution terms. Personal observations can be used immediately
on the observing account; they are not automatically published or corroborated.

## Everloot

- Feed: <https://everloot.app/api/corpus/public?kinds=vendor&limit=500>
- Contract and terms: <https://everloot.app/docs/api> and
  <https://everloot.app/docs/licence>.
- The recheck returned zero vendor records, with `dataAsOf`
  `2026-11-05T06:40:10.749Z`. This establishes this feed's coverage at that time;
  it does not establish that other projects have no data.
- Public observations carry installation pseudonyms and timestamps. The vendor
  schema lacks purchase quantity, alternate costs, discount context and exact
  client build. Never infer those fields from Classic data or matching item IDs.
- Player data is CC BY-SA 4.0. The existing adapter remains eligible for qualifying
  future records, with its current corroboration and price restrictions.

## Merchant Map

- Project: <https://www.curseforge.com/wow/addons/merchant-map>.
- Source inspected at commit `dbfedd3577dfda8e8c592359a57c01f252af212c`:
  [VendorData.lua](https://github.com/knofle/MerchantMap/blob/dbfedd3577dfda8e8c592359a57c01f252af212c/VendorData.lua)
  and [VerifiedData.lua](https://github.com/knofle/MerchantMap/blob/dbfedd3577dfda8e8c592359a57c01f252af212c/VerifiedData.lua).
- `VendorData.lua` identifies a Questie-derived baseline; the file being distributed
  for Forever does not establish current live inventory.
- `VerifiedData.lua` is explicitly described as generated from in-game observations.
  Its 220 shipped vendor entries have last-seen timestamps from
  2026-09-24 22:21:11 UTC through 2026-10-11 02:30:11 UTC. None is after the live
  launch cutoff, 2026-11-04 23:00 UTC.
- That table exposes a last-seen time and price/cost fields, but not independent
  reporter evidence, exact client builds, or an explicit purchase quantity field.
- The project is GPLv3. No database rows or code were copied. The inspected snapshot
  does not satisfy the live and three-report policy, so no adapter is added.

## Polestar forever-db

- Published dataset: <https://github.com/fitzforge/polestar/tree/next/forever-db>.
- Inspected index: version `2026.11.1`, schema version `1`, client build
  `1.60.1.70532`, producer commit `6d0de256e66674512e453a2990076d84f7e979bb`.
- [Documentation](https://github.com/fitzforge/polestar/blob/next/forever-db/README.md)
  describes quests, NPCs and quest-relevant item sources, built from mixed sources.
  Its [item-source schema](https://github.com/fitzforge/polestar/blob/next/forever-db/schema/item_source.schema.json)
  identifies item/source entities and optional loot chance. It has no merchant-offer
  relation, inventory quote, purchase quantity, or per-offer reporter/date evidence.
- The database tables are GPL-3.0; its own documentation/schema layer is CC BY 4.0.
  No rows or code were copied. The inspected public contract cannot supply the
  verified merchant offers required here, so no adapter is added.

## Accepted path

Keep collecting direct positive observations through the game's merchant APIs.
Exports retain builds, dates, quantities and cost context; a maintainer establishes
independent contributors and live provenance before accepting them into the review
ledger. Three qualifying contributors are needed before any fact is bundled.
No candidate in this audit supplies an eligible starter import under that policy.

Re-audit a candidate when it publishes fresh live observations and sufficient
provenance. Record the inspected revision, licences and evidence before adding an
adapter; never silently reinterpret an inherited or beta dataset as live data.
