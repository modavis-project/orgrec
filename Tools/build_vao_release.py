#!/usr/bin/env python3
"""Build a deterministic VAO 0.2.2 candidate, with guarded public-draft mode."""

from __future__ import annotations

import argparse
from datetime import date
import hashlib
import json
from pathlib import Path
import shutil
import stat
import tempfile
import zipfile

import check_vao_release
import vaom


ROOT = Path(__file__).resolve().parent.parent
VERSION = "0.2.2"
TOP = f"vao-{VERSION}"
RELEASE_FILES = [
    "Docs/VAO_AUTHORS.md",
    "Release/VAO-CITATION.cff",
    "Docs/VAO_CHANGELOG.md",
    "Docs/VAO_CONTRIBUTING.md",
    "Docs/VAO_SECURITY.md",
    "Docs/VAO_STANDARD.md",
    "Docs/VAO_IMPLEMENTATION_GUIDE.md",
    "Docs/VAO_CONFORMANCE.md",
    "Docs/VAO_GOVERNANCE.md",
    "Docs/VAO_RELEASE_CHECKLIST.md",
    "Docs/VAO_RELEASE_README_0.2.2.md",
    "Docs/VAO_PREPUBLICATION_PREPARATION.md",
    "Docs/VAO_MODAVIS_TERM_LEDGER.md",
    "Docs/VAO_LEGACY_CONCEPT_TRACEABILITY.md",
    "Docs/VAOM.md",
    "Docs/VAO_ORGREC_PROFILE.md",
    "Docs/LONG_TAKE_RECORDING.md",
    "Docs/AUDIO_AND_SPECTRAL_ANALYSIS.md",
    "Docs/TIMBRE_ANALYSIS.md",
    "Docs/COLLECTION_ACOUSTIC_DIAGNOSTICS.md",
    "Docs/LOOP_ANALYSIS_AND_SUSTAINED_PLAYBACK.md",
    "Docs/EXISTING_AUDIO_DATASET_TO_VAO.md",
    "Docs/GRANDORGUE_IMPORT.md",
    "Docs/BUREA_GRANDORGUE_VAO_CASE_STUDY.md",
    "Docs/POSITIVXR_VAO_MIGRATION.md",
    "Schemas/grandorgue-import-manifest.schema.json",
    "Schemas/vao-manifest.schema.json",
    "Schemas/vao-context.jsonld",
    "Schemas/vao-vocabulary.ttl",
    "Schemas/modavis-audio-loop.ttl",
    "Release/vao-release-metadata.json",
    "Tools/vaom.py",
    "Tools/check_vao_release.py",
    "Tools/build_vao_release.py",
    "Tools/test_vao_conformance.py",
    "Fixtures/VAO/README.md",
    "Fixtures/VAO/valid/minimal-string-instrument/mimetype",
    "Fixtures/VAO/valid/minimal-string-instrument/vao-manifest.json",
    "Fixtures/VAO/valid/minimal-string-instrument/payload/evidence/source.txt",
    "Fixtures/VAO/valid/minimal-playable-string-instrument/mimetype",
    "Fixtures/VAO/valid/minimal-playable-string-instrument/vao-manifest.json",
    "Fixtures/VAO/valid/minimal-playable-string-instrument/payload/evidence/source.txt",
    "Fixtures/VAO/valid/minimal-experiential-instrument/vao-manifest.json",
    "Fixtures/VAO/valid/minimal-experiential-instrument/mimetype",
    "Fixtures/VAO/valid/minimal-experiential-instrument/payload/media/model.glb",
    "Fixtures/VAO/valid/minimal-experiential-instrument/payload/media/performance.wav",
    "Fixtures/VAO/valid/minimal-experiential-instrument/payload/media/target.png",
    "Fixtures/VAO/valid/minimal-acoustic-room/mimetype",
    "Fixtures/VAO/valid/minimal-acoustic-room/vao-manifest.json",
    "Fixtures/VAO/valid/minimal-acoustic-room/payload/models/room.ifc",
    "Fixtures/VAO/valid/minimal-acoustic-room/payload/acoustics/room.sofa",
    "Fixtures/VAO/valid/minimal-acoustic-room/payload/evidence/measurement-protocol.txt",
    "Sources/OrgRecCore/VAOModels.swift",
    "Sources/OrgRecCore/VAOArchive.swift",
    "Sources/OrgRecCore/VAOManifestSchema.swift",
    "Sources/OrgRecCore/VAOExperientialValidation.swift",
    "Sources/OrgRecCore/VAOAcousticsSemanticValidation.swift",
    "Sources/OrgRecCore/VAOPackage.swift",
    "Sources/OrgRecCore/VAOPackageAccess.swift",
    "Sources/OrgRecCore/CollectionAnalysis.swift",
]


def digest(path: Path) -> tuple[str, int]:
    result = hashlib.sha256()
    size = 0
    with path.open("rb") as stream:
        while block := stream.read(1024 * 1024):
            result.update(block)
            size += len(block)
    return result.hexdigest(), size


def role(path: str) -> str:
    if path == "Schemas/grandorgue-import-manifest.schema.json":
        return "implementation-contract"
    if path.startswith("Schemas/"):
        return "normative"
    if path == "Docs/VAO_STANDARD.md":
        return "normative"
    if path.startswith("Fixtures/"):
        return "conformance-fixture"
    if path.startswith("Examples/"):
        return "conformance-example"
    if path.startswith(("Tools/", "Sources/")):
        return "reference-implementation"
    return "release-documentation"


