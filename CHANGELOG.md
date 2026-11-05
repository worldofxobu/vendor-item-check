# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Forever no longer displays historical Classic inventories, locations, faction restrictions, or prices as Forever data.
- Both TOC variants accept the Forever interface alongside supported Classic Era interfaces.
- Fixed a Lua syntax error in `Tooltip.lua` caused by invalid method existence check syntax (`tooltip:NumLines and`).

### Added
- Separate Forever dataset using corroborated live Everloot observations, with source metadata in `/vic status`, independent expiry, and explicit unknown access/location handling.
- Reproducible offline Forever data builds and an explicit refresh command. The initial source snapshot has no qualifying vendor offers; unknown items receive no tooltip section.
- Forever data attribution and clear coverage and price limitations. Ambiguous purchase prices are omitted.
- Initial release of Vendor Item Check for WoW Classic Era and WoW Forever.
- Compact item tooltip indicator showing if an item can be bought at a vendor.
- Dynamic Alt-key expansion showing who sells the item, where (zone & coordinates), and faction tag.
- Instant tooltip refresh on modifier key change without moving the mouse cursor.
- Faction filtering (Alliance vs Horde vs Neutral).
- Proximity-based vendor sorting prioritizing vendors in the player's current zone and closest coordinates.
- Configurable maximum vendor display limit with overflow counter (`+N more`).
- Embedded Classic Era vendor database with 1,931 items and 956 vendor NPCs.
- Native configuration panel with slash commands (`/vic`, `/vendorcheck`).
- Standalone test suite with automated verification.
