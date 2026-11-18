"""Run WoWLua browser tests from a temporary addon project."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
TEST_FILE = "merchant_browser.test.wowlua"
SCREENSHOTS = {
    "merchant-window": ("renders the native merchant window", "MerchantFrame"),
    "vendor-inventory": ("renders the vendor inventory", "VendorItemCheckBrowser"),
    "item-sellers": ("renders the observed sellers", "VendorItemCheckBrowser"),
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

    with tempfile.TemporaryDirectory(prefix="vic-wowlua-") as temp_dir:
        project = Path(temp_dir) / "VendorItemCheck"
        shutil.copytree(ROOT / "VendorItemCheck", project)

        def run(*options):
            subprocess.run([wowlua, *options], cwd=project, env=env, check=True)

        run("init", "--from-toc", "VendorItemCheck.toc", "--no-pkgmeta", "--offline")
        manifest_path = project / "wowlua.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest["test"] = {"blizzard-ui": True}
        if args.compact:
            manifest["test"]["screen"] = {"width": 600, "height": 460, "uiScale": 1.15}
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        test_path = project / "tests" / TEST_FILE
        test_path.parent.mkdir()
        shutil.copy2(ROOT / "tests" / TEST_FILE, test_path)

        if args.screenshots:
            output = args.screenshots.resolve()
            output.mkdir(parents=True, exist_ok=True)
            for name, (test, frame) in SCREENSHOTS.items():
                if args.filter and args.filter not in test:
                    continue
                run("screenshot", str(test_path.relative_to(project)), "--flavor", "camelot", "--locked",
                    "--test", test, "--frame", frame, "--output", str(output / (name + ".png")))
        else:
            filters = [args.filter] if args.filter else []
            run("test", "--flavor", "camelot", "--locked", *filters)


if __name__ == "__main__":
    main()
