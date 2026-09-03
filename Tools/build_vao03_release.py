#!/usr/bin/env python3
"""Build a deterministic VAO 0.3.3 editor-draft release bundle."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import stat
import subprocess
import sys
import zipfile

import vao03


ROOT = Path(__file__).resolve().parent.parent
PREFIX = "vao-specification-0.3.3"
FILES = [
    "Docs/VAO_CHANGELOG.md",
    "Docs/VAO_STANDARD_0.3.md",
    "Docs/VAO_CONFORMANCE_0.3.md",
    "Docs/VAO_ZENODO_PROFILE_0.3.md",
    "Docs/VAO_0.2_TO_0.3_MIGRATION.md",
    "Docs/VAO_0.3_IMPLEMENTATION_REPORT.md",
    "Docs/VAO_0.3.1_CHANGELOG.md",
    "Docs/VAO_0.3.2_CHANGELOG.md",
    "Docs/VAO_0.3.3_CHANGELOG.md",
    "Docs/VAO_ACOUSTIC_SCENES_0.3.md",
    "Docs/VAO_PLAYABLE_PROFILE_0.3.md",
    "Docs/ORGREC_VAO_0.3.3_COMPATIBILITY.md",
    "Docs/VAO_RELEASE_CHECKLIST_0.3.md",
    "Docs/VAO_GOVERNANCE.md",
    "Schemas/README.md",
    "Schemas/vao-manifest-0.3.schema.json",
    "Schemas/vao-carrier-0.3.schema.json",
    "Schemas/vao-release-0.3.schema.json",
    "Schemas/vao-pack-manifest-0.3.schema.json",
    "Schemas/vao-materialization-receipt-0.3.schema.json",
    "Schemas/vao-zenodo-metadata-0.3.schema.json",
    "Schemas/vao-context-0.3.jsonld",
    "Schemas/vao-vocabulary-0.3.ttl",
    "Schemas/vao-manifest.schema.json",
    "Tools/vaom.py",
    "Tools/vao03.py",
    "Tools/vao03_zenodo.py",
    "Tools/test_vao03_conformance.py",
    "Tools/build_vao03_release.py",
    "Sources/OrgRecCore/VAO03Models.swift",
    "Sources/OrgRecCore/VAO03Validation.swift",
    "Sources/OrgRecCore/VAO03AcousticsValidation.swift",
    "Sources/OrgRecCore/VAO03PlayableValidation.swift",
    "Sources/OrgRecCore/VAO03ComplexInteractionValidation.swift",
    "Sources/OrgRecCore/VAO03PackageAccess.swift",
    "Sources/OrgRecCore/VAO03Materialization.swift",
    "Tests/OrgRecCoreTests/VAO03Tests.swift",
    "Fixtures/VAO03/valid/embedded-private/mimetype",
    "Fixtures/VAO03/valid/embedded-private/vao-manifest.json",
    "Fixtures/VAO03/valid/embedded-private/META-INF/vao-carrier.json",
    "Fixtures/VAO03/valid/embedded-private/payload/evidence/source.txt",
    "Fixtures/VAO03/valid/zenodo-sandbox/mimetype",
    "Fixtures/VAO03/valid/zenodo-sandbox/vao-manifest.json",
    "Fixtures/VAO03/valid/zenodo-sandbox/META-INF/vao-carrier.json",
    "Fixtures/VAO03/valid/zenodo-sandbox/payload/evidence/source.txt",
    "Fixtures/VAO03/valid/acousticrooms-scene/mimetype",
    "Fixtures/VAO03/valid/acousticrooms-scene/vao-manifest.json",
    "Fixtures/VAO03/valid/acousticrooms-scene/META-INF/vao-carrier.json",
    "Fixtures/VAO03/valid/acousticrooms-scene/payload/acoustics/S000_R0011_hybrid_IR.wav",
    "Fixtures/VAO03/valid/acousticrooms-scene/payload/geometry/Bathrooms_idx_0.obj",
    "Fixtures/VAO03/valid/acousticrooms-scene/payload/geometry/Bathrooms_idx_0.glb",
    "Fixtures/VAO03/valid/acousticrooms-scene/payload/evidence/ACOUSTICROOMS_LICENSE.txt",
    "Fixtures/VAO03/valid/acousticrooms-scene/payload/evidence/ACOUSTICROOMS_README.md",
    "Fixtures/VAO03/valid/acousticrooms-scene/payload/evidence/S000_R0011.json",
    "Fixtures/VAO03/valid/acousticrooms-scene/payload/evidence/simulation.json",
    "Fixtures/VAO03/valid/acousticrooms-scene/payload/evidence/fixture-provenance.json",
    "Fixtures/VAO03/descriptors/pack-manifest.example.json",
    "Fixtures/VAO03/descriptors/materialization-receipt.example.json",
    "Fixtures/VAO03/descriptors/release-single-record.example.json",
    "Fixtures/VAO03/descriptors/zenodo-metadata-single-record.example.json",
    "Fixtures/VAO03/descriptors/release-record-family.example.json",
    "Fixtures/VAO03/descriptors/zenodo-metadata-family-root.example.json",
    "Fixtures/VAO03/descriptors/zenodo-metadata-family-model.example.json",
    "Fixtures/VAO03/descriptors/zenodo-metadata-family-audio.example.json",
    "Fixtures/VAO03/descriptors/kinoorgel-interaction.example.json",
    "Fixtures/VAO/valid/minimal-playable-string-instrument/mimetype",
    "Fixtures/VAO/valid/minimal-playable-string-instrument/vao-manifest.json",
    "Fixtures/VAO/valid/minimal-playable-string-instrument/payload/evidence/source.txt",
    "Fixtures/VAO/valid/minimal-acoustic-room/mimetype",
    "Fixtures/VAO/valid/minimal-acoustic-room/vao-manifest.json",
    "Fixtures/VAO/valid/minimal-acoustic-room/payload/evidence/measurement-protocol.txt",
    "Fixtures/VAO/valid/minimal-acoustic-room/payload/acoustics/room.sofa",
    "Fixtures/VAO/valid/minimal-acoustic-room/payload/models/room.ifc",
]


def digest(path: Path) -> tuple[str, int]:
    value = path.read_bytes()
    return hashlib.sha256(value).hexdigest(), len(value)


def info(name: str) -> zipfile.ZipInfo:
    result = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
    result.compress_type = zipfile.ZIP_DEFLATED
    result.create_system = 3
    result.external_attr = (stat.S_IFREG | 0o644) << 16
    result.flag_bits |= 0x800
    return result


def check() -> dict:
    missing = [name for name in FILES if not (ROOT / name).is_file()]
    if missing:
        raise vao03.VAO03Error("Release input is missing: " + ", ".join(missing))
    private = vao03.validate_workspace(ROOT / "Fixtures/VAO03/valid/embedded-private")
    sandbox = vao03.validate_workspace(ROOT / "Fixtures/VAO03/valid/zenodo-sandbox")
    acoustic = vao03.validate_workspace(ROOT / "Fixtures/VAO03/valid/acousticrooms-scene")
    kinoorgel = vao03.validate_manifest(vao03.load_json(
        ROOT / "Fixtures/VAO03/descriptors/kinoorgel-interaction.example.json"
    )[0])
    descriptors = {
        "singleRecord": vao03.validate_publication_set(
            ROOT / "Fixtures/VAO03/descriptors/release-single-record.example.json",
            [ROOT / "Fixtures/VAO03/descriptors/zenodo-metadata-single-record.example.json"],
        ),
        "recordFamily": vao03.validate_publication_set(
            ROOT / "Fixtures/VAO03/descriptors/release-record-family.example.json",
            [
                ROOT / "Fixtures/VAO03/descriptors/zenodo-metadata-family-root.example.json",
                ROOT / "Fixtures/VAO03/descriptors/zenodo-metadata-family-model.example.json",
                ROOT / "Fixtures/VAO03/descriptors/zenodo-metadata-family-audio.example.json",
            ],
        ),
        "pack": vao03.validate_descriptor(ROOT / "Fixtures/VAO03/descriptors/pack-manifest.example.json", vao03.PACK_SCHEMA),
        "receipt": vao03.validate_descriptor(ROOT / "Fixtures/VAO03/descriptors/materialization-receipt.example.json", vao03.RECEIPT_SCHEMA),
    }
    failures = private["errors"] + sandbox["errors"] + acoustic["errors"] + kinoorgel["errors"] + [error for report in descriptors.values() for error in report["errors"]]
    if failures:
        raise vao03.VAO03Error("Release input validation failed: " + "; ".join(failures[:12]))
    conformance = subprocess.run([sys.executable, str(ROOT / "Tools/test_vao03_conformance.py")], cwd=ROOT, capture_output=True, text=True)
    if conformance.returncode:
        raise vao03.VAO03Error("VAO 0.3 conformance suite failed: " + conformance.stdout[-2000:] + conformance.stderr[-1000:])
    summary_line = next((line for line in reversed(conformance.stdout.splitlines()) if line.startswith("{")), "{}")
    swift = subprocess.run(["swift", "test", "--filter", "VAO03Tests"], cwd=ROOT, capture_output=True, text=True)
    if swift.returncode:
        raise vao03.VAO03Error("Swift VAO 0.3 suite failed: " + swift.stdout[-2000:] + swift.stderr[-1000:])
    swift_counts = [(int(cases), int(failures)) for cases, failures in re.findall(r"Executed (\d+) tests, with (\d+) failures", swift.stdout + swift.stderr)]
    if not swift_counts:
        raise vao03.VAO03Error("Swift VAO 0.3 suite did not report an XCTest result.")
    swift_summary = {"caseCount": max(count for count, _ in swift_counts), "failed": max(failures for _, failures in swift_counts)}
    swift_summary["passed"] = swift_summary["caseCount"] - swift_summary["failed"]
    return {"privateFixture": private, "sandboxFixture": sandbox, "acousticRoomsFixture": acoustic, "kinoorgelInteractionFixture": kinoorgel, "descriptors": descriptors, "conformance": json.loads(summary_line), "swiftVAO03": swift_summary}


def build(output: Path, force: bool) -> dict:
    checks = check()
    if output.exists() and not force:
        raise vao03.VAO03Error(f"Output already exists: {output}; use --force to rebuild")
    output.parent.mkdir(parents=True, exist_ok=True)
    inventory = []
    for name in FILES:
        sha, size = digest(ROOT / name)
        inventory.append({"path": name, "byteSize": size, "sha256": sha})
    build_info = {
        "type": "VAOEditorDraftReleaseBundle",
        "formatVersion": "0.3.3",
        "status": "implemented-editor-draft",
        "publicationReady": False,
        "publicationBlockers": [
            "governance approval and public W3ID ownership are not complete",
            "MODAVIS dependencies are development bindings rather than released checksum pins",
            "media-type registration and production repository publication are not complete"
        ],
        "sandboxEvidence": {
            "recordId": "590947",
            "versionDOI": "10.5072/zenodo.590947",
            "conceptDOI": "10.5072/zenodo.590944",
            "optionalAdapter": True,
            "historicalFormatVersion": "0.3.0",
            "mutatedFor033": False
        },
        "checks": checks,
        "files": inventory,
    }
    temporary = output.with_name(f".{output.name}.tmp")
    temporary.unlink(missing_ok=True)
    with zipfile.ZipFile(temporary, "x", compression=zipfile.ZIP_DEFLATED, allowZip64=True) as archive:
        archive.writestr(info(f"{PREFIX}/BUILD_INFO.json"), vao03.json_bytes(build_info))
        for name in FILES:
            archive.writestr(info(f"{PREFIX}/{name}"), (ROOT / name).read_bytes())
        archive.comment = b"VAO 0.3.3 implemented editor draft"
    temporary.replace(output)
    sha, size = digest(output)
    checksum = output.with_suffix(output.suffix + ".sha256")
    checksum.write_text(f"{sha}  {output.name}\n", encoding="utf-8")
    return {"output": str(output), "byteSize": size, "sha256": sha, "checksum": str(checksum), "fileCount": len(FILES) + 1, "checks": checks}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default=str(ROOT / "dist/vao-specification-0.3.3-rc.zip"))
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    try:
        report = build(Path(args.output), args.force)
    except vao03.VAO03Error as exc:
        print(f"build_vao03_release: {exc}", file=sys.stderr)
        return 2
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
