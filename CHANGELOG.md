# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- Forever no longer displays historical Classic inventories, locations, faction restrictions, or prices as Forever data.
- Client-specific TOCs use matching Forever or Classic Era interface numbers, preventing flavor mismatch errors during packaging.
- Fixed a Lua syntax error in `Tooltip.lua` caused by invalid method existence check syntax (`tooltip:NumLines and`).

### Added
- Contextual controller expansion on Forever (LT by default), with separate remappable keyboard and controller modifiers, controller-only/off modes, and hints that follow the selected inputs.
- Optional manual JSON exports of Forever observations, with explicit sharing terms and private character/account data excluded.
- Reviewed community contributions in bundled data builds and weekly update PRs, requiring three independent contributors and retaining price context and source checksums.
- Automatic local merchant recording on Forever, with dated observations, character-specific purchase quotes, exact batch quantities, recording controls, and 30-day expiry.
- Forever vendor snapshot: 0 confirmed items and 0 vendors (source observations as of 2026-11-05T03:10:11.401Z).
- Weekly review PRs for confirmed Forever vendor data, with automatic coverage documentation updates and checks before proposing changes.
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
