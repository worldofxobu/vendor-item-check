"""Contract and failure-mode tests for the public Forever feed importer."""

import copy
from datetime import datetime, timezone
import hashlib
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import build_data as builder


def records():
    result = []
    for n in range(3):
        reporter = "pub-" + str(n) * 32
        result.extend([
            {"kind": "vendor", "installId": reporter, "capturedAt": "2026-11-05T01:00:00Z",
             "vendorNpcId": 100001, "items": [{"itemId": 100002, "priceCopper": 100}]},
            {"kind": "npc_sighting", "installId": reporter, "capturedAt": "2026-11-05T01:00:00Z",
             "npcId": 100001, "name": "Test Vendor", "mapId": 1429, "x": 41.1, "y": 65.1,
             "positionKind": "interaction"},
        ])
    return result


def page(rows=None):
    rows = records() if rows is None else rows
    return {"ok": True, "uploads": 3, "records": rows, "dataAsOf": "2026-11-05T03:10:11.401Z",
            "offset": 0, "limit": 500, "total": len(rows), "next": None,
            "attribution": {"licence": "CC BY-SA 4.0", "credit": builder.CREDIT}}


def snapshot(rows=None):
    return {"schema": 1, "source": builder.SOURCE,
            "pages": [{"url": builder.SOURCE, "response": page(rows)}]}


