#!/usr/bin/env python3
"""Build the Forever database from reproducible, public Everloot observations.

Python standard library only. Network refreshes are explicit; the default is offline.
"""

import argparse
from collections import defaultdict
from datetime import datetime, timezone, timedelta
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SOURCE = "https://everloot.app/api/corpus/public?kinds=vendor,npc_sighting&limit=500"
SNAPSHOT = ROOT / "scripts/data/forever-source.json"
OUTPUT = ROOT / "VendorItemCheck/DataForever.lua"
LAUNCH = datetime(2026, 11, 4, 23, tzinfo=timezone.utc)
MAX_AGE_DAYS = 30
MIN_REPORTERS = 3
CREDIT = "Data from Everloot (https://everloot.app), CC BY-SA 4.0."


def timestamp(value):
    if not isinstance(value, str):
        raise ValueError("Missing observation/snapshot timestamp")
    result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if result.tzinfo is None:
        raise ValueError("Timestamp must include timezone")
    return result


def positive_int(value):
    return type(value) is int and 0 < value <= 9007199254740991


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": "VendorItemCheck-Builder/2"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            # Pagination is public and must never redirect to an unrelated host.
            if urllib.parse.urlsplit(response.url).netloc != "everloot.app":
                raise ValueError("Unexpected response host")
            return json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == 429:
            raise ValueError("Source rate limited; retry after " + error.headers.get("Retry-After", "the rate-limit window")) from error
        raise


def validate_page(page, offset, total=None, data_as_of=None):
    if not isinstance(page, dict) or not {"ok", "records", "offset", "total", "next", "dataAsOf", "attribution"} <= page.keys():
        raise ValueError("Incomplete source response")
    if page.get("ok") is not True or page.get("unreachable"):
        raise ValueError("Source is unavailable; keeping the existing database")
    if page.get("offset") != offset or not isinstance(page.get("records"), list):
        raise ValueError("Malformed or out-of-order source page")
    count = page.get("total")
    if type(count) is not int or count < 0 or (total is not None and total != count):
        raise ValueError("Source total changed during pagination")
    if data_as_of is not None and page.get("dataAsOf") != data_as_of:
        raise ValueError("Source snapshot changed during pagination; retry")
    timestamp(page.get("dataAsOf"))
    attribution = page.get("attribution", {})
    if attribution.get("licence") != "CC BY-SA 4.0" or attribution.get("credit") != CREDIT:
        raise ValueError("Missing or changed source attribution; review before importing")
    return count


def download_snapshot(get=fetch):
    pages, url, offset, total, data_as_of, visited = [], SOURCE, 0, None, None, set()
    while url:
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme != "https" or parsed.netloc != "everloot.app" or parsed.path != "/api/corpus/public" or url in visited:
            raise ValueError("Unsafe or repeated pagination URL")
        if len(visited) >= 25:
            raise ValueError("Feed exceeds unauthenticated request budget; review bulk import")
        visited.add(url)
        page = get(url)
        total = validate_page(page, offset, total, data_as_of)
        data_as_of = page["dataAsOf"]
        pages.append({"url": url, "response": page})
        offset += len(page["records"])
        url = page.get("next")
        if url and (not page["records"] or offset >= total):
            raise ValueError("Invalid pagination progress")
    if offset != total:
        raise ValueError("Incomplete source download")
    return {"schema": 1, "source": SOURCE, "pages": pages}


def consensus(values):
    """Only one corroborated value may win. Repeats from one install count once."""
    groups = defaultdict(set)
    for reporter, value in values:
        groups[value].add(reporter)
    winners = [(value, len(reporters)) for value, reporters in groups.items() if len(reporters) >= MIN_REPORTERS]
    return winners[0] if len(winners) == 1 else (None, 0)


def confirmation_expiry(dates):
    # Confirmation ends when fewer than three independent reports remain fresh.
    third_newest = sorted((timestamp(date) for date in dates), reverse=True)[MIN_REPORTERS - 1]
    return int((third_newest + timedelta(days=MAX_AGE_DAYS)).timestamp())


