# Vendor Item Check UI implementation

[Approved Figma specification and screen index](https://www.figma.com/design/1zE9AwAqZWXlYUIPnWtpXX/Vendor-Item-Check?node-id=51-1172)

## Implemented and checked with fixtures

- [x] Active coverage, per-character quote isolation, independent merchant learning and legacy preference migration. Foundation commit `e5964af`.
- [x] Compact Items/Vendors shell, history, searchable zone controls, seller filters, inventory grid and stock paging, and native waypoint ownership. Screen and integration commit `1a93abf`.
- [x] Short native tooltip sections, settings preview, and shared Data, Status and Contribute views. Fixture checks cover input overlap, reset and export round-trip, read-only text, selection, and unsupported export.
- [x] Python runner (33 tests), seven Lua smoke suites, and whitespace validation.

## Pending client and Figma acceptance

- [ ] Test on both live clients and record build, interface, dataset date, native map/control availability, tooltip coexistence, combat safety, and full selection of a large JSON document.
- [ ] Compare the native UI against each approved frame at standard and constrained UI scales. Current layouts use native templates. Crest and portrait artwork, detailed frame styling, focus help, and visual polish need a follow-up comparison.
- [ ] Validate reputation and promotion evidence against the target APIs before enabling REP PRICE or SALE badges. Enable the CurseForge contact actions only after a verified project contact URL is supplied.
