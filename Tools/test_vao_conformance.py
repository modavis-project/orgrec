#!/usr/bin/env python3
"""Executable positive and negative conformance suite for VAO 0.2."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import shutil
import tempfile
import zipfile

import vaom


ROOT = Path(__file__).resolve().parent.parent
FIXTURE = ROOT / "Fixtures" / "VAO" / "valid" / "minimal-string-instrument"
PLAYABLE_FIXTURE = ROOT / "Fixtures" / "VAO" / "valid" / "minimal-playable-string-instrument"
EXPERIENTIAL_FIXTURE = ROOT / "Fixtures" / "VAO" / "valid" / "minimal-experiential-instrument"
ACOUSTIC_FIXTURE = ROOT / "Fixtures" / "VAO" / "valid" / "minimal-acoustic-room"
NEGATIVE_CASES = 0


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def require_invalid(report: dict, phrase: str, case: str) -> None:
    global NEGATIVE_CASES
    NEGATIVE_CASES += 1
    require(not report["valid"], f"{case}: mutation was incorrectly accepted")
    combined = "\n".join(report["errors"])
    require(phrase.lower() in combined.lower(), f"{case}: expected {phrase!r} in:\n{combined}")


def collection_diagnostics_manifest(source: dict) -> dict:
    """Return a minimal, complete 0.2.2 collection-diagnostics claim."""
    manifest = copy.deepcopy(source)
    take_id = "urn:uuid:00000000-0000-4000-8000-000000000003"
    rank_id = "urn:uuid:00000000-0000-4000-8000-000000000002"
    activity_id = "urn:uuid:00000000-0000-4000-8000-000000000020"
    analysis_id = "urn:uuid:00000000-0000-4000-8000-000000000021"
    manifest["profiles"].append({
        "id": vaom.RESEARCH_PROFILE,
        "version": "0.2",
        "requiredCapabilities": [
            vaom.VAO_VOCABULARY + "capability/paradata",
            vaom.VAO_VOCABULARY + "capability/analysis",
            vaom.ACOUSTICAL_ANALYSIS,
            vaom.COLLECTION_ACOUSTIC_DIAGNOSTICS,
        ],
    })
    manifest["conformsTo"].append(vaom.RESEARCH_PROFILE)
    manifest["entities"].append({
        "id": take_id,
        "kind": "measurement",
        "types": [vaom.VAO_ONTOLOGY + "AcousticTakeMeasurement"],
        "labels": {"en": "Evidence-qualified fixture take"},
        "properties": {},
    })
    parameter_values = {
        "minimumAggregateQualityScore": 0.45,
        "moderateQualityScore": 0.60,
        "highQualityScore": 0.80,
        "minimumAnomalyGroupSize": 4,
        "anomalyWarningScore": 3.5,
        "anomalyCriticalScore": 5.0,
        "similarityThreshold": 0.97,
        "minimumSimilarityHarmonics": 6,
        "maximumSimilarityCandidates": 100,
        "minimumDriftRepeatedTargets": 2,
        "minimumDriftPairComparisons": 3,
        "minimumDriftSpanHours": 0.25,
    }
    parameters = {vaom.VAO_ONTOLOGY + key: value for key, value in parameter_values.items()}
    parameters[vaom.VAO_ONTOLOGY + "parameterSHA256"] = "0" * 64
    manifest["paradata"] = [{
        "id": activity_id,
        "activityType": vaom.VAO_VOCABULARY + "activity/CollectionAcousticDiagnostics",
        "startedAt": "2026-08-20T00:00:00Z",
        "software": {"name": "VAO conformance fixture", "version": "0.2.2"},
        "method": {"methodType": "metric-calculation", "representationStatus": "inferred"},
        "inputIds": [take_id],
        "outputIds": [analysis_id],
        "parameters": parameters,
    }]
    manifest["analyses"] = [{
        "id": analysis_id,
        "analysisType": vaom.COLLECTION_ACOUSTIC_DIAGNOSTICS_ANALYSIS,
        "method": "Evidence-qualified collection acoustic diagnostics",
        "version": "orgrec-collection-analysis/2",
        "generatedAt": "2026-08-20T00:00:00Z",
        "inputIds": [take_id],
        "outputIds": [],
        "paradataId": activity_id,
        "observations": [
            {
                "property": vaom.COLLECTION_EVIDENCE_SUMMARY,
                "value": {
                    "eligibleTakeCount": 1,
                    "analyzedTakeCount": 1,
                    "aggregateTakeCount": 1,
                    "highQualityCount": 1,
                    "moderateQualityCount": 0,
                    "limitedQualityCount": 0,
                    "excludedCount": 0,
                    "aggregateCoverage": 1.0,
                },
                "coverage": 1.0,
                "evidenceCount": 1,
                "status": "inferred",
                "applicability": "applicable",
                "subjectId": manifest["primaryEntityId"],
            },
            {
                "property": vaom.COLLECTION_TAKE_EVIDENCE,
                "value": [{
                    "takeId": take_id,
                    "rankGroupId": rank_id,
                    "keyNumber": 60,
                    "qualityScore": 0.9,
                    "tier": "high",
                    "includedInAggregates": True,
                }],
                "evidenceCount": 1,
                "status": "inferred",
                "applicability": "applicable",
                "subjectId": manifest["primaryEntityId"],
            },
            {
                "property": vaom.COLLECTION_RANK_CURVES,
                "value": [{
                    "rankGroupId": rank_id,
                    "groupingBasis": "declared-parent-component",
                    "points": [{
                        "keyNumber": 60,
                        "medianDeviationCents": 0.5,
                        "medianAbsoluteDeviationCents": 0.2,
                        "evidenceCount": 1,
                    }],
                }],
                "unit": vaom.VAO_VOCABULARY + "unit/cent",
                "evidenceCount": 1,
                "status": "inferred",
                "applicability": "applicable",
                "aggregation": vaom.VAO_VOCABULARY + "aggregation/quality-weighted-median",
                "subjectId": manifest["primaryEntityId"],
            },
            {
                "property": vaom.COLLECTION_RANK_STRETCH,
                "value": [],
                "unit": vaom.VAO_VOCABULARY + "unit/cent-per-octave",
                "evidenceCount": 0,
                "status": "inferred",
                "applicability": "indeterminate",
                "aggregation": vaom.VAO_VOCABULARY + "aggregation/siegel-repeated-median",
                "subjectId": manifest["primaryEntityId"],
            },
            {
                "property": vaom.COLLECTION_SESSION_OFFSET,
                "value": [],
                "unit": vaom.VAO_VOCABULARY + "unit/cent",
                "evidenceCount": 0,
                "status": "inferred",
                "applicability": "indeterminate",
                "aggregation": vaom.VAO_VOCABULARY + "aggregation/median",
                "subjectId": manifest["primaryEntityId"],
            },
            {
                "property": vaom.COLLECTION_SESSION_DRIFT,
                "value": [],
                "unit": vaom.VAO_VOCABULARY + "unit/cent-per-hour",
                "evidenceCount": 0,
                "status": "inferred",
                "applicability": "indeterminate",
                "aggregation": vaom.VAO_VOCABULARY + "aggregation/within-target-median-slope",
                "subjectId": manifest["primaryEntityId"],
            },
            {
                "property": vaom.COLLECTION_ANOMALIES,
                "value": [],
                "evidenceCount": 1,
                "status": "inferred",
                "applicability": "applicable",
                "aggregation": vaom.VAO_VOCABULARY + "aggregation/robust-multivariate-distance",
                "subjectId": manifest["primaryEntityId"],
            },
            {
                "property": vaom.COLLECTION_SIMILARITIES,
                "value": [],
                "evidenceCount": 1,
                "status": "inferred",
                "applicability": "applicable",
                "aggregation": vaom.VAO_VOCABULARY + "aggregation/harmonic-aligned-cosine",
                "subjectId": manifest["primaryEntityId"],
            },
        ],
    }]
    return manifest


def main() -> int:
    positive = vaom.validate_workspace(FIXTURE)
    require(positive["valid"], "positive workspace failed:\n" + "\n".join(positive["errors"]))
    playable_positive = vaom.validate_workspace(PLAYABLE_FIXTURE)
    require(
        playable_positive["valid"],
        "positive playable workspace failed:\n" + "\n".join(playable_positive["errors"]),
    )
    experiential_manifest = vaom.load_json(EXPERIENTIAL_FIXTURE / vaom.MANIFEST_NAME)
    experiential_positive = vaom.validate_manifest(
        experiential_manifest,
        payload_names=vaom.iter_payload_files(EXPERIENTIAL_FIXTURE),
        payload_reader=lambda name: vaom.sha256_file(EXPERIENTIAL_FIXTURE / name),
    )
    require(
        experiential_positive["valid"],
        "positive experiential fixture failed:\n" + "\n".join(experiential_positive["errors"]),
    )
    acoustic_manifest = vaom.load_json(ACOUSTIC_FIXTURE / vaom.MANIFEST_NAME)
    acoustic_positive = vaom.validate_workspace(ACOUSTIC_FIXTURE)
    require(
        acoustic_positive["valid"],
        "positive acoustic fixture failed:\n" + "\n".join(acoustic_positive["errors"]),
    )

    with tempfile.TemporaryDirectory(prefix="vao-0.2-conformance-") as temporary:
        root = Path(temporary)
        workspace = root / "workspace"
        shutil.copytree(FIXTURE, workspace)
        archive = root / "minimal-string-instrument.vao"
        args = type("Arguments", (), {"workspace": str(workspace), "output": str(archive)})()
        vaom.command_pack(args)
        packed = vaom.validate_archive(archive)
        require(packed["valid"], "packed fixture failed:\n" + "\n".join(packed["errors"]))

        unpacked = root / "unpacked"
        unpack_args = type("Arguments", (), {"source": str(archive), "destination": str(unpacked), "force": False})()
        vaom.command_unpack(unpack_args)
        require(vaom.validate_workspace(unpacked)["valid"], "unpacked fixture did not round-trip")

        corrupt = root / "corrupt"
        shutil.copytree(FIXTURE, corrupt)
        (corrupt / "payload/evidence/source.txt").write_text("corrupted\n", encoding="utf-8")
        require_invalid(vaom.validate_workspace(corrupt), "hash mismatch", "corrupt fixity")

        unindexed = root / "unindexed"
        shutil.copytree(FIXTURE, unindexed)
        (unindexed / "payload/evidence/unindexed.txt").write_text("hidden payload\n", encoding="utf-8")
        require_invalid(vaom.validate_workspace(unindexed), "not indexed", "unindexed payload")

        manifest = vaom.load_json(FIXTURE / vaom.MANIFEST_NAME)

        collection_manifest = collection_diagnostics_manifest(manifest)
        collection_positive = vaom.validate_manifest(collection_manifest)
        require(
            collection_positive["valid"],
            "positive collection-diagnostics contract failed:\n" + "\n".join(collection_positive["errors"]),
        )
        require(
            vaom.COLLECTION_ACOUSTIC_DIAGNOSTICS in collection_positive["supportedCapabilities"],
            "collection-diagnostics capability was not reported as supported",
        )

        unknown_capability_manifest = copy.deepcopy(manifest)
        unknown_capability = "https://example.org/vao/capability/future-research-method"
        unknown_capability_manifest["profiles"][0]["requiredCapabilities"].append(unknown_capability)
        unknown_capability_report = vaom.validate_manifest(unknown_capability_manifest)
        require(unknown_capability_report["valid"], "an unknown future capability must remain structurally readable")
        require(
            unknown_capability_report["unsupportedCapabilities"] == [unknown_capability],
            "unknown future capability was not disclosed as unsupported",
        )

        non_finite_manifest = copy.deepcopy(manifest)
        non_finite_manifest["entities"][0]["properties"]["https://example.org/nonFinite"] = float("nan")
        require_invalid(
            vaom.validate_manifest(non_finite_manifest),
            "non-finite JSON number",
            "programmatic non-finite observation",
        )

        legacy_source = root / "legacy-0.1-workspace"
        migrated_destination = root / "migrated-0.2-workspace"
        shutil.copytree(FIXTURE, legacy_source)
        legacy_manifest = copy.deepcopy(manifest)
        legacy_manifest["rootEntityId"] = legacy_manifest.pop("primaryEntityId")
        legacy_manifest.pop("focusEntityIds")
        legacy_manifest["formatVersion"] = "0.1.2"
        legacy_manifest["$schema"] = "https://w3id.org/modavis/vao/0.1/schema/manifest.json"
        legacy_manifest["@context"] = ["https://w3id.org/modavis/vao/0.1/context.jsonld"]
        legacy_manifest["conformsTo"] = [value.removesuffix("/0.2") + "/0.1" for value in legacy_manifest["conformsTo"]]
        for profile in legacy_manifest["profiles"]:
            profile["id"] = profile["id"].removesuffix("/0.2") + "/0.1"
            profile["version"] = "0.1"
        legacy_manifest["modavisBinding"]["mappingVersion"] = "vao-modavis-mapping/0.1.2"
        vaom.write_json(legacy_source / vaom.MANIFEST_NAME, legacy_manifest)
        migrate_args = type(
            "Arguments",
            (),
            {"source": str(legacy_source), "destination": str(migrated_destination)},
        )()
        require(vaom.command_migrate(migrate_args) == 0, "0.1 migration command reported failure")
        migrated_report = vaom.validate_workspace(migrated_destination)
        require(migrated_report["valid"], "migrated 0.2 workspace failed validation")
        require(
            vaom.load_json(legacy_source / vaom.MANIFEST_NAME)["formatVersion"] == "0.1.2",
            "migration modified its source workspace",
        )
        migrated_manifest = vaom.load_json(migrated_destination / vaom.MANIFEST_NAME)
        migration_inputs = [
            asset for asset in migrated_manifest["assets"]
            if asset.get("path", "").startswith("payload/migration/source-manifest-")
            and vaom.SOURCE_EVIDENCE in asset.get("roles", [])
        ]
        require(len(migration_inputs) == 1, "migration did not retain exactly one source-manifest evidence asset")
        migration_activities = [
            activity for activity in migrated_manifest["paradata"]
            if activity.get("activityType") == vaom.VAO_ONTOLOGY + "MigrationActivity"
        ]
        require(len(migration_activities) == 1, "migration did not record exactly one migration activity")
        require(
            migration_activities[0]["inputIds"] == [migration_inputs[0]["id"]],
            "migration activity is not bound to the retained source manifest",
        )

        previous_private_patch = copy.deepcopy(manifest)
        previous_private_patch["formatVersion"] = "0.2.0"
        previous_private_patch_report = vaom.validate_manifest(previous_private_patch)
        require(
            previous_private_patch_report["valid"],
            "reader compatibility failed for a conforming 0.2.0 manifest:\n"
            + "\n".join(previous_private_patch_report["errors"]),
        )

        immediately_previous_patch = copy.deepcopy(manifest)
        immediately_previous_patch["formatVersion"] = "0.2.1"
        immediately_previous_patch_report = vaom.validate_manifest(immediately_previous_patch)
        require(
            immediately_previous_patch_report["valid"],
            "reader compatibility failed for a conforming 0.2.1 manifest:\n"
            + "\n".join(immediately_previous_patch_report["errors"]),
        )

        original_private_patch = copy.deepcopy(manifest)
        original_private_patch["formatVersion"] = "0.2.7"
        require(
            vaom.validate_manifest(original_private_patch)["valid"],
            "reader compatibility failed for a conforming 0.2.7 manifest",
        )

        missing_rights = copy.deepcopy(manifest)
        missing_rights["rights"] = []
        require_invalid(vaom.validate_manifest(missing_rights), "rights", "missing rights")

        missing_representation_status = copy.deepcopy(manifest)
        del missing_representation_status["assets"][0]["representationStatus"]
        require_invalid(
            vaom.validate_manifest(missing_representation_status),
            "representationStatus",
            "missing representation status",
        )

        unsafe = copy.deepcopy(manifest)
        unsafe["assets"][0]["path"] = "payload/../escape.txt"
        require_invalid(vaom.validate_manifest(unsafe), "unsafe payload path", "unsafe path")

        incompatible = copy.deepcopy(manifest)
        incompatible["formatVersion"] = "0.3.3"
        require_invalid(vaom.validate_manifest(incompatible), "unsupported VAO format", "incompatible minor")

        missing_empirical_contract = copy.deepcopy(experiential_manifest)
        research_profile = next(
            profile for profile in missing_empirical_contract["profiles"]
            if profile["id"] == vaom.RESEARCH_PROFILE
        )
        research_profile["requiredCapabilities"].append(vaom.EMPIRICAL_TIMBRE_CLASSIFICATION)
        require_invalid(
            vaom.validate_manifest(missing_empirical_contract),
            "hierarchical classification analysis",
            "empirical classifier claim without model and analysis",
        )

        missing_fingerprint_contract = copy.deepcopy(experiential_manifest)
        research_profile = next(
            profile for profile in missing_fingerprint_contract["profiles"]
            if profile["id"] == vaom.RESEARCH_PROFILE
        )
        research_profile["requiredCapabilities"].append(vaom.PITCH_DEPENDENT_RANK_FINGERPRINT)
        require_invalid(
            vaom.validate_manifest(missing_fingerprint_contract),
            "rank-fingerprint analysis",
            "rank fingerprint claim without trajectory analysis",
        )

        missing_collection_contract = copy.deepcopy(experiential_manifest)
        research_profile = next(
            profile for profile in missing_collection_contract["profiles"]
            if profile["id"] == vaom.RESEARCH_PROFILE
        )
        research_profile["requiredCapabilities"].append(vaom.COLLECTION_ACOUSTIC_DIAGNOSTICS)
        require_invalid(
            vaom.validate_manifest(missing_collection_contract),
            "evidence-qualified collection analysis",
            "collection diagnostics claim without governed analysis",
        )

        inconsistent_collection_summary = copy.deepcopy(collection_manifest)
        collection_analysis = next(
            record for record in inconsistent_collection_summary["analyses"]
            if record["analysisType"] == vaom.COLLECTION_ACOUSTIC_DIAGNOSTICS_ANALYSIS
        )
        summary_observation = next(
            observation for observation in collection_analysis["observations"]
            if observation["property"] == vaom.COLLECTION_EVIDENCE_SUMMARY
        )
        summary_observation["value"]["aggregateCoverage"] = 0.5
        require_invalid(
            vaom.validate_manifest(inconsistent_collection_summary),
            "inconsistent evidence summary",
            "collection diagnostics with inconsistent evidence coverage",
        )

        unpinned_released_binding = copy.deepcopy(manifest)
        unpinned_released_binding["modavisBinding"]["ontologyStatus"] = "released"
        require_invalid(
            vaom.validate_manifest(unpinned_released_binding),
            "ontologyVersionIRI",
            "released ontology binding without immutable IRIs",
        )

        unpinned_vocabulary = copy.deepcopy(manifest)
        unpinned_vocabulary["modavisBinding"]["vocabularyReleaseIRI"] = "https://w3id.org/modavis/vocab/1.3/"
        require_invalid(
            vaom.validate_manifest(unpinned_vocabulary),
            "SHA-256",
            "vocabulary binding without manifest checksum",
        )

        unknown_field = copy.deepcopy(manifest)
        unknown_field["unregisteredField"] = True
        require_invalid(vaom.validate_manifest(unknown_field), "unknown property", "unknown standard field")

        unqualified_extension_property = copy.deepcopy(manifest)
        unqualified_extension_property["entities"][0]["properties"]["localName"] = "ambiguous"
        require_invalid(
            vaom.validate_manifest(unqualified_extension_property),
            "valid uri",
            "extension property without absolute IRI",
        )

        incomplete_orgrec = copy.deepcopy(manifest)
        incomplete_orgrec["profiles"].extend([
            {
                "id": vaom.RESEARCH_PROFILE,
                "version": "0.2",
                "requiredCapabilities": ["https://w3id.org/modavis/vao/vocab/capability/paradata"],
            },
            {
                "id": vaom.ORGREC_PROFILE,
                "version": "0.2",
                "requiredCapabilities": ["https://w3id.org/modavis/vao/vocab/capability/audio"],
            },
        ])
        incomplete_orgrec["conformsTo"].extend([vaom.RESEARCH_PROFILE, vaom.ORGREC_PROFILE])
        incomplete_orgrec["paradata"] = [{
            "id": "urn:uuid:00000000-0000-4000-8000-000000000020",
            "activityType": "https://w3id.org/modavis/ontology/provenance#PackagingActivity",
            "startedAt": "2026-08-14T00:00:00Z",
            "software": {"name": "fixture", "version": "0.1.0"},
            "inputIds": [],
            "outputIds": [],
            "parameters": {},
        }]
        require_invalid(vaom.validate_manifest(incomplete_orgrec), "project.json", "incomplete OrgRec profile")

        incomplete_playable = copy.deepcopy(manifest)
        incomplete_playable["profiles"].append({
            "id": vaom.PLAYABLE_PROFILE,
            "version": "0.2",
            "requiredCapabilities": ["https://w3id.org/modavis/vao/vocab/capability/interaction"],
        })
        incomplete_playable["conformsTo"].append(vaom.PLAYABLE_PROFILE)
        require_invalid(vaom.validate_manifest(incomplete_playable), "interaction entity", "incomplete playable profile")

        incomplete_spatial = copy.deepcopy(manifest)
        incomplete_spatial["profiles"].append({
            "id": vaom.SPATIAL_PROFILE,
            "version": "0.2",
            "requiredCapabilities": ["https://w3id.org/modavis/vao/vocab/capability/spatial"],
        })
        incomplete_spatial["conformsTo"].append(vaom.SPATIAL_PROFILE)
        require_invalid(vaom.validate_manifest(incomplete_spatial), "top-level acoustics", "incomplete spatial profile")

        missing_experience = copy.deepcopy(experiential_manifest)
        missing_experience["entities"] = [
            entity for entity in missing_experience["entities"]
            if entity.get("properties", {}).get(vaom.VAO_ONTOLOGY + "experienceCapability")
            != vaom.GENERIC_MODEL_VIEWING
        ]
        require_invalid(
            vaom.validate_manifest(missing_experience),
            "no matching experience entity",
            "experiential capability without experience",
        )

        missing_experiential_dependency = copy.deepcopy(experiential_manifest)
        missing_experiential_dependency["profiles"] = [
            profile for profile in missing_experiential_dependency["profiles"]
            if profile.get("id") != vaom.SPATIAL_PROFILE
        ]
        missing_experiential_dependency["conformsTo"].remove(vaom.SPATIAL_PROFILE)
        require_invalid(
            vaom.validate_manifest(missing_experiential_dependency),
            "requires the spatial profile",
            "experiential capability without spatial dependency",
        )

        malformed_model = copy.deepcopy(experiential_manifest)
        del malformed_model["assets"][0]["properties"][vaom.VAO_ONTOLOGY + "physicalDimensions"]
        require_invalid(
            vaom.validate_manifest(malformed_model),
            "physical dimensions",
            "experiential model without dimensions",
        )

        incomplete_synchronization = copy.deepcopy(experiential_manifest)
        incomplete_synchronization["relations"] = [
            relation for relation in incomplete_synchronization["relations"]
            if relation.get("predicate") != vaom.VAO_ONTOLOGY + "drivesAnimation"
        ]
        require_invalid(
            vaom.validate_manifest(incomplete_synchronization),
            "drivesAnimation",
            "synchronized performance without animation",
        )

        invalid_target = copy.deepcopy(experiential_manifest)
        invalid_target["assets"][2]["roles"].remove(vaom.IMAGE_TARGET)
        require_invalid(
            vaom.validate_manifest(invalid_target),
            "image target asset",
            "image-target AR without target role",
        )

        invalid_placement = copy.deepcopy(experiential_manifest)
        surface = next(
            entity for entity in invalid_placement["entities"]
            if entity.get("properties", {}).get(vaom.VAO_ONTOLOGY + "experienceCapability")
            == vaom.SURFACE_PLACEMENT_AR
        )
        surface["properties"][vaom.VAO_ONTOLOGY + "placementPolicy"]["surfaceAlignment"] = "ceiling"
        require_invalid(
            vaom.validate_manifest(invalid_placement),
            "placementPolicy",
            "surface AR with invalid placement policy",
        )

        incomplete_listening = copy.deepcopy(experiential_manifest)
        incomplete_listening["relations"] = [
            relation for relation in incomplete_listening["relations"]
            if not (
                relation.get("subjectId") == "urn:vao:fixture:experiential:listening-point"
                and relation.get("predicate") == vaom.VAO_ONTOLOGY + "usesMedia"
            )
        ]
        require_invalid(
            vaom.validate_manifest(incomplete_listening),
            "spatial-listening audio asset",
            "listening point without media",
        )

        empty_offline_group = copy.deepcopy(experiential_manifest)
        empty_offline_group["relations"] = [
            relation for relation in empty_offline_group["relations"]
            if relation.get("predicate") != vaom.VAO_ONTOLOGY + "includesAsset"
        ]
        require_invalid(
            vaom.validate_manifest(empty_offline_group),
            "includes no assets",
            "offline group without assets",
        )

        executable_media_action = copy.deepcopy(experiential_manifest)
        media_interaction = next(
            entity for entity in executable_media_action["entities"]
            if entity.get("id") == "urn:vao:fixture:experiential:media-interaction"
        )
        media_interaction["properties"][vaom.VAO_ONTOLOGY + "actionSequence"][2]["action"] = "execute"
        require_invalid(
            vaom.validate_manifest(executable_media_action),
            "prohibited or invalid action",
            "replaceable media executable action",
        )

        invalid_sample_key_range = copy.deepcopy(experiential_manifest)
        sample_parameters = next(
            entity for entity in invalid_sample_key_range["entities"]
            if "https://w3id.org/modavis/ontology/audio#SamplePlaybackParameters" in entity.get("types", [])
        )
        sample_parameters["properties"][vaom.MODAVIS_AUDIO + "minimumKeyNumber"] = 70
        require_invalid(
            vaom.validate_manifest(invalid_sample_key_range),
            "invalid key range",
            "sample mapping with root outside key range",
        )

        duplicate_tuning_key = copy.deepcopy(experiential_manifest)
        tuning_map = next(
            entity for entity in duplicate_tuning_key["entities"]
            if vaom.TUNING_MAP_TYPE in entity.get("types", [])
        )
        entries = tuning_map["properties"][vaom.MODAVIS_AUDIO + "tuningEntries"]
        entries.append(copy.deepcopy(entries[0]))
        require_invalid(
            vaom.validate_manifest(duplicate_tuning_key),
            "invalid or duplicate entry",
            "tuning map with duplicate key",
        )

        unlinked_tuning_map = copy.deepcopy(experiential_manifest)
        unlinked_tuning_map["relations"] = [
            relation for relation in unlinked_tuning_map["relations"]
            if relation.get("predicate") not in {
                vaom.MODAVIS_AUDIO + "hasTuningMap",
                vaom.MODAVIS_AUDIO + "usesTuningMap",
            }
        ]
        require_invalid(
            vaom.validate_manifest(unlinked_tuning_map),
            "not linked to an instrument or interaction",
            "floating tuning map",
        )

        unbound_extraction_region = copy.deepcopy(experiential_manifest)
        unbound_extraction_region["relations"] = [
            relation for relation in unbound_extraction_region["relations"]
            if relation.get("predicate") != vaom.MODAVIS_AUDIO + "appliesToSignal"
        ]
        require_invalid(
            vaom.validate_manifest(unbound_extraction_region),
            "does not resolve its fixed source audio",
            "extraction region without source binding",
        )

        invalid_exact_frame_clock = copy.deepcopy(experiential_manifest)
        del invalid_exact_frame_clock["analyses"][0]["observations"][0]["timeRange"]["clockAssetId"]
        require_invalid(
            vaom.validate_manifest(invalid_exact_frame_clock),
            "invalid exact-frame clock",
            "observation with incomplete exact-frame clock",
        )

        obsolete_centi_unit = copy.deepcopy(experiential_manifest)
        obsolete_centi_unit["analyses"][0]["observations"][0]["unit"] = "http://qudt.org/vocab/unit/Centi"
        require_invalid(
            vaom.validate_manifest(obsolete_centi_unit),
            "not a cent unit",
            "observation using invalid QUDT Centi IRI",
        )

        cyclic_frames = copy.deepcopy(acoustic_manifest)
        frame = cyclic_frames["acoustics"]["coordinateFrames"][0]
        frame["parentFrameId"] = frame["id"]
        frame["transformToParent"] = [
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1,
        ]
        require_invalid(vaom.validate_manifest(cyclic_frames), "contains a cycle", "cyclic coordinate frames")

        invalid_quaternion = copy.deepcopy(acoustic_manifest)
        invalid_quaternion["acoustics"]["poses"][0]["orientationXYZW"] = [0, 0, 0, 0.5]
        require_invalid(vaom.validate_manifest(invalid_quaternion), "normalized XYZW", "unnormalized pose")

        measured_without_method = copy.deepcopy(acoustic_manifest)
        measured_without_method["paradata"][0]["method"]["methodType"] = "simulation"
        require_invalid(
            vaom.validate_manifest(measured_without_method),
            "measurement/deconvolution method paradata",
            "measured response without measurement method",
        )

        sofa_with_wrong_asset = copy.deepcopy(acoustic_manifest)
        sofa_with_wrong_asset["assets"][1]["path"] = "payload/acoustics/room.wav"
        require_invalid(vaom.validate_manifest(sofa_with_wrong_asset), ".sofa asset", "SOFA declaration on WAVE path")

        misaligned_metrics = copy.deepcopy(acoustic_manifest)
        misaligned_metrics["acoustics"]["metricSets"][0]["metrics"][0]["values"].append(1.3)
        require_invalid(vaom.validate_manifest(misaligned_metrics), "align with its frequency axis", "metric band mismatch")

        missing_runtime_fallback = copy.deepcopy(acoustic_manifest)
        missing_runtime_fallback["acoustics"]["renderConfigurations"][0]["fallbackIds"] = []
        require_invalid(
            vaom.validate_manifest(missing_runtime_fallback),
            "fallback policy without a fallback",
            "runtime fallback policy without resource",
        )

        incomplete_neural_field = copy.deepcopy(acoustic_manifest)
        incomplete_neural_field["acoustics"]["responseSets"][0]["representationStatus"] = "learned"
        incomplete_neural_field["acoustics"]["responseSets"][0]["interpolation"] = {
            "method": "neural-field",
            "domain": "urn:vao:fixture:acoustic-room:space",
            "outsideDomainPolicy": "fallback",
        }
        require_invalid(
            vaom.validate_manifest(incomplete_neural_field),
            "requires modelAssetId",
            "neural field without model lineage",
        )

        misplaced_acoustic_capabilities = copy.deepcopy(acoustic_manifest)
        misplaced_profile = next(
            profile for profile in misplaced_acoustic_capabilities["profiles"]
            if profile["id"] == vaom.ACOUSTICS_PROFILE
        )
        moved_capabilities = list(misplaced_profile["requiredCapabilities"])
        misplaced_profile["requiredCapabilities"] = []
        next(
            profile for profile in misplaced_acoustic_capabilities["profiles"]
            if profile["id"] == vaom.CORE_PROFILE
        )["requiredCapabilities"].extend(moved_capabilities)
        require_invalid(
            vaom.validate_manifest(misplaced_acoustic_capabilities),
            "standard acoustic capability",
            "acoustic capabilities declared under the wrong profile",
        )

        incomplete_building_metric = copy.deepcopy(acoustic_manifest)
        acoustics_profile = next(
            profile for profile in incomplete_building_metric["profiles"]
            if profile["id"] == vaom.ACOUSTICS_PROFILE
        )
        acoustics_profile["requiredCapabilities"].append(vaom.BUILDING_ACOUSTIC_PERFORMANCE)
        require_invalid(
            vaom.validate_manifest(incomplete_building_metric),
            "source room, receiving room, and separating element",
            "building metric without transmission pair",
        )

        incomplete_tracked_sources = copy.deepcopy(acoustic_manifest)
        next(
            profile for profile in incomplete_tracked_sources["profiles"]
            if profile["id"] == vaom.ACOUSTICS_PROFILE
        )["requiredCapabilities"].append(vaom.TRACKED_SOURCES)
        require_invalid(
            vaom.validate_manifest(incomplete_tracked_sources),
            "source-tracking feature",
            "tracked-sources capability without source tracking inputs",
        )

        misaligned_material = copy.deepcopy(acoustic_manifest)
        misaligned_material["entities"].append({
            "id": "urn:vao:fixture:acoustic-room:material",
            "kind": "material",
            "types": ["https://w3id.org/modavis/vao/ontology#AcousticMaterial"],
            "labels": {"en": "Fixture material"},
            "properties": {},
        })
        misaligned_material["acoustics"]["materialModels"].append({
            "id": "urn:vao:fixture:acoustic-room:material-model",
            "materialEntityId": "urn:vao:fixture:acoustic-room:material",
            "bandAxis": {"scale": "octave", "centerFrequenciesHz": [125, 250]},
            "absorption": [0.2],
            "representationStatus": "measured",
            "generatedById": "urn:vao:fixture:acoustic-room:activity:measurement",
        })
        require_invalid(
            vaom.validate_manifest(misaligned_material),
            "absorption length",
            "material coefficient band mismatch",
        )

        incomplete_preservation = copy.deepcopy(manifest)
        incomplete_preservation["profiles"].append({
            "id": vaom.PRESERVATION_PROFILE,
            "version": "0.2",
            "requiredCapabilities": ["https://w3id.org/modavis/vao/vocab/capability/preservation"],
        })
        incomplete_preservation["conformsTo"].append(vaom.PRESERVATION_PROFILE)
        del incomplete_preservation["assets"][0]["createdAt"]
        require_invalid(vaom.validate_manifest(incomplete_preservation), "createdAt", "incomplete preservation profile")

        traversal = root / "archive-traversal.vao"
        with zipfile.ZipFile(traversal, "x", compression=zipfile.ZIP_STORED, allowZip64=True) as archive_file:
            archive_file.writestr(vaom.zip_info("mimetype"), vaom.MIMETYPE.encode("utf-8"))
            archive_file.writestr(vaom.zip_info(vaom.MANIFEST_NAME), vaom.json_bytes(manifest))
            archive_file.writestr(vaom.zip_info("payload/../escape.txt"), b"escape\n")
        require_invalid(vaom.validate_archive(traversal), "unsafe archive path", "archive traversal")

        result = {
            "suite": "VAO 0.2 conformance",
            "formatVersion": vaom.FORMAT_VERSION,
            "positiveFixture": str(FIXTURE.relative_to(ROOT)),
            "positiveAssetCount": packed["assetCount"],
            "positiveVerifiedBytes": packed["verifiedBytes"],
            "playableFixture": str(PLAYABLE_FIXTURE.relative_to(ROOT)),
            "experientialFixture": str(EXPERIENTIAL_FIXTURE.relative_to(ROOT)),
            "acousticFixture": str(ACOUSTIC_FIXTURE.relative_to(ROOT)),
            "readerCompatibleFormatVersions": ["0.2.0", "0.2.1", "0.2.7"],
            "migrationCases": 1,
            "negativeCases": NEGATIVE_CASES,
            "status": "PASS",
        }
        print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