def compile_snapshot(snapshot):
    if snapshot.get("schema") != 1 or snapshot.get("source") != SOURCE or not snapshot.get("pages"):
        raise ValueError("Unsupported source snapshot")
    records, offset, total, as_of = [], 0, None, None
    expected_url = SOURCE
    for saved in snapshot["pages"]:
        if saved["url"] != expected_url:
            raise ValueError("Snapshot page chain is incomplete")
        page = saved["response"]
        total = validate_page(page, offset, total, as_of)
        as_of = page["dataAsOf"]
        offset += len(page["records"])
        expected_url = page.get("next")
        records.extend(page["records"])
    if offset != total or expected_url is not None:
        raise ValueError("Snapshot is incomplete")
    cutoff = timestamp(as_of) - timedelta(days=MAX_AGE_DAYS)
    latest = {}
    for record in records:
        kind = record.get("kind")
        if kind not in ("vendor", "npc_sighting"):
            raise ValueError("Unexpected record kind")
        seen = timestamp(record.get("capturedAt"))
        if seen > timestamp(as_of):
            raise ValueError("Observation is newer than the snapshot")
        # The public corpus is Forever-specific but older rows may be from beta.
        if seen < max(LAUNCH, cutoff):
            continue
        build = record.get("build")
        if build is not None and not re.fullmatch(r"1\.60\.\d+\.\d+", str(build)):
            continue
        if record.get("channel", "live") != "live":
            continue
        reporter = record.get("installId", "")
        if not re.fullmatch(r"pub-[0-9a-f]{32}", reporter):
            continue  # Missing public pseudonyms cannot corroborate each other.
        npc = record.get("vendorNpcId" if kind == "vendor" else "npcId")
        if not positive_int(npc):
            raise ValueError("Invalid NPC id")
        key = kind, npc, reporter
        if key not in latest or timestamp(latest[key]["capturedAt"]) < seen:
            latest[key] = record
        elif timestamp(latest[key]["capturedAt"]) == seen and latest[key] != record:
            # Tied conflicting reports from one install provide no evidence.
            latest[key] = {"kind": kind, "capturedAt": record["capturedAt"], "conflict": True}

    offers, names, positions = defaultdict(list), defaultdict(list), defaultdict(list)
    name_dates, position_dates = {}, {}
    for (kind, npc, reporter), record in latest.items():
        if record.get("conflict"):
            continue
        if kind == "vendor":
            if not isinstance(record.get("items"), list) or not record["items"]:
                raise ValueError("Malformed merchant inventory")
            seen_ids = set()
            for item in record["items"]:
                iid, price = item.get("itemId"), item.get("priceCopper")
                if not positive_int(iid) or type(price) is not int or price < 0 or iid in seen_ids:
                    raise ValueError("Invalid or duplicate merchant item/price")
                seen_ids.add(iid)
                offers[npc, iid].append((reporter, record["capturedAt"], price))
        else:
            name = record.get("name")
            if isinstance(name, str) and name.strip() and len(name) <= 120:
                names[npc].append((reporter, name))
                name_dates[npc, reporter] = record["capturedAt"]
            # Player positions never become NPC pins. Interaction positions are approximate.
            if record.get("positionKind") not in ("npc", "vignette", "interaction"):
                continue
            map_id, x, y = record.get("mapId"), record.get("x"), record.get("y")
            if not positive_int(map_id) or any(type(v) not in (int, float) or not math.isfinite(v) or not 0 < v <= 100 for v in (x, y)):
                continue
            # Rounded consensus cells are approximate even for exact upstream pins.
            positions[npc].append((reporter, (map_id, round(x), round(y), True)))
            position_dates[npc, reporter] = record["capturedAt"]

    vendors, items = {}, {}
    for (npc, iid), evidence in sorted(offers.items()):
        if len(evidence) < MIN_REPORTERS:
            continue
        name, _ = consensus(names[npc])
        position, _ = consensus(positions[npc])
        vendor = {"name": name or ("Vendor " + str(npc)), "faction": "?"}
        if name:
            vendor["nameExpires"] = confirmation_expiry([name_dates[npc, r] for r, value in names[npc] if value == name])
        if position:
            vendor.update(zip(("mapID", "x", "y", "approximate"), position))
            vendor["locationExpires"] = confirmation_expiry([position_dates[npc, r] for r, value in positions[npc] if value == position])
        vendors[npc] = vendor
        # The current upstream contract omits quantity, currencies and discount context.
        # Preserve corroborated raw price evidence, but NEVER turn it into a unit price.
        raw_price, price_reporters = consensus([(r, p) for r, _, p in evidence])
        offer = {"reporters": len(evidence), "lastSeen": max(t for _, t, _ in evidence),
                 "expires": confirmation_expiry([t for _, t, _ in evidence]),
                 "priceContext": "unknown"}
        if raw_price is not None:
            offer.update(observedCopper=raw_price, priceReporters=price_reporters)
        items.setdefault(iid, {"v": [], "offers": {}})["v"].append(npc)
        items[iid]["offers"][npc] = offer
    return {"metadata": {"client": "Forever", "source": "Everloot", "sourceURL": "https://everloot.app",
                          "credit": CREDIT, "licence": "CC BY-SA 4.0", "dataAsOf": as_of,
                          "build": "Unrecorded by source (live post-launch observations)",
                          "maxAgeDays": MAX_AGE_DAYS, "minimumReporters": MIN_REPORTERS},
            "vendors": vendors, "items": items}


