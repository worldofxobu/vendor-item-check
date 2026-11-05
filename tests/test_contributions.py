import copy
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import build_data as builder
import contributions as contributions


@unittest.skipUnless(shutil.which("lua"), "Lua interpreter required for scanner/export integration")
class ContributionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        result = subprocess.run(["lua", "tests/contribution_fixture.lua"], cwd=ROOT, text=True, capture_output=True, check=True)
        cls.document = json.loads(result.stdout)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "index.json").write_bytes(contributions.canonical({"schema": 1, "asOf": None, "files": []}))

    def add(self, document, identity, live=True):
        content = contributions.canonical(document)
        checksum = hashlib.sha256(content).hexdigest()
        (self.root / (checksum + ".json")).write_bytes(content)
        index = json.loads((self.root / "index.json").read_text())
        index["asOf"] = "2026-11-05T03:10:11.401Z"
        index["files"].append({"file": checksum + ".json", "sha256": checksum, "identity": identity,
                               "reference": "Synthetic independent-contributor review", "reviewedLive": live})
        (self.root / "index.json").write_bytes(contributions.canonical(index))

    def three(self, same_identity=False):
        for number in range(3):
            document = copy.deepcopy(self.document)
            document["reporterId"] = "vic-" + str(number) * 32
            self.add(document, "contributor-" + ("same" if same_identity else str(number)))

    def compile(self):
        source = {"schema": 1, "source": builder.SOURCE, "pages": [{"url": builder.SOURCE, "response": {
            "ok": True, "records": [], "offset": 0, "total": 0, "next": None,
            "dataAsOf": "2026-11-05T03:10:11.401Z",
            "attribution": {"licence": "CC BY-SA 4.0", "credit": builder.CREDIT},
        }}]}
        return builder.compile_sources(source, self.root)

    def test_real_export_is_valid_and_private(self):
        contributions.validate_document(self.document)
        encoded = json.dumps(self.document)
        self.assertNotIn("PRIVATE", encoded)
        self.assertNotIn("Player-", encoded)
        row = self.document["records"][0]
        self.assertEqual((row["priceCopper"], row["quantity"]), (20, 5))
        self.assertEqual(row["vendorName"], 'Éowyn "Vendor"')
        self.assertTrue(row["location"]["approximate"])

    def test_three_reviewed_people_qualify_with_context_preserved(self):
        self.three()
        result = self.compile()
        offer = result["items"][100002]["offers"][100001]
        self.assertEqual(offer["reporters"], 3)
        self.assertEqual(offer["quoteEvidence"][0]["quantity"], 5)
        self.assertEqual(offer["quoteEvidence"][0]["discount"], 0.95)
        self.assertNotIn("p", result["items"][100002])
        self.assertEqual(result["vendors"][100001]["faction"], "?")

    def test_multiple_installs_of_one_person_do_not_confirm(self):
        self.three(same_identity=True)
        self.assertFalse(self.compile()["items"])

    def test_repeat_exports_do_not_inflate_reports(self):
        self.add(self.document, "contributor-one")
        document = copy.deepcopy(self.document)
        document["exportedAt"] += 1
        self.add(document, "contributor-one")
        self.assertFalse(self.compile()["items"])

    def test_installation_cannot_be_assigned_to_multiple_people(self):
        self.add(self.document, "contributor-one")
        document = copy.deepcopy(self.document)
        document["exportedAt"] += 1
        self.add(document, "contributor-two")
        with self.assertRaisesRegex(ValueError, "multiple independent"):
            self.compile()

    def test_unreviewed_or_modified_inputs_are_rejected(self):
        self.add(self.document, "contributor-one", live=False)
        with self.assertRaises(ValueError): self.compile()
        index = json.loads((self.root / "index.json").read_text())
        index["files"][0]["reviewedLive"] = True
        (self.root / "index.json").write_bytes(contributions.canonical(index))
        (self.root / index["files"][0]["file"]).write_text("{}")
        with self.assertRaisesRegex(ValueError, "checksum"): self.compile()

    def test_malformed_private_beta_and_future_records_are_rejected(self):
        for key, value in [("channel", "test"), ("build", "1.15.9.70003"), ("quantity", 0),
                           ("priceCopper", -1), ("characterName", "private"),
                           ("observedAt", self.document["exportedAt"] + 1), ("discount", float("nan"))]:
            document = copy.deepcopy(self.document)
            document["records"][0][key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                contributions.validate_document(document)
        document = copy.deepcopy(self.document)
        document["schema"] = "vic.observations/999"
        with self.assertRaises(ValueError): contributions.validate_document(document)

    def test_expired_contributions_do_not_remain_in_bundled_counts(self):
        self.three()
        index = json.loads((self.root / "index.json").read_text())
        index["asOf"] = "2026-12-10T00:00:00Z"
        (self.root / "index.json").write_bytes(contributions.canonical(index))
        self.assertFalse(self.compile()["items"])

    def test_import_command_requires_review_and_is_idempotent(self):
        document = copy.deepcopy(self.document)
        document["exportedAt"] = int(datetime.now(timezone.utc).timestamp())
        file = self.root / "incoming.json"
        file.write_bytes(contributions.canonical(document))
        with self.assertRaises(ValueError): contributions.accept_file(file, self.root, "contributor-one", "Review 1", False)
        self.assertTrue(contributions.accept_file(file, self.root, "contributor-one", "Review 1", True))
        self.assertFalse(contributions.accept_file(file, self.root, "contributor-one", "Review 1", True))

    def test_unsafe_paths_and_lua_inputs_are_rejected(self):
        self.add(self.document, "contributor-one")
        index = json.loads((self.root / "index.json").read_text())
        index["files"][0]["file"] = "../outside.json"
        (self.root / "index.json").write_bytes(contributions.canonical(index))
        with self.assertRaisesRegex(ValueError, "Unsafe"): self.compile()
        path = self.root / "not-json.lua"
        path.write_text("return { observations = {} }")
        with self.assertRaises(ValueError): contributions.read_document(path)

    def test_end_to_end_generated_database_renders_in_tooltip(self):
        self.three()
        dataset = self.compile()
        generated = self.root / "DataForever.lua"
        generated.write_text(builder.render(dataset, "synthetic-source-checksum"))
        script = '''
local VIC = dofile("tests/contribution_fixture.lua")
assert(loadfile(arg[1]))("VendorItemCheck", VIC)
VIC.personalIndex = nil
VIC:SelectDataset()
VIC.settings.modifierKey = "NONE"
VIC:TooltipInitialize()
local info = VIC:GetItemVendors(100002)
assert(info.totalCount == 1 and not info.vendors[1].personal)
assert(info.price == nil and info.observedPriceText == nil)
local tip = CreateFrame("GameTooltip", "ContributionTestTooltip")
tip:SetHyperlink("item:100002")
local found = false
for _, line in ipairs(tip.lines) do
    found = found or (line.left and line.left:find("Éowyn", 1, true))
end
assert(found, "Reviewed contributions must render as bundled vendors")
'''
        subprocess.run(["lua", "-", str(generated)], input=script, text=True, cwd=ROOT, check=True)


if __name__ == "__main__":
    unittest.main()
