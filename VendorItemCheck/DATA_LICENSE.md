# Vendor data attribution

## Forever

Personal observations remain local unless the player explicitly prepares and
shares an export. Shared Vendor Item Check exports and their derived bundled
database are CC BY-SA 4.0, credited to Vendor Item Check contributors. The reviewed
JSON inputs retain installation pseudonyms and review references in the source
repository's `scripts/data/contributions/` directory. Character identifiers and
unrelated saved settings are not included in exports.

The contribution transformation validates fields, deduplicates each reviewed
contributor, requires three independent reports, preserves quote context, excludes
old/test observations, rounds confirmed positions and generates Lua. Builds that
include contributions carry a checksum of the review index and combined attribution.

Data from Everloot (https://everloot.app), CC BY-SA 4.0.

Credit: Everloot contributors. Source: https://everloot.app/database

The public observation snapshot and derived Forever database are distributed under
Creative Commons Attribution-ShareAlike 4.0 International:
https://creativecommons.org/licenses/by-sa/4.0/

Legal text: https://creativecommons.org/licenses/by-sa/4.0/legalcode

Changes made here: exclude pre-launch and old observations, require independent
corroboration, omit unconfirmed fields, aggregate vendor/item relations, round
confirmed locations, retain raw price evidence without treating it as a unit
purchase price, and convert to Lua. Provenance and a source checksum are included
in DataForever.lua. Reproducible inputs are in the source repository's
scripts/data/forever-source.json. An empty dataset contains no confirmed offers.

Everloot's software is not included. No Merchant Map or Polestar data/code is included.
This data licence does not change the
licence of Vendor Item Check's independently written addon or build code.

## Classic Era

The historical Classic registry retains its existing sources:

- pfQuest, by Shagu: https://github.com/shagu/pfQuest
- wow-classic-items, by nexus-devs: https://github.com/nexus-devs/wow-classic-items

Its exact observation date and client build were not recorded by the original
pipeline. These records are not evidence of Forever inventories or prices.

World of Warcraft and its game content belong to Blizzard Entertainment.
Vendor Item Check is an independent community addon.
