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
   ```

4. Update `CHANGELOG.md` for user-facing changes under `[Unreleased]`.
5. Avoid adding heavy runtime libraries unless the benefit clearly outweighs the addon size and maintenance cost.

## Style

- Use four spaces for Lua indentation.
- Prefer descriptive names over abbreviations.
- Keep tooltip text concise and consistent with the default WoW interface.
- Guard client API calls that may be absent or temporarily unavailable across client flavors.

## Development & Data Pipeline

The addon database is compiled into `VendorItemCheck/Data.lua` using the build script:

```sh
python3 scripts/build_data.py
```

This ensures the addon runs with zero dependencies for players while maintaining a completely reproducible build pipeline.
