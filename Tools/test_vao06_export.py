#!/usr/bin/env python3
"""Exercise actual OrgRec and VAO export commands with synthetic project data."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from tempfile import TemporaryDirectory
import wave
from zipfile import ZipFile


EXPORT = Path(__file__).with_name("export_vao06.py")


def create_project(directory: Path) -> dict[str, bytes]:
    directory.mkdir()
    identity = "00000000-0000-4000-8000-000000000001"
    date = "2026-01-01T00:00:00Z"
    project = {
        "schemaVersion": 1,
        "id": identity,
        "title": "Synthetic project",
        "organMDVSID": "",
        "organName": "Synthetic organ",
        "venueName": "Test venue",
        "createdAt": date,
        "updatedAt": date,
        "snapshot": {
            "id": identity,
            "retrievedAt": date,
            "endpoint": "manual://test",
            "payloadSHA256": hashlib.sha256(b"synthetic snapshot").hexdigest(),
            "release": {
                "requestedRelease": "fixture",
                "releaseState": "synthetic",
                "canonicalSourceRelease": "fixture",
                "protectedFingerprintSHA256": hashlib.sha256(b"fixture").hexdigest(),
                "navigatorContractVersion": "fixture/v1",
            },
        },
        "recipe": {
            "id": identity,
            "name": "Fixture",
            "version": 1,
            "techniques": [],
            "preRollSeconds": 1,
            "sustainSeconds": 4,
            "releaseSeconds": 4,
            "chromaticStep": 1,
        },
        **{key: [] for key in ("devices", "setups", "registrations", "roadmap", "takes",
                               "annotations", "syncReceipts")},
    }
    (directory / "project.json").write_text(json.dumps(project), encoding="utf-8")
    with wave.open(str(directory / "silence.wav"), "wb") as recording:
        recording.setparams((1, 2, 44100, 64, "NONE", "not compressed"))
        recording.writeframes(bytes(128))
    return {file.name: file.read_bytes() for file in directory.iterdir()}


def read_carrier(path: Path) -> tuple[bytes, dict[str, bytes]]:
    with ZipFile(path) as archive:
        payload = {name: archive.read(name) for name in archive.namelist() if name.startswith("payload/")}
        return archive.read("vao-manifest.json"), payload


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--orgrec-tool", required=True, type=Path)
    parser.add_argument("--reference-wheel", required=True, type=Path)
    args = parser.parse_args()
    tool = args.orgrec_tool.resolve(strict=True)
    wheel = args.reference_wheel.resolve(strict=True)

    def call(operation: str, source: Path, target: Path, reference: Path = wheel, *, succeeds: bool = True) -> None:
        result = subprocess.run(
            [sys.executable, EXPORT, operation, source, target,
             "--orgrec-tool", tool, "--reference-wheel", reference],
            capture_output=True, text=True,
        )
        assert (result.returncode == 0) == succeeds, result.stdout + result.stderr

    with TemporaryDirectory(prefix="orgrec-vao06-test-") as temporary:
        root = Path(temporary)
        project = root / "Test Organ.orgrec"
        source_payload = create_project(project)
        original = root / "legacy.vao"
        subprocess.run([tool, "vao-export", project, original], check=True)
        subprocess.run([tool, "vao-validate", original], check=True)
        original_manifest, original_payload = read_carrier(original)
        before = json.loads(original_manifest)
        assert before["formatVersion"] == "0.5.0"

        for operation, source in (("export", project), ("migrate", original)):
            target = root / operation
            carrier = target / (source.stem + ".vao")
            call(operation, source, target)
            migrated_manifest, migrated_payload = read_carrier(carrier)
            after = json.loads(migrated_manifest)
            receipt = json.loads((target / "migration-receipt.json").read_text(encoding="utf-8"))
            assert migrated_payload == original_payload == {
                "payload/orgrec/" + name: content for name, content in source_payload.items()
            }
            assert after["formatVersion"] == receipt["outputFormatVersion"] == "0.6.0"
            assert after["modavisBinding"]["mappingVersion"] == "0.6.0"
            assert after["release"]["id"] != before["release"]["id"]
            assert receipt["outputSHA256"] == hashlib.sha256(migrated_manifest).hexdigest()
            assert receipt["validation"]["valid"]
            assert sorted(receipt["unchangedRealizationIds"]) == sorted(
                record["id"] for record in after["realizations"]
            ) == sorted(record["id"] for record in before["realizations"])
            assert receipt["prototypeMMICPromoted"] is False
            if operation == "migrate":
                assert receipt["sourceSHA256"] == hashlib.sha256(original_manifest).hexdigest()
            call(operation, source, target, succeeds=False)
            assert read_carrier(carrier) == (migrated_manifest, migrated_payload)

        invalid_wheel = root / "invalid.whl"
        wheel_bytes = wheel.read_bytes()
        invalid_wheel.write_bytes(wheel_bytes[:-1] + bytes([wheel_bytes[-1] ^ 1]))
        bad_export = root / "bad-wheel"
        call("export", project, bad_export, invalid_wheel, succeeds=False)
        assert not bad_export.exists()

        corrupt = root / "invalid.vao"
        with ZipFile(original) as source_archive, ZipFile(corrupt, "x") as corrupt_archive:
            for entry in source_archive.infolist():
                data = source_archive.read(entry)
                if entry.filename == "payload/orgrec/silence.wav":
                    data = bytes([data[0] ^ 1]) + data[1:]
                corrupt_archive.writestr(entry, data)
        corrupt_export = root / "corrupt"
        call("migrate", corrupt, corrupt_export, succeeds=False)
        assert not corrupt_export.exists()
        assert read_carrier(original) == (original_manifest, original_payload)
        assert {file.name: file.read_bytes() for file in project.iterdir()} == source_payload
        assert not list(root.glob(".orgrec-vao06-*"))

    print("VAO 0.6.0 project export, carrier migration, byte preservation and refusal checks passed.")


if __name__ == "__main__":
    main()
