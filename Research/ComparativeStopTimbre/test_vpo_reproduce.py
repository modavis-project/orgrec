#!/usr/bin/env python3

import hashlib
import importlib.util
import json
import csv
import tempfile
import threading
import unittest
import zipfile
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


SCRIPT = Path(__file__).with_name("vpo_reproduce.py")
SPEC = importlib.util.spec_from_file_location("vpo_reproduce", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC and SPEC.loader
SPEC.loader.exec_module(MODULE)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


class QuietHandler(SimpleHTTPRequestHandler):
    def log_message(self, format, *args):
        pass


class VPOReproduceTests(unittest.TestCase):
    def test_inventory_remap_updates_paths_and_reports_missing(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            mounted = root / "mounted"
            present = mounted / "VPO-1"
            present.mkdir(parents=True)
            source = root / "inventory.csv"
            with source.open("w", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(handle, fieldnames=["entity_id", "path", "path_exists", "manifest_path"])
                writer.writeheader()
                writer.writerow({"entity_id": "VPO-1", "path": "/old/VPO-1", "path_exists": "no", "manifest_path": "/old/log.csv"})
                writer.writerow({"entity_id": "VPO-2", "path": "/old/VPO-2", "path_exists": "yes", "manifest_path": ""})
            output = root / "remapped.csv"
            report = MODULE.remap_inventory(source, output, [("/old", str(mounted))])
            self.assertEqual(report["summary"]["remappedRowCount"], 2)
            self.assertEqual(report["summary"]["historicallyExpectedPresentMissingPathCount"], 1)
            with output.open(encoding="utf-8", newline="") as handle:
                rows = list(csv.DictReader(handle))
            self.assertEqual(rows[0]["path_exists"], "yes")
            self.assertEqual(rows[1]["path_exists"], "no")
            self.assertTrue(rows[0]["manifest_path"].endswith("/mounted/log.csv"))

    def test_corpus_comparison_ignores_only_run_and_path_provenance(self):
        base = {
            "contractVersion": "orgrec-retrieved-timbre-corpus/1",
            "generatedAt": "old",
            "software": {"build": "1"},
            "inventoryPath": "/old/inventory.csv",
            "inventorySHA256": "old",
            "catalogPath": "/old/catalog.csv",
            "catalogSHA256": "catalog",
            "sourceMutationPolicy": "read only",
            "options": {"maximumPipesPerRank": 9},
            "instruments": [{"entityID": "VPO-1", "sourceDefinitionPath": "/old/a.organ", "sourceDefinitionSHA256": "abc"}],
            "ranks": [{"rankID": "r1", "observations": [{"id": "random-a", "sourceAudioSHA256": "audio"}]}],
            "exclusions": [],
            "warnings": [],
        }
        candidate = json.loads(json.dumps(base))
        candidate.update({"generatedAt": "new", "software": {"build": "2"}, "inventoryPath": "/new/inventory.csv", "inventorySHA256": "new", "catalogPath": "/new/catalog.csv"})
        candidate["instruments"][0]["sourceDefinitionPath"] = "/new/a.organ"
        candidate["ranks"][0]["observations"][0]["id"] = "random-b"
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            reference_path = root / "reference.json"
            candidate_path = root / "candidate.json"
            reference_path.write_text(json.dumps(base), encoding="utf-8")
            candidate_path.write_text(json.dumps(candidate), encoding="utf-8")
            self.assertTrue(MODULE.compare_corpora(reference_path, candidate_path)["equivalent"])
            candidate["ranks"][0]["rankID"] = "changed"
            candidate_path.write_text(json.dumps(candidate), encoding="utf-8")
            self.assertFalse(MODULE.compare_corpora(reference_path, candidate_path)["equivalent"])

    def test_result_comparison_is_canonical_but_exact(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            reference = root / "reference"
            candidate = root / "candidate"
            reference.mkdir()
            candidate.mkdir()
            for directory in (reference, candidate):
                (directory / "summary.json").write_text('{"value": 1}\n', encoding="utf-8")
                for filename in MODULE.RESULT_CSV_FILES:
                    (directory / filename).write_text("a,b\n1,2\n", encoding="utf-8")
            self.assertTrue(MODULE.compare_results(reference, candidate)["equivalent"])
            (candidate / "association-tests.csv").write_text("a,b\n1,3\n", encoding="utf-8")
            self.assertFalse(MODULE.compare_results(reference, candidate)["equivalent"])

    def test_historical_backup_entity_roots_are_scoped(self):
        roots = MODULE.historical_backup_entity_roots(Path("/backup/mac"), Path("/backup/xfer"))
        self.assertEqual(set(roots), {"VPO-083", "VPO-085", "VPO-086", "VPO-087", "VPO-088", "VPO-089", "VPO-090", "VPO-091", "VPO-092", "VPO-187"})
        self.assertEqual(roots["VPO-085"], roots["VPO-092"])
        self.assertTrue(str(roots["VPO-187"]).endswith("VPO-187 Veendam Kaat Tijhuis/extracted"))

    def test_verify_distinguishes_equivalent_from_variant(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            entity = root / "VPO-TEST" / "extracted" / "package"
            entity.mkdir(parents=True)
            audio = b"RIFF-test-audio"
            definition = b"[Organ]\nName=Test\n"
            (entity / "pipe.wav").write_bytes(audio)
            (entity / "test.organ").write_bytes(definition)
            lock = {
                "contractVersion": MODULE.LOCK_CONTRACT,
                "entities": [
                    {
                        "entityID": "VPO-TEST",
                        "requiredAudioSHA256": [digest(audio)],
                        "definitionSHA256": digest(definition),
                    }
                ],
            }
            exact = MODULE.verify_acquisition(lock, root)
            self.assertTrue(exact["equivalent"])
            self.assertEqual(exact["status"], "analysis-input equivalent")
            (entity / "pipe.wav").write_bytes(b"changed")
            variant = MODULE.verify_acquisition(lock, root)
            self.assertFalse(variant["equivalent"])
            self.assertEqual(variant["status"], "dataset variant")

    def test_download_extract_and_verify_local_zip(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            served = root / "served"
            destination = root / "destination"
            served.mkdir()
            audio = b"RIFF-local-fixture"
            definition = b"[Organ]\nName=Fixture\n"
            archive = served / "fixture.orgue"
            with zipfile.ZipFile(archive, "w") as handle:
                handle.writestr("Fixture/pipe.wav", audio)
                handle.writestr("Fixture/fixture.organ", definition)

            handler = lambda *args, **kwargs: QuietHandler(*args, directory=served, **kwargs)
            server = ThreadingHTTPServer(("127.0.0.1", 0), handler)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                lock = {
                    "contractVersion": MODULE.LOCK_CONTRACT,
                    "entities": [
                        {
                            "entityID": "VPO-TEST",
                            "downloads": [
                                {
                                    "url": f"http://127.0.0.1:{server.server_port}/fixture.orgue",
                                    "filename": "fixture.orgue",
                                    "expectedBytes": archive.stat().st_size,
                                    "expectedSHA256": MODULE.sha256_file(archive),
                                    "archiveFormat": "zip",
                                }
                            ],
                            "requiredAudioSHA256": [digest(audio)],
                            "definitionSHA256": digest(definition),
                        }
                    ],
                }
                MODULE.download_entities(lock, destination, None, True, 5)
                report = MODULE.verify_acquisition(lock, destination)
                self.assertTrue(report["equivalent"])
                self.assertTrue((destination / "VPO-TEST/downloads/fixture.orgue").exists())
            finally:
                server.shutdown()
                thread.join()
                server.server_close()

    def test_archive_path_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = root / "bad.orgue"
            with zipfile.ZipFile(archive, "w") as handle:
                handle.writestr("../escape.txt", "bad")
            with self.assertRaises(MODULE.ReproductionError):
                MODULE.extract_archive(archive, "zip", root / "out")

    def test_verify_reads_unextracted_orgue_and_shared_override(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            shared = root / "historical-shared-folder"
            shared.mkdir()
            audio_a = b"RIFF-a"
            audio_b = b"RIFF-b"
            definition_a = b"[Organ]\nName=A\n"
            definition_b = b"[Organ]\nName=B\n"
            with zipfile.ZipFile(shared / "a.orgue", "w") as handle:
                handle.writestr("A/a.wav", audio_a)
                handle.writestr("A/a.organ", definition_a)
            with zipfile.ZipFile(shared / "b.orgue", "w") as handle:
                handle.writestr("B/b.wav", audio_b)
                handle.writestr("B/b.organ", definition_b)
            lock = {
                "contractVersion": MODULE.LOCK_CONTRACT,
                "entities": [
                    {"entityID": "VPO-A", "requiredAudioSHA256": [digest(audio_a)], "definitionSHA256": digest(definition_a)},
                    {"entityID": "VPO-B", "requiredAudioSHA256": [digest(audio_b)], "definitionSHA256": digest(definition_b)},
                ],
            }
            report = MODULE.verify_acquisition(
                lock,
                root / "unused-default",
                {"VPO-A": shared, "VPO-B": shared},
            )
            self.assertTrue(report["equivalent"])


if __name__ == "__main__":
    unittest.main()
