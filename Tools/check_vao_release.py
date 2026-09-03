#!/usr/bin/env python3
"""Check VAO 0.2.2 preparation and, separately, publication readiness."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import vaom


ROOT = Path(__file__).resolve().parent.parent
EXPECTED_VERSION = "0.2.2"
EXPECTED_LINE = "0.2"
EXPECTED_SCHEMA = "https://w3id.org/modavis/vao/0.2/schema/manifest.json"
EXPECTED_CONTEXT = "https://w3id.org/modavis/vao/0.2/context.jsonld"
EXPECTED_EXACT_IRI = "https://w3id.org/modavis/vao/0.2.2/"
EXPECTED_COMPATIBILITY_IRI = "https://w3id.org/modavis/vao/0.2/"
EXPECTED_ORCID = "https://orcid.org/0000-0002-7904-3892"


def file_digest(path: Path) -> tuple[str, int]:
    result = hashlib.sha256()
    size = 0
    with path.open("rb") as stream:
        while block := stream.read(1024 * 1024):
            result.update(block)
            size += len(block)
    return result.hexdigest(), size


def load_release_metadata(root: Path = ROOT) -> dict:
    return json.loads((root / "Release/vao-release-metadata.json").read_text(encoding="utf-8"))


def publication_blockers(root: Path = ROOT) -> list[str]:
    """Return unresolved gates which make a public-draft build impermissible."""
    metadata = load_release_metadata(root)
    blockers: list[str] = []
    if metadata.get("noPublish") is not False:
        blockers.append("the noPublish guard has not been removed by the release authority")
    for key, label in (
        ("publisher", "publisher/release authority"),
        ("publicRepository", "durable public repository"),
        ("publicationHost", "publication host"),
        ("securityContact", "public security contact"),
    ):
        if not metadata.get(key):
            blockers.append(f"missing {label}")
    if not metadata.get("maintainerContacts"):
        blockers.append("missing public maintainer contact")
    for record in metadata.get("licenses", {}).values():
        if not record.get("approved"):
            blockers.append(f"license approval pending: {record.get('proposed', 'unspecified')}")
    for review, reviewers in metadata.get("requiredReviews", {}).items():
        if not reviewers:
            blockers.append(f"no reviewer named for {review}")
    dependencies = metadata.get("dependencies", {})
    ontology = dependencies.get("modavisOntologyRelease", {})
    if ontology.get("status") != "released" or not ontology.get("versionIRI") or not ontology.get("mappingIRI"):
        blockers.append("exact MODAVIS ontology release and VAO mapping are not pinned")
    vocabulary = dependencies.get("modavisRelease13VocabularySnapshot", {})
    if vocabulary.get("status") != "released" or not vocabulary.get("releaseIRI") or not vocabulary.get("manifestSHA256"):
        blockers.append("immutable MODAVIS Release 1.3 vocabulary snapshot is not pinned")
    return blockers


def run_checks(root: Path = ROOT) -> list[str]:
    errors: list[str] = []

    def require(condition: bool, message: str) -> None:
        if not condition:
            errors.append(message)

    require(vaom.FORMAT_VERSION == EXPECTED_VERSION, "VAOM format version drift")
    require(vaom.SCHEMA_URI == EXPECTED_SCHEMA, "VAOM schema URI drift")
    require(vaom.CONTEXT_URI == EXPECTED_CONTEXT, "VAOM context URI drift")
    require(vaom.CORE_PROFILE.endswith("/core/0.2"), "VAOM core profile drift")
    require(vaom.ACOUSTICS_PROFILE.endswith("/acoustics/0.2"), "VAOM acoustics profile drift")
    require(vaom.EXPERIENTIAL_PROFILE.endswith("/experiential/0.2"), "VAOM experiential profile drift")

    schema = json.loads((root / "Schemas/vao-manifest.schema.json").read_text(encoding="utf-8"))
    require(schema.get("$id") == EXPECTED_SCHEMA, "JSON Schema id drift")
    require(schema.get("properties", {}).get("formatVersion", {}).get("pattern") == r"^0\.2\.[0-9]+$", "JSON Schema version pattern drift")
    context = json.loads((root / "Schemas/vao-context.jsonld").read_text(encoding="utf-8"))["@context"]
    for term in ("sourceRegionId", "valueAssetId", "channelIndices", "clockAssetId", "aggregation", "primaryEntityId", "focusEntityIds", "coordinateFrames", "responseSets", "audioScenes", "renderConfigurations"):
        require(term in context, f"JSON-LD observation term is missing: {term}")
    require(context.get("unit", {}).get("@type") == "@id", "JSON-LD observation unit must expand as an IRI")
    grandorgue_schema = json.loads(
        (root / "Schemas/grandorgue-import-manifest.schema.json").read_text(encoding="utf-8")
    )
    require(
        grandorgue_schema.get("properties", {}).get("contract", {}).get("const")
        == "orgrec.grandorgue-import-manifest/v1",
        "GrandOrgue import-manifest schema contract drift",
    )
    require(
        grandorgue_schema.get("$schema") == "https://json-schema.org/draft/2020-12/schema",
        "GrandOrgue import-manifest schema dialect drift",
    )

    vocabulary = (root / "Schemas/vao-vocabulary.ttl").read_text(encoding="utf-8")
    require('owl:versionInfo "0.2.2"' in vocabulary, "RDF vocabulary version drift")
    for term in (
        "SampleExtractionRegion", "SamplePlaybackParameters", "TuningMap",
        "sampled-instrument-playback", "source-segmentation", "acoustical-analysis",
        "vocab/unit/cent", "AcousticResponseSet", "RenderConfiguration",
        "semantic-building-model", "measured-impulse-response", "learned-acoustic-field",
        "empirical-timbre-classification", "pitch-dependent-rank-fingerprint", "machine-learning-model",
        "collection-acoustic-diagnostics", "evidence-qualified-collection-acoustic-diagnostics",
        "analysis/collection/evidence-summary", "analysis/collection/take-evidence",
        "analysis/collection/rank-tuning-curves", "analysis/collection/rank-stretch",
        "analysis/collection/session-offset", "analysis/collection/session-drift",
        "analysis/collection/acoustic-anomaly-candidates",
        "analysis/collection/acoustic-similarity-candidates",
    ):
        require(term in vocabulary, f"VAO 0.2.2 vocabulary term is missing: {term}")

    audio_vocabulary = (root / "Schemas/modavis-audio-loop.ttl").read_text(encoding="utf-8")
    require('owl:versionInfo "0.2.0-dev"' in audio_vocabulary, "Provisional audio vocabulary version drift")
    for term in ("SampleExtractionRegion", "SamplePlaybackParameters", "TuningMap", "tuningEntries"):
        require(term in audio_vocabulary, f"Provisional audio term is missing: {term}")

    swift = (root / "Sources/OrgRecCore/VAOModels.swift").read_text(encoding="utf-8")
    require('formatVersion = "0.2.2"' in swift, "OrgRec format version drift")
    require('/vao/0.2/schema/manifest.json' in swift, "OrgRec schema URI drift")
    require('/profile/core/0.2' in swift, "OrgRec profile URI drift")
    require('/profile/acoustics/0.2' in swift, "OrgRec acoustics profile URI drift")
    require('/profile/experiential/0.2' in swift, "OrgRec experiential profile URI drift")
    for capability in (
        "generic-model-viewing",
        "synchronized-media-animation",
        "image-target-ar",
        "surface-placement-ar",
        "spatial-listening-map",
        "offline-asset-groups",
        "replaceable-performance-media",
        "sampled-instrument-playback",
        "source-segmentation",
        "acoustical-analysis",
        "tuning-map",
        "semantic-building-model",
        "measured-impulse-response",
        "spatial-response-field",
        "room-acoustic-metrics",
        "spatial-audio-scene",
        "tracked-listener-convolution",
        "learned-acoustic-field",
        "collection-acoustic-diagnostics",
    ):
        require(capability in swift, f"OrgRec experiential capability drift: {capability}")

    experiential_validation = (
        root / "Sources/OrgRecCore/VAOExperientialValidation.swift"
    ).read_text(encoding="utf-8")
    require(
        "VAOExperientialValidator" in experiential_validation,
        "OrgRec native experiential validation is missing",
    )
    acoustic_validation = (
        root / "Sources/OrgRecCore/VAOAcousticsSemanticValidation.swift"
    ).read_text(encoding="utf-8")
    require("VAOAcousticsSemanticValidator" in acoustic_validation, "OrgRec native acoustic validation is missing")
    package_access = (root / "Sources/OrgRecCore/VAOPackageAccess.swift").read_text(encoding="utf-8")
    require("VAOPackageReader" in package_access, "OrgRec general VAO reader is missing")
    require("VAOPackageWriter" in package_access, "OrgRec general VAO writer is missing")
    require("metadataOnly" in package_access, "OrgRec experiential processing disclosure is missing")
    package_builder = (root / "Sources/OrgRecCore/VAOPackage.swift").read_text(encoding="utf-8")
    require('mappingVersion: "vao-modavis-mapping/0.2.2"' in package_builder, "OrgRec mapping version drift")
    release_builder = (root / "Tools/build_vao_release.py").read_text(encoding="utf-8")
    require('VERSION = "0.2.2"' in release_builder, "Release builder version drift")

    specification = (root / "Docs/VAO_STANDARD.md").read_text(encoding="utf-8")
    require("Target version: 0.2.2" in specification, "Specification version drift")
    require(EXPECTED_EXACT_IRI in specification, "Specification exact-release IRI drift")
    require("VAO 0.2" in specification, "Specification line is missing")
    for term in ("AES69-2022", "ISO/IEC 23090-4:2025", "neural acoustic fields", "building-acoustic-performance"):
        require(term.lower() in specification.lower(), f"Specification acoustic coverage is missing: {term}")

    changelog = (root / "Docs/VAO_CHANGELOG.md").read_text(encoding="utf-8")
    require("## Unreleased — target 0.2.2" in changelog, "Changelog target version drift")
    require("## 0.1.1 — prior private implementation snapshot" in changelog, "0.1.1 baseline history is missing")
    require("backward-compatible patch contract revision" in changelog, "0.2.2 compatibility classification is missing")

    release_readme = (root / "Docs/VAO_RELEASE_README_0.2.2.md").read_text(encoding="utf-8")
    require("# Planned VAO 0.2.2 release contents" in release_readme, "Release README version drift")
    implementation_guide = (root / "Docs/VAO_IMPLEMENTATION_GUIDE.md").read_text(encoding="utf-8")
    require("generated `0.2.2` candidate snapshots" in implementation_guide, "Implementation guide version drift")
    citation = (root / "Release/VAO-CITATION.cff").read_text(encoding="utf-8")
    require('version: "0.2.2-dev"' in citation, "Citation version drift")

    release_metadata = load_release_metadata(root)
    require(release_metadata.get("targetVersion") == EXPECTED_VERSION, "Release metadata version drift")
    require(release_metadata.get("compatibilityLine") == EXPECTED_LINE, "Release metadata compatibility-line drift")
    require(release_metadata.get("supersedesPrivateSnapshot") == "0.2.1", "Prior snapshot metadata drift")
    require(release_metadata.get("changeClassification") == "backward-compatible-patch-contract-revision", "Change classification drift")
    require(release_metadata.get("readerCompatibility") == "0.2.x", "Reader compatibility metadata drift")
    require(release_metadata.get("exactReleaseIRI") == EXPECTED_EXACT_IRI, "Exact release IRI drift")
    require(release_metadata.get("compatibilityIRI") == EXPECTED_COMPATIBILITY_IRI, "Compatibility IRI drift")
    require(release_metadata.get("creator", {}).get("orcid") == EXPECTED_ORCID, "Creator ORCID drift")
    expected_maturity = (
        "public-draft" if release_metadata.get("noPublish") is False
        else "checksum-pinned-private-snapshot"
    )
    require(
        release_metadata.get("implementationMaturity") == expected_maturity,
        "Implementation maturity metadata drift",
    )

    release_files = [
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
        "Fixtures/VAO/valid/minimal-string-instrument/vao-manifest.json",
        "Fixtures/VAO/valid/minimal-playable-string-instrument/vao-manifest.json",
        "Fixtures/VAO/valid/minimal-experiential-instrument/vao-manifest.json",
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
    for relative in release_files:
        require((root / relative).is_file(), f"Missing release artifact: {relative}")

    prohibited = {
        "Docs/VAO_STANDARD.md": ["VAO 1.0", "/profile/core/1.0", "/vao/1.0/"],
        "Docs/VAOM.md": ["VAO 1.0"],
        "Docs/VAO_ORGREC_PROFILE.md": ["VAO 1.0", "/profile/core/1.0"],
        "Tools/vaom.py": ['FORMAT_VERSION = "1.0.0"', "/profile/core/1.0"],
        "Sources/OrgRecCore/VAOModels.swift": ['formatVersion = "1.0.0"', "/profile/core/1.0"],
    }
    for relative, fragments in prohibited.items():
        text = (root / relative).read_text(encoding="utf-8")
        for fragment in fragments:
            require(fragment not in text, f"Stale release fragment {fragment!r} in {relative}")

    fixture = vaom.validate_workspace(root / "Fixtures/VAO/valid/minimal-string-instrument")
    require(fixture["valid"], "Positive fixture failed: " + "; ".join(fixture["errors"][:3]))
    require(fixture.get("formatVersion") == EXPECTED_VERSION, "Core fixture version drift")
    playable_fixture = vaom.validate_workspace(root / "Fixtures/VAO/valid/minimal-playable-string-instrument")
    require(
        playable_fixture["valid"],
        "Positive playable fixture failed: " + "; ".join(playable_fixture["errors"][:3]),
    )
    require(playable_fixture.get("formatVersion") == EXPECTED_VERSION, "Playable fixture version drift")
    experiential_root = root / "Fixtures/VAO/valid/minimal-experiential-instrument"
    experiential_manifest = vaom.load_json(experiential_root / vaom.MANIFEST_NAME)
    experiential_fixture = vaom.validate_manifest(
        experiential_manifest,
        payload_names=vaom.iter_payload_files(experiential_root),
        payload_reader=lambda name: vaom.sha256_file(experiential_root / name),
    )
    require(
        experiential_fixture["valid"],
        "Positive experiential fixture failed: " + "; ".join(experiential_fixture["errors"][:3]),
    )
    require(experiential_fixture.get("formatVersion") == EXPECTED_VERSION, "Experiential fixture version drift")
    acoustic_fixture = vaom.validate_workspace(root / "Fixtures/VAO/valid/minimal-acoustic-room")
    require(
        acoustic_fixture["valid"],
        "Positive acoustic fixture failed: " + "; ".join(acoustic_fixture["errors"][:3]),
    )
    require(acoustic_fixture.get("formatVersion") == EXPECTED_VERSION, "Acoustic fixture version drift")

    release_manifest_path = root / "release-manifest.json"
    if release_manifest_path.is_file():
        release_manifest = json.loads(release_manifest_path.read_text(encoding="utf-8"))
        require(release_manifest.get("version") == EXPECTED_VERSION, "Release manifest version drift")
        require(release_manifest.get("supersedesPrivateSnapshot") == "0.2.1", "Release manifest predecessor drift")
        require(release_manifest.get("changeClassification") == "backward-compatible-patch-contract-revision", "Release manifest change classification drift")
        declared: set[str] = set()
        for record in release_manifest.get("artifacts", []):
            if not isinstance(record, dict) or not isinstance(record.get("path"), str):
                errors.append("Release manifest contains a malformed artifact record")
                continue
            relative = record["path"]
            parts = Path(relative).parts
            if Path(relative).is_absolute() or ".." in parts:
                errors.append(f"Release manifest contains an unsafe path: {relative}")
                continue
            declared.add(relative)
            artifact = root / relative
            if not artifact.is_file():
                errors.append(f"Release manifest artifact is missing: {relative}")
                continue
            checksum, size = file_digest(artifact)
            require(record.get("sha256") == checksum, f"Release manifest checksum mismatch: {relative}")
            require(record.get("byteSize") == size, f"Release manifest byte-size mismatch: {relative}")
        actual = {
            path.relative_to(root).as_posix()
            for path in root.rglob("*")
            if path.is_file() and path != release_manifest_path and "__pycache__" not in path.parts
        }
        for relative in sorted(actual - declared):
            errors.append(f"Release file is not checksum-indexed: {relative}")
        for relative in sorted(declared - actual):
            errors.append(f"Checksum-indexed release file is absent: {relative}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description="Check a VAO 0.2.2 source or extracted release tree")
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument(
        "--publication-ready",
        action="store_true",
        help="also fail unless every owner, review, semantic, and infrastructure gate is resolved",
    )
    args = parser.parse_args()
    errors = run_checks(args.root.resolve())
    blockers = publication_blockers(args.root.resolve())
    result = {
        "release": EXPECTED_VERSION,
        "compatibilityLine": EXPECTED_LINE,
        "status": "PASS" if not errors else "FAIL",
        "implementationReady": not errors,
        "implementationScope": "checksum-pinned private development and controlled interoperability",
        "publicationReady": not errors and not blockers,
        "publicationBlockers": blockers,
        "errors": errors,
    }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if not errors and (not args.publication_ready or not blockers) else 1


if __name__ == "__main__":
    raise SystemExit(main())
