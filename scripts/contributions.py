"""Validate explicit, maintainer-reviewed VIC contributions. Never evaluate Lua."""

from collections import defaultdict
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1] / "scripts/data/contributions"
MAX_BYTES = 10 * 1024 * 1024
MAX_INTEGER = 9007199254740991
RECORD_FIELDS = {"vendorId", "itemId", "vendorName", "observedAt", "build", "interface", "channel",
                 "playerFaction", "priceCopper", "quantity", "stock", "canPurchase", "hasExtendedCost",
                 "discount", "costsComplete", "costs", "location"}


def canonical(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False) + "\n").encode("utf-8")


def integer(value, minimum=0):
    return type(value) is int and minimum <= value <= MAX_INTEGER


def text(value, maximum=120):
    return isinstance(value, str) and 0 < len(value) <= maximum and not any(ord(c) < 32 or c == "|" for c in value)


def validate_document(document):
    required = {"schema", "client", "licence", "reporterId", "exportedAt", "records"}
    if not isinstance(document, dict) or set(document) != required or document["schema"] != "vic.observations/1":
        raise ValueError("Unsupported contribution schema or unexpected/private fields")
    if document["client"] != "forever" or document["licence"] != "CC BY-SA 4.0":
        raise ValueError("Contribution must be Forever data explicitly shared under CC BY-SA 4.0")
    if not isinstance(document["reporterId"], str) or not re.fullmatch(r"vic-[0-9a-f]{32}", document["reporterId"]):
        raise ValueError("Invalid installation pseudonym")
    if not integer(document["exportedAt"], 1) or not isinstance(document["records"], list) or len(document["records"]) > 50000:
        raise ValueError("Invalid export date or record count")
    for row in document["records"]:
        required_row = {"vendorId", "itemId", "observedAt", "build", "interface", "channel", "priceCopper", "quantity", "costs", "costsComplete"}
        if not isinstance(row, dict) or not required_row <= row.keys() or not row.keys() <= RECORD_FIELDS:
            raise ValueError("Missing observation fields or unexpected/private fields")
        for key in ("vendorId", "itemId", "observedAt", "quantity"):
            if not integer(row[key], 1): raise ValueError("Invalid " + key)
        if not integer(row["priceCopper"]): raise ValueError("Invalid price")
        if not integer(row["interface"]) or not 16000 <= row["interface"] < 17000 or not isinstance(row["build"], str) or not re.fullmatch(r"1\.60\.\d+\.\d+", row["build"]):
            raise ValueError("Observation is not from a supported Forever build")
        if row["observedAt"] > document["exportedAt"]:
            raise ValueError("Observation is newer than its export")
        if row["channel"] not in ("live", "unknown"):
            raise ValueError("Test/beta observations cannot be accepted as live data")
        if "vendorName" in row and not text(row["vendorName"]): raise ValueError("Invalid NPC name")
        if "playerFaction" in row and row["playerFaction"] not in ("Alliance", "Horde"):
            raise ValueError("Invalid observation faction")
        for key in ("canPurchase", "hasExtendedCost", "costsComplete"):
            if key in row and type(row[key]) is not bool: raise ValueError("Invalid " + key)
        if "stock" in row and not integer(row["stock"], -1): raise ValueError("Invalid stock")
        if "discount" in row and (type(row["discount"]) not in (int, float) or not 0 <= row["discount"] <= 1):
            raise ValueError("Invalid discount context")
        if not isinstance(row["costs"], list) or len(row["costs"]) > 20: raise ValueError("Invalid alternate costs")
        for cost in row["costs"]:
            if not isinstance(cost, dict) or not cost.keys() <= {"itemId", "currencyId", "quantity"} or not integer(cost.get("quantity"), 1):
                raise ValueError("Invalid alternate cost")
            ids = [key for key in ("itemId", "currencyId") if key in cost]
            if len(ids) != 1 or not integer(cost[ids[0]], 1): raise ValueError("Invalid alternate cost identifier")
        if "location" in row:
            location = row["location"]
            if not isinstance(location, dict) or not {"mapId", "x", "y", "approximate"} <= location.keys() or not location.keys() <= {"mapId", "x", "y", "approximate", "zone"}:
                raise ValueError("Invalid location fields")
            if not integer(location["mapId"], 1) or location["approximate"] is not True:
                raise ValueError("Personal positions must remain approximate")
            if any(type(location[key]) not in (int, float) or not 0 < location[key] <= 100 for key in ("x", "y")):
                raise ValueError("Invalid map coordinates")
            if "zone" in location and not text(location["zone"], 128): raise ValueError("Invalid zone")
    return document


