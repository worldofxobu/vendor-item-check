# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
