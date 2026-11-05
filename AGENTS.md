# Repository guidance

- Read `CONTRIBUTING.md` before changing code or release configuration. Keep changes focused on the request and preserve unrelated work.
- Preserve the addon's supported WoW Forever and Classic Era client and Lua compatibility. Guard unavailable client APIs, keep saved data compatible, and avoid new runtime dependencies unless clearly justified.
- Maintain accurate `## Interface:` headers across supported clients (e.g. `16001` for Forever, active `1.15.x` interface numbers such as `11509, 11508, ...` for Classic Era) in both base and flavor-specific TOC files to prevent "out of date" warnings on live patches.
- Follow existing code style and native WoW UI conventions. Keep tooltips compact and routine addon behavior quiet.
- Keep `README.md` focused on installing, configuring, and using the addon. Put contributor and release procedures in `CONTRIBUTING.md`; keep agent instructions here. Public addon documentation should contain no conversation history, agent commentary, or internal workflow notes.
- Keep documentation accurate to implemented behavior. Record user-facing addon changes under `Unreleased` in `CHANGELOG.md`; do not rewrite published release history or add routine repository housekeeping to the changelog.
- For code changes, run the test runner `python3 tests/run_tests.py` and smoke tests. Report what was verified and any checks that could not run; do not claim in-game testing without performing it.
- Commit continuously as coherent units of work are completed and relevant checks pass; do not leave all completed work for one final commit. Review the staged diff before each commit and use focused commits with clear messages. Push only when requested or already authorized; do not overwrite unrelated changes or rewrite shared history.
- Update documentation alongside implementation in the same commit: player usage and limitations in `README.md`, contributor/data-refresh/release procedures in `CONTRIBUTING.md`, and agent guidance here. Record user-facing changes under `Unreleased` in `CHANGELOG.md`; keep housekeeping out of the changelog.
- Treat Forever and Classic Era data as separate sources of truth. Never present Classic vendor inventories, locations, faction access, or prices as verified Forever facts. Keep source attribution, observation dates, and reproducible refresh inputs with generated data. Failed or incomplete refreshes must preserve the last validated dataset.
- Change versions, create tags, or publish releases only when requested. Follow the release procedure and verify the installable ZIP layout when changing packaging. Exclude tests, contributor docs, and agent instructions from addon packages.
- Keep credentials and tokens out of repository files, logs, and public documentation.