def build(
    output_directory: Path,
    release_status: str = "release-candidate",
    release_date: str | None = None,
    publication_confirmation: str | None = None,
) -> tuple[Path, Path]:
    errors = check_vao_release.run_checks()
    if errors:
        raise RuntimeError("Release coherence failed: " + "; ".join(errors))
    if release_status not in {"release-candidate", "public-draft"}:
        raise ValueError(f"Unsupported release status: {release_status}")
    blockers = check_vao_release.publication_blockers()
    if release_status == "public-draft":
        if publication_confirmation != f"publish VAO {VERSION} public draft":
            raise RuntimeError("Public-draft build requires the exact explicit confirmation phrase.")
        if blockers:
            raise RuntimeError("Public-draft build is blocked: " + "; ".join(blockers))
        if release_date is None:
            raise RuntimeError("Public-draft build requires --release-date.")
        date.fromisoformat(release_date)
    elif release_date is not None:
        raise RuntimeError("A release candidate must not declare a publication date.")

    output_directory.mkdir(parents=True, exist_ok=True)
    suffix = "" if release_status == "public-draft" else "-rc"
    archive_path = output_directory / f"vao-specification-{VERSION}{suffix}.zip"
    checksum_path = output_directory / f"vao-specification-{VERSION}{suffix}.zip.sha256"
    if archive_path.exists() or checksum_path.exists():
        raise FileExistsError("Release output already exists; refusing to overwrite it")

    with tempfile.TemporaryDirectory(prefix="vao-release-") as temporary:
        stage = Path(temporary) / TOP
        for relative in RELEASE_FILES:
            source = ROOT / relative
            destination = stage / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)

        examples = stage / "Examples"
        examples.mkdir(parents=True, exist_ok=True)
        for fixture_name in (
            "minimal-string-instrument", "minimal-playable-string-instrument",
            "minimal-experiential-instrument", "minimal-acoustic-room",
        ):
            fixture_root = stage / "Fixtures/VAO/valid" / fixture_name
            example = examples / f"{fixture_name}.vao"
            with zipfile.ZipFile(example, "x", compression=zipfile.ZIP_STORED, allowZip64=True) as archive:
                archive.writestr(vaom.zip_info("mimetype"), (fixture_root / "mimetype").read_bytes())
                archive.writestr(vaom.zip_info(vaom.MANIFEST_NAME), (fixture_root / vaom.MANIFEST_NAME).read_bytes())
                for payload_path in vaom.iter_payload_files(fixture_root):
                    archive.writestr(vaom.zip_info(payload_path), (fixture_root / payload_path).read_bytes())
                archive.comment = f"VAO {VERSION} {fixture_name} conformance example".encode("ascii")
            example_report = vaom.validate_archive(example)
            if not example_report["valid"]:
                raise RuntimeError(
                    f"Generated example VAO {fixture_name} is invalid: "
                    + "; ".join(example_report["errors"][:3])
                )

        artifacts = []
        release_paths = sorted(
            path.relative_to(stage).as_posix()
            for path in stage.rglob("*")
            if path.is_file()
        )
        for relative in release_paths:
            checksum, size = digest(stage / relative)
            artifacts.append({"path": relative, "sha256": checksum, "byteSize": size, "role": role(relative)})
        release_manifest = {
            "type": "VAOSpecificationRelease",
            "version": VERSION,
            "compatibilityLine": "0.2",
            "supersedesPrivateSnapshot": "0.2.1",
            "changeClassification": "backward-compatible-patch-contract-revision",
            "status": release_status,
            "implementationMaturity": "checksum-pinned-private-snapshot" if release_status == "release-candidate" else "public-draft",
            "exactReleaseIRI": check_vao_release.EXPECTED_EXACT_IRI,
            "compatibilityIRI": check_vao_release.EXPECTED_COMPATIBILITY_IRI,
            "creators": [check_vao_release.load_release_metadata().get("creator")],
            "artifacts": artifacts,
            "publicationBlockers": [] if release_status == "public-draft" else blockers,
        }
        if release_status == "public-draft":
            release_manifest["releasedAt"] = release_date
        (stage / "release-manifest.json").write_text(
            json.dumps(release_manifest, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
            encoding="utf-8",
        )

        with zipfile.ZipFile(archive_path, "x", compression=zipfile.ZIP_STORED, allowZip64=True) as archive:
            for source in sorted(path for path in stage.rglob("*") if path.is_file()):
                relative = source.relative_to(stage.parent).as_posix()
                info = zipfile.ZipInfo(relative, date_time=(1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_STORED
                info.create_system = 3
                info.external_attr = (stat.S_IFREG | 0o644) << 16
                info.flag_bits |= 0x800
                archive.writestr(info, source.read_bytes())
            archive.comment = f"VAO specification {release_status} {VERSION}".encode("ascii")

    archive_hash, _ = digest(archive_path)
    checksum_path.write_text(f"{archive_hash}  {archive_path.name}\n", encoding="utf-8")
    return archive_path, checksum_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a VAO 0.2.2 release candidate (default) or guarded public draft")
    parser.add_argument("--output-directory", default=str(ROOT / "dist"))
    parser.add_argument("--release-status", choices=("release-candidate", "public-draft"), default="release-candidate")
    parser.add_argument("--release-date", help="ISO date; required only for a public-draft build")
    parser.add_argument("--confirm-publication", help="exact explicit confirmation phrase for public-draft mode")
    args = parser.parse_args()
    archive, checksum = build(
        Path(args.output_directory),
        release_status=args.release_status,
        release_date=args.release_date,
        publication_confirmation=args.confirm_publication,
    )
    print(archive)
    print(checksum)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
