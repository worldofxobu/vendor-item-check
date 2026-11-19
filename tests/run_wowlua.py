"""Run WoWLua UI tests and capture browser screenshots from the repository root."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
MERCHANT = "merchant_browser.test.wowlua"
ACCOUNT = "account-replay.test.wowlua"
BROWSER = "VendorItemCheckBrowser"
SCREENSHOTS = {
    "merchant-window": (MERCHANT, "renders the native merchant window", "MerchantFrame"),
    "vendor-inventory": (MERCHANT, "renders the vendor inventory", BROWSER),
    "item-sellers": (MERCHANT, "renders the observed sellers", BROWSER),
    "zone-picker": (MERCHANT, "renders the searchable zone picker", BROWSER),
    "advanced-filters": (MERCHANT, "renders the advanced browser filters", BROWSER),
    "no-results": (MERCHANT, "renders no results and zone recovery", BROWSER),
    "unnamed-item": (MERCHANT, "renders an unnamed item", BROWSER),
    "waypoint-set": (MERCHANT, "renders the waypoint set state", BROWSER),
    "waypoint-unavailable": (MERCHANT, "renders the waypoint unavailable state", BROWSER),
    "data-overview": (ACCOUNT, "renders data overview with personal observations", BROWSER),
    "data-status": (ACCOUNT, "renders data status", BROWSER),
    "data-empty": (MERCHANT, "renders the data overview without personal observations", BROWSER),
    "contribute-generate": (ACCOUNT, "renders the contribution generation state", BROWSER),
    "contribute-copy": (ACCOUNT, "renders and selects the complete generated contribution", BROWSER),
    "settings": (MERCHANT, "renders Vendor Item Check in native AddOns settings", "SettingsPanel"),
    "settings-help": (MERCHANT, "renders the contextual settings hint", "VendorItemCheckSettingsHint"),
    "collapsed-tooltip": (MERCHANT, "renders the collapsed native item tooltip", "GameTooltip"),
    "expanded-tooltip": (MERCHANT, "renders the expanded native item tooltip", "GameTooltip"),
    "minimal-tooltip": (MERCHANT, "renders the minimal expanded native item tooltip", "GameTooltip"),
    "accurate-slugs": (ACCOUNT, "shows the recorded Accurate Slugs price", BROWSER),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--wowlua", help="Path to the WoWLua CLI")
    parser.add_argument("--wow", type=Path, help="World of Warcraft installation path")
    parser.add_argument("--screenshots", type=Path, help="Directory for rendered screenshots")
    parser.add_argument("--compact", action="store_true", help="Use a small emulated viewport")
    parser.add_argument("--filter", help="Only run tests whose name contains this text")
    args = parser.parse_args()

    wowlua = args.wowlua or shutil.which("wowlua")
    if not wowlua:
        executable = "wowlua.exe" if os.name == "nt" else "wowlua"
        wowlua = Path.home() / ".wowlua" / "bin" / executable
        if not wowlua.is_file():
            parser.error("WoWLua is required. Set --wowlua or add it to PATH.")
    wowlua = str(Path(wowlua).resolve())
    env = os.environ.copy()
    env.setdefault("WOWLUA_HOME", str(Path.home() / ".wowlua"))
    if args.wow:
        env["WOWLUA_WOW_PATH"] = str(args.wow.resolve())

    manifest_args = []
    compact_manifest = None
    try:
        if args.compact:
            manifest = json.loads((ROOT / "wowlua.json").read_text(encoding="utf-8"))
            manifest["build"]["out"] = ".cache/wowlua/compact"
            manifest["test"]["screen"] = {"width": 480, "height": 800, "uiScale": 1.15}
            with tempfile.NamedTemporaryFile(
                mode="w", encoding="utf-8", dir=ROOT,
                prefix=".wowlua-compact-", suffix=".json", delete=False,
            ) as config:
                compact_manifest = Path(config.name)
                json.dump(manifest, config)
            manifest_args = ["--manifest", str(compact_manifest)]

        def run(*options):
            subprocess.run([wowlua, *manifest_args, *options], cwd=ROOT, env=env, check=True)

        if args.screenshots:
            output = args.screenshots.resolve()
            output.mkdir(parents=True, exist_ok=True)
            for name, (test_file, test, frame) in SCREENSHOTS.items():
                if args.filter and args.filter not in test:
                    continue
                run("screenshot", f"tests/{test_file}", "--flavor", "camelot", "--locked",
                    "--test", test, "--frame", frame, "--output", str(output / (name + ".png")))
        else:
            filters = [args.filter] if args.filter else []
            run("test", "--flavor", "camelot", "--locked", *filters)
    finally:
        if compact_manifest:
            compact_manifest.unlink()


if __name__ == "__main__":
    main()
