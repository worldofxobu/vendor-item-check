#!/usr/bin/env python3
"""Keep player-facing coverage and the Unreleased snapshot entry in sync."""

import argparse
import json
import re

from build_data import ROOT, SNAPSHOT, compile_sources

START = "<!-- forever-coverage:start -->"
END = "<!-- forever-coverage:end -->"
ENTRY = "- Forever vendor snapshot:"


def update(root, dataset, check=False):
    items, vendors = len(dataset["items"]), len(dataset["vendors"])
    date = dataset["metadata"]["dataAsOf"]
    counts = f"{items:,} confirmed {'item' if items == 1 else 'items'} and {vendors:,} {'vendor' if vendors == 1 else 'vendors'}"
    summary = f"**Bundled Forever coverage:** {counts}. Source observations as of `{date}`."
    if not items:
        summary += " No qualifying offers are bundled; Forever tooltips remain unchanged for unknown items."
    readme = root / "README.md"
    text = readme.read_text()
    pattern = re.escape(START) + r".*?" + re.escape(END)
    updated_readme, count = re.subn(pattern, START + "\n" + summary + "\n" + END, text, flags=re.S)
    if count != 1:
        raise ValueError("README must have exactly one Forever coverage block")

    changelog = root / "CHANGELOG.md"
    history = changelog.read_text()
    before, separator, unreleased = history.partition("## [Unreleased]\n")
    if not separator:
        raise ValueError("Missing Unreleased changelog section")
    section, published_separator, published = unreleased.partition("\n## [")
    line = f"{ENTRY} {counts} (source observations as of {date})."
    if ENTRY in section:
        section = re.sub(r"^- Forever vendor snapshot:.*$", line, section, flags=re.M)
    elif "### Added\n" in section:
        section = section.replace("### Added\n", "### Added\n" + line + "\n", 1)
    else:
        section += "\n### Added\n\n" + line + "\n"
    updated_history = before + separator + section + published_separator + published
    changes = [(readme, text, updated_readme), (changelog, history, updated_history)]
    if check:
        if any(old != new for _, old, new in changes):
            raise ValueError("Coverage documentation differs from the committed snapshot")
    else:
        for path, old, new in changes:
            if old != new:
                path.write_text(new)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    update(ROOT, compile_sources(json.loads(SNAPSHOT.read_text())), args.check)