def lua(value):
    if isinstance(value, dict):
        return "{\n" + "\n".join("    [" + lua(k) + "] = " + lua(v) + "," for k, v in sorted(value.items(), key=lambda pair: (isinstance(pair[0], str), pair[0]))) + "\n}"
    if isinstance(value, list):
        return "{ " + ", ".join(lua(v) for v in value) + " }"
    if isinstance(value, str):
        # Lua 5.1 accepts decimal byte escapes, not JSON's unicode escapes.
        escaped = ''.join('\\%03d' % ord(char) if ord(char) < 32 or char in ('"', '\\') or ord(char) == 127 else char for char in value)
        return '"' + escaped + '"'
    if type(value) is bool:
        return "true" if value else "false"
    if type(value) in (int, float):
        return str(value)
    raise ValueError("Unsupported Lua value")


def render(dataset, checksum):
    metadata = dict(dataset["metadata"], snapshotSHA256=checksum)
    # Adapt vendors to the existing compact registry; map metadata remains named.
    vendors = {}
    for npc, vendor in dataset["vendors"].items():
        vendors[npc] = {1: vendor["name"], 2: "Location unknown", 3: vendor["faction"],
                        4: vendor.get("x", 0), 5: vendor.get("y", 0)}
        for key in ("mapID", "approximate", "nameExpires", "locationExpires"):
            if key in vendor:
                vendors[npc][key] = vendor[key]
    # Mixed numeric/string keys need a stable ordering.
    return ("-- Generated by scripts/build_data.py; DO NOT EDIT.\n"
            "-- " + CREDIT + "\n-- Derived data: CC BY-SA 4.0; see DATA_LICENSE.md.\n"
            "local _, VIC = ...\nVIC.Datasets = VIC.Datasets or {}\n"
            "VIC.Datasets.forever = { metadata = " + lua(metadata) + ", vendors = " + lua(vendors) +
            ", items = " + lua(dataset["items"]) + " }\n")


def encode(snapshot):
    return (json.dumps(snapshot, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--refresh", action="store_true", help="Fetch current public data instead of the checked-in snapshot")
    parser.add_argument("--check", action="store_true", help="Check offline reproducibility without writing")
    parser.add_argument("--snapshot", type=Path, default=SNAPSHOT)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    if args.refresh and args.check:
        parser.error("--refresh and --check are mutually exclusive")
    old_snapshot = json.loads(args.snapshot.read_text()) if args.snapshot.exists() else None
    old_dataset = compile_snapshot(old_snapshot) if old_snapshot else None
    snapshot = download_snapshot() if args.refresh else json.loads(args.snapshot.read_text())
    dataset = compile_snapshot(snapshot)
    if args.refresh and datetime.now(timezone.utc) - timestamp(dataset["metadata"]["dataAsOf"]) > timedelta(days=2):
        raise ValueError("Source snapshot is over two days old; keeping previous output")
    content = encode(snapshot)
    generated = render(dataset, hashlib.sha256(content).hexdigest())
    previous = args.output.read_text() if args.output.exists() else ""
    # A successful empty response must not silently erase a previously populated dataset.
    if args.refresh and not dataset["items"] and previous and '["offers"]' in previous:
        raise ValueError("Refresh would empty a populated database; manual review required")
    if old_dataset:
        old_items, new_items = set(old_dataset["items"]), set(dataset["items"])
        old_vendors, new_vendors = set(old_dataset["vendors"]), set(dataset["vendors"])
        changed = sum(old_dataset["items"][iid] != dataset["items"][iid] for iid in old_items & new_items)
        print(f"Changes: items +{len(new_items - old_items)}/-{len(old_items - new_items)}, "
              f"vendors +{len(new_vendors - old_vendors)}/-{len(old_vendors - new_vendors)}, "
              f"{changed} item offer/price/freshness changes")
        if args.refresh and previous and all(old_dataset[key] == dataset[key] for key in ("vendors", "items")):
            expected = render(old_dataset, hashlib.sha256(encode(old_snapshot)).hexdigest())
            if previous != expected:
                raise ValueError("Existing output differs from its snapshot; reproduce it offline before refreshing")
            print("No changes to vendor data; preserving the existing reproducible snapshot.")
            return
    if args.check:
        if previous != generated:
            raise ValueError("Generated Forever data differs from its source snapshot")
    else:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        if args.refresh:
            args.snapshot.parent.mkdir(parents=True, exist_ok=True)
            args.snapshot.write_bytes(content)
        args.output.write_text(generated)
    print(f"Forever coverage: {len(dataset['items'])} items, {len(dataset['vendors'])} vendors; data as of {dataset['metadata']['dataAsOf']}")
    if not dataset["items"]:
        print("No corroborated live Forever vendor offers. Unknown items will have no vendor section.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError) as error:
        sys.exit("Data build failed: " + str(error))