class BuildDataTests(unittest.TestCase):
    def test_independent_confirmation_and_price_ambiguity(self):
        data = builder.compile_snapshot(snapshot())
        self.assertEqual(len(data["items"]), 1)
        self.assertEqual(data["vendors"][100001]["faction"], "?")
        offer = data["items"][100002]["offers"][100001]
        self.assertEqual(offer["observedCopper"], 100)
        self.assertEqual(offer["priceContext"], "unknown")
        self.assertNotIn("p", data["items"][100002])
        self.assertNotIn("unitPrice", offer)

    def test_repeats_do_not_confirm(self):
        rows = records()[:2] * 10
        self.assertFalse(builder.compile_snapshot(snapshot(rows))["items"])

    def test_missing_pseudonyms_beta_and_other_clients(self):
        for field, value in [("installId", ""), ("capturedAt", "2026-10-20T01:00:00Z"),
                             ("build", "1.15.9.70003"), ("channel", "beta")]:
            rows = records()
            for record in rows:
                record[field] = value
            self.assertFalse(builder.compile_snapshot(snapshot(rows))["items"])

    def test_unverified_fields_never_use_classic(self):
        rows = [r for r in records() if r["kind"] == "vendor"]
        vendor = builder.compile_snapshot(snapshot(rows))["vendors"][100001]
        self.assertEqual(vendor, {"name": "Vendor 100001", "faction": "?"})

    def test_player_positions_do_not_become_vendor_pins(self):
        rows = records()
        for record in rows:
            record["positionKind"] = "player"
        vendor = builder.compile_snapshot(snapshot(rows))["vendors"][100001]
        self.assertNotIn("x", vendor)
        self.assertNotIn("mapID", vendor)

    def test_conflicting_prices_omit_price_but_keep_inventory(self):
        rows = records()
        rows[0]["items"][0]["priceCopper"] = 99
        offer = builder.compile_snapshot(snapshot(rows))["items"][100002]["offers"][100001]
        self.assertNotIn("observedCopper", offer)

    def test_latest_merchant_snapshot_can_remove_item(self):
        rows = records()
        newer = copy.deepcopy(rows[0])
        newer["capturedAt"] = "2026-11-05T02:00:00Z"
        newer["items"] = [{"itemId": 999, "priceCopper": 1}]
        rows.append(newer)
        self.assertFalse(builder.compile_snapshot(snapshot(rows))["items"])

    def test_old_observations_expire(self):
        saved = snapshot()
        saved["pages"][0]["response"]["dataAsOf"] = "2026-12-10T00:00:00Z"
        self.assertFalse(builder.compile_snapshot(saved)["items"])

    def test_confirmation_expires_when_third_reporter_ages_out(self):
        rows = records()
        rows[0]["capturedAt"] = "2026-11-04T23:30:00Z"
        rows[2]["capturedAt"] = "2026-11-05T01:30:00Z"
        rows[4]["capturedAt"] = "2026-11-05T02:30:00Z"
        offer = builder.compile_snapshot(snapshot(rows))["items"][100002]["offers"][100001]
        self.assertEqual(offer["expires"], int(builder.timestamp("2026-12-04T23:30:00Z").timestamp()))

    def test_empty_is_valid_unknown(self):
        self.assertFalse(builder.compile_snapshot(snapshot([]))["items"])

    def test_pagination_and_snapshot_consistency(self):
        first, second = page(records()[:3]), page(records()[3:])
        next_url = builder.SOURCE + "&offset=3"
        first.update(total=6, next=next_url)
        second.update(offset=3, total=6)
        saved = builder.download_snapshot(lambda url: first if url == builder.SOURCE else second)
        self.assertEqual(len(builder.compile_snapshot(saved)["items"]), 1)
        second["dataAsOf"] = "2026-11-05T03:15:00Z"
        with self.assertRaises(ValueError):
            builder.download_snapshot(lambda url: first if url == builder.SOURCE else second)

    def test_reject_unavailable_partial_and_unsafe_pages(self):
        for mutate in [lambda p: p.update(unreachable=True), lambda p: p.update(ok=False),
                       lambda p: p.update(total=100), lambda p: p.update(next="https://example.com/"),
                       lambda p: p.update(dataAsOf=None), lambda p: p.update(attribution={})]:
            response = page()
            mutate(response)
            with self.assertRaises(ValueError):
                builder.download_snapshot(lambda url: response)

    def test_deterministic_lua_and_string_escaping(self):
        data = builder.compile_snapshot(snapshot())
        data["vendors"][100001]["name"] = 'Éowyn "test"\\\n'
        text = builder.render(data, "test-checksum")
        self.assertEqual(text, builder.render(data, "test-checksum"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Data.lua"
            path.write_text(text)
            if shutil.which("luac"):
                subprocess.run(["luac", "-p", str(path)], check=True)

    def test_failed_refresh_preserves_both_outputs(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output = Path(directory) / "source.json", Path(directory) / "Data.lua"
            source.write_bytes(builder.encode(snapshot()))
            output.write_text("last known good")
            original = source.read_bytes()
            argv = ["build_data", "--refresh", "--snapshot", str(source), "--output", str(output)]
            with patch.object(sys, "argv", argv), patch.object(builder, "download_snapshot", side_effect=ValueError("unavailable")):
                with self.assertRaises(ValueError):
                    builder.main()
            self.assertEqual(output.read_text(), "last known good")
            self.assertEqual(source.read_bytes(), original)

    def test_empty_refresh_cannot_erase_populated_data(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output = Path(directory) / "source.json", Path(directory) / "Data.lua"
            source.write_bytes(builder.encode(snapshot()))
            output.write_text(builder.render(builder.compile_snapshot(snapshot()), "original"))
            original_output, original_source = output.read_bytes(), source.read_bytes()
            argv = ["build_data", "--refresh", "--snapshot", str(source), "--output", str(output)]
            fresh_empty = snapshot([])
            fresh_empty["pages"][0]["response"]["dataAsOf"] = datetime.now(timezone.utc).isoformat()
            with patch.object(sys, "argv", argv), patch.object(builder, "download_snapshot", return_value=fresh_empty):
                with self.assertRaisesRegex(ValueError, "empty a populated"):
                    builder.main()
            self.assertEqual(output.read_bytes(), original_output)
            self.assertEqual(source.read_bytes(), original_source)

    def test_unchanged_refresh_does_not_create_metadata_only_changes(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output = Path(directory) / "source.json", Path(directory) / "Data.lua"
            saved = snapshot([])
            source.write_bytes(builder.encode(saved))
            output.write_text(builder.render(builder.compile_snapshot(saved), hashlib.sha256(builder.encode(saved)).hexdigest()))
            original_output, original_source = output.read_bytes(), source.read_bytes()
            fresh_empty = snapshot([])
            fresh_empty["pages"][0]["response"]["dataAsOf"] = datetime.now(timezone.utc).isoformat()
            argv = ["build_data", "--refresh", "--snapshot", str(source), "--output", str(output)]
            with patch.object(sys, "argv", argv), patch.object(builder, "download_snapshot", return_value=fresh_empty):
                builder.main()
            self.assertEqual(output.read_bytes(), original_output)
            self.assertEqual(source.read_bytes(), original_source)
            output.write_text("corrupted generated file")
            with patch.object(sys, "argv", argv), patch.object(builder, "download_snapshot", return_value=fresh_empty):
                with self.assertRaisesRegex(ValueError, "Existing output differs"):
                    builder.main()
            self.assertEqual(source.read_bytes(), original_source)

    def test_checked_in_data_reproduces_offline(self):
        subprocess.run([sys.executable, str(ROOT / "scripts/build_data.py"), "--check"], check=True)


if __name__ == "__main__":
    unittest.main()