def read_document(path):
    with Path(path).open("rb") as source:
        content = source.read(MAX_BYTES + 1)
    if len(content) > MAX_BYTES: raise ValueError("Contribution exceeds 10 MiB")
    return validate_document(json.loads(content))


def load_index(root):
    index = json.loads((root / "index.json").read_text())
    if not isinstance(index, dict) or set(index) != {"schema", "asOf", "files"} or index["schema"] != 1 or not isinstance(index["files"], list):
        raise ValueError("Invalid contribution review index")
    return index


def reviewed_documents(root):
    index = load_index(root)
    identities, seen_files, documents = {}, set(), []
    for entry in index["files"]:
        if not isinstance(entry, dict) or set(entry) != {"file", "sha256", "identity", "reference", "reviewedLive"}:
            raise ValueError("Invalid contribution review entry")
        if not text(entry["reference"], 500) or not isinstance(entry["identity"], str) or not re.fullmatch(r"contributor-[a-z0-9-]+", entry["identity"]) or entry["reviewedLive"] is not True:
            raise ValueError("Independent contributor and live-server review are required")
        relative = Path(entry["file"])
        if relative.is_absolute() or ".." in relative.parts or relative.suffix != ".json":
            raise ValueError("Unsafe contribution path")
        path = (root / relative).resolve()
        if not path.is_relative_to(root.resolve()) or path in seen_files:
            raise ValueError("Duplicate or unsafe contribution path")
        seen_files.add(path)
        with path.open("rb") as source:
            content = source.read(MAX_BYTES + 1)
        if len(content) > MAX_BYTES or hashlib.sha256(content).hexdigest() != entry["sha256"]:
            raise ValueError("Contribution checksum mismatch or oversized file")
        document = validate_document(json.loads(content))
        reporter = document["reporterId"]
        if reporter in identities and identities[reporter] != entry["identity"]:
            raise ValueError("One installation cannot count as multiple independent contributors")
        identities[reporter] = entry["identity"]
        documents.append((entry["identity"], document))
    return index, documents


def accept_file(source, root, identity, reference, confirm_live):
    if not confirm_live: raise ValueError("Explicit live-server and independence review is required")
    document = read_document(source)
    now = datetime.now(timezone.utc)
    if document["exportedAt"] > now.timestamp(): raise ValueError("Export is in the future")
    if not re.fullmatch(r"contributor-[a-z0-9-]+", identity) or not text(reference, 500):
        raise ValueError("Use an opaque contributor-... identity and a review reference")
    index, previous = reviewed_documents(root)
    for old_identity, old_document in previous:
        if old_document["reporterId"] == document["reporterId"] and old_identity != identity:
            raise ValueError("Installation already belongs to another reviewed contributor")
    content = canonical(document)
    checksum = hashlib.sha256(content).hexdigest()
    filename = checksum + ".json"
    if any(entry["sha256"] == checksum for entry in index["files"]):
        return False
    index["files"].append({"file": filename, "sha256": checksum, "identity": identity,
                           "reference": reference, "reviewedLive": True})
    index["files"].sort(key=lambda entry: entry["file"])
    index["asOf"] = now.isoformat()
    # Validate everything before writing. There is no network access or Lua evaluation.
    destination = root / filename
    if destination.is_symlink() or (destination.exists() and destination.read_bytes() != content):
        raise ValueError("Existing contribution path does not match the reviewed document")
    if not destination.exists():
        with destination.open("xb") as output:
            output.write(content)
    (root / "index.json").write_bytes(canonical(index))
    return True


