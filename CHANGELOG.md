# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

- Added Data & Sharing with current coverage, client status, and explicit generation and selection of contribution JSON.
- Updated the browser with a charcoal-and-brass layout, inset results, paged merchant inventory, stock filters, searchable zones, and native waypoint controls.
- Fixed overlapping browser labels and seller offers at in-game UI scales and hid scrollbars for short lists.
- Rebuilt the AddOns settings page with separate control groups, a framed live preview, and a stacked layout for narrow panels.
- Simplified tooltip details and made tooltip enhancement independent of merchant learning.


### Changed
- Replace cycling browser filters and expansion controls with explicit choice menus.
- Browse scrollable item/vendor lists with remembered tab state, Back navigation, direct seller tracking, and expandable offer details.
- Add compact screen layouts, browser help and coverage details, grouped settings with a sample preview, and confirmation before resetting settings.
- Fit sharing and detail windows to the viewport and make settings scrollable.
- Keep tracking coordinates visible when map waypoint creation fails.


- Open the browser with /vic and settings with /vic settings; restore item/vendor browsing context with Back. Simplify result labels and keep the browser on screen.

### Fixed
- Browser headings, page counts, and expanded offer details stay visible above their panel backgrounds. The browser stays above the default HUD, and inventory tiles show prices and stock on separate lines.
- The item browser now honors **Prioritize nearby vendors** when ordering sellers.
- Forever no longer displays historical Classic inventories, locations, faction restrictions, or prices as Forever data.
- Client-specific TOCs use matching Forever or Classic Era interface numbers, preventing flavor mismatch errors during packaging.
- Fixed a Lua syntax error in `Tooltip.lua` caused by invalid method existence check syntax (`tooltip:NumLines and`).

### Added
- Searchable item and vendor browser (`/vic browse`) with source, zone and faction filters, linked known inventories, contextual prices, and session-only vendor tracking with native map waypoints where supported.
- Contextual controller expansion on Forever (LT by default), with separate remappable keyboard and controller modifiers, controller-only/off modes, and hints that follow the selected inputs.
- Optional manual JSON exports of Forever observations, with explicit sharing terms and private character/account data excluded.
- Reviewed community contributions in bundled data builds and weekly update PRs, requiring three independent contributors and retaining price context and source checksums.
- Automatic local merchant recording on Forever, with dated observations, character-specific purchase quotes, exact batch quantities, recording controls, and 30-day expiry.
- Forever vendor snapshot: 2 confirmed items and 2 vendors (source observations as of 2026-11-09T08:20:14.478Z).
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
