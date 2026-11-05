#!/usr/bin/env python3
"""Accept a manually reviewed export into the reproducible contribution ledger."""
import argparse
import sys
from pathlib import Path
from contributions import ROOT, accept_file

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path)
    parser.add_argument("--identity", required=True, help="Opaque contributor-... id; reuse for this person's other installs")
    parser.add_argument("--reference", required=True, help="Review reference establishing independent contributor and live data")
    parser.add_argument("--confirm-live", action="store_true", help="Confirm live-server provenance was reviewed, including unknown-channel records")
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    try:
        changed = accept_file(args.file, args.root, args.identity, args.reference, args.confirm_live)
        print("Accepted reviewed contribution; rebuild data and coverage docs." if changed else "Identical contribution already accepted; no changes.")
    except (ValueError, OSError, KeyError, TypeError) as error:
        sys.exit("Contribution rejected: " + str(error))