def compile_reviewed(root, fallback_as_of):
    from build_data import MAX_AGE_DAYS, MIN_REPORTERS, LAUNCH, timestamp, consensus, confirmation_expiry
    index, documents = reviewed_documents(root)
    as_of = max(timestamp(fallback_as_of), timestamp(index["asOf"])) if index["files"] else timestamp(fallback_as_of)
    cutoff = max(LAUNCH.timestamp(), as_of.timestamp() - MAX_AGE_DAYS * 86400)
    latest = {}
    for identity, document in documents:
        if document["exportedAt"] > as_of.timestamp(): raise ValueError("Export is newer than its review snapshot")
        for row in document["records"]:
            if not cutoff <= row["observedAt"] <= as_of.timestamp(): continue
            key = identity, row["vendorId"], row["itemId"]
            old = latest.get(key)
            if old is None or row["observedAt"] > old["observedAt"]:
                latest[key] = row
            elif old["observedAt"] == row["observedAt"] and old != row:
                latest[key] = {"observedAt": row["observedAt"], "conflict": True}
    offers, traits = defaultdict(list), {}
    for (identity, vendor, item), row in latest.items():
        if row.get("conflict"): continue
        offers[vendor, item].append((identity, row))
        old = traits.get((identity, vendor))
        if old is None or row["observedAt"] > old["observedAt"]:
            traits[identity, vendor] = row
        elif row["observedAt"] == old["observedAt"]:
            # Only name/location affect trait agreement; item and quote differences do not.
            for field in ("vendorName", "location"):
                if old.get(field) != row.get(field):
                    old = dict(old)
                    old.pop(field, None)
                    traits[identity, vendor] = old
    vendors, items = {}, {}
    def iso(epoch): return datetime.fromtimestamp(epoch, timezone.utc).isoformat()
    for (vendor, item), evidence in sorted(offers.items()):
        if len(evidence) < MIN_REPORTERS: continue
        name_evidence, location_evidence = [], []
        dates = {}
        for (identity, npc), row in traits.items():
            if npc != vendor: continue
            dates[identity] = iso(row["observedAt"])
            if row.get("vendorName"): name_evidence.append((identity, row["vendorName"]))
            if row.get("location"):
                loc = row["location"]
                location_evidence.append((identity, (loc["mapId"], round(loc["x"]), round(loc["y"]))))
        name, _ = consensus(name_evidence)
        location, _ = consensus(location_evidence)
        entry = {"name": name or ("Vendor " + str(vendor)), "faction": "?"}
        if name:
            entry["nameExpires"] = confirmation_expiry([dates[r] for r, value in name_evidence if value == name])
        if location:
            entry.update(mapID=location[0], x=location[1], y=location[2], approximate=True,
                         locationExpires=confirmation_expiry([dates[r] for r, value in location_evidence if value == location]))
        vendors[vendor] = entry
        offer = {"reporters": len(evidence), "lastSeenEpoch": max(row["observedAt"] for _, row in evidence),
                 "expires": confirmation_expiry([iso(row["observedAt"]) for _, row in evidence]),
                 "priceContext": "Reported quotes; applicability to this character unknown"}
        offer["lastSeen"] = iso(offer["lastSeenEpoch"])
        quote_groups = defaultdict(list)
        for identity, row in evidence:
            quote = {key: row[key] for key in ("priceCopper", "quantity", "hasExtendedCost", "costs", "costsComplete", "discount", "playerFaction", "canPurchase") if key in row}
            quote_groups[canonical(quote).decode()].append(row)
        quote_evidence = []
        for quoted, rows in sorted(quote_groups.items()):
            if len(rows) >= MIN_REPORTERS:
                quote = json.loads(quoted)
                quote.update(reporters=len(rows), expires=confirmation_expiry([iso(row["observedAt"]) for row in rows]))
                quote_evidence.append(quote)
        if quote_evidence: offer["quoteEvidence"] = quote_evidence
        items.setdefault(item, {"v": [], "offers": {}})["v"].append(vendor)
        items[item]["offers"][vendor] = offer
    return {"metadata": {"dataAsOf": as_of.isoformat()}, "vendors": vendors, "items": items}, hashlib.sha256(canonical(index)).hexdigest(), bool(documents)


def merge_reviewed(dataset, root):
    community, checksum, present = compile_reviewed(root, dataset["metadata"]["dataAsOf"])
    if not present: return dataset
    for item, data in community["items"].items():
        existing = dataset["items"].setdefault(item, {"v": [], "offers": {}})
        for vendor, offer in data["offers"].items():
            old = existing["offers"].get(vendor)
            if old is None or offer["lastSeenEpoch"] > old.get("lastSeenEpoch", 0):
                existing["offers"][vendor] = offer
                if vendor not in existing["v"]: existing["v"].append(vendor)
        existing["v"].sort()
    for vendor, entry in community["vendors"].items():
        old = dataset["vendors"].setdefault(vendor, {"name": "Vendor " + str(vendor), "faction": "?"})
        if entry.get("nameExpires", 0) > old.get("nameExpires", 0):
            old.update(name=entry["name"], nameExpires=entry["nameExpires"])
        if entry.get("locationExpires", 0) > old.get("locationExpires", 0):
            for field in ("mapID", "x", "y", "approximate", "locationExpires"): old[field] = entry[field]
    dataset["metadata"].update(dataAsOf=community["metadata"]["dataAsOf"], reviewedSHA256=checksum,
        source="Everloot / VIC contributors", credit="Everloot (https://everloot.app) and VIC contributors; CC BY-SA 4.0.",
        build="Mixed observations; contribution builds recorded in source files")
    return dataset
