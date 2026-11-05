import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import update_data_docs as docs
from build_data import ROOT, SNAPSHOT, compile_snapshot


class DataDocumentationTests(unittest.TestCase):
    def test_coverage_updates_preserve_published_history(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "README.md").write_text(docs.START + "\nold coverage\n" + docs.END)
            published = "\n## [0.1.0]\n\nPublished text must stay unchanged.\n"
            (root / "CHANGELOG.md").write_text("# Changelog\n\n## [Unreleased]\n\n### Added\n\n- Existing feature.\n" + published)
            dataset = {"items": {1: {}}, "vendors": {2: {}}, "metadata": {"dataAsOf": "2026-11-05T00:00:00Z"}}
            docs.update(root, dataset)
            self.assertIn("1 confirmed item and 1 vendor", (root / "README.md").read_text())
            self.assertTrue((root / "CHANGELOG.md").read_text().endswith(published))
            docs.update(root, dataset, check=True)
            dataset["items"] = {}
            with self.assertRaises(ValueError):
                docs.update(root, dataset, check=True)
            docs.update(root, dataset)
            self.assertEqual((root / "CHANGELOG.md").read_text().count(docs.ENTRY), 1)

    def test_checked_in_coverage_is_current(self):
        docs.update(ROOT, compile_snapshot(json.loads(SNAPSHOT.read_text())), check=True)


if __name__ == "__main__":
    unittest.main()
