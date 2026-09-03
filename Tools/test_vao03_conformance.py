#!/usr/bin/env python3
"""Positive, negative, migration, carrier, acoustic, and interaction tests for VAO 0.3.3."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import shutil
import tempfile

import vao03
import vaom


ROOT = Path(__file__).resolve().parent.parent
FIXTURE = ROOT / "Fixtures" / "VAO03" / "valid" / "embedded-private"
ACOUSTIC_FIXTURE = ROOT / "Fixtures" / "VAO03" / "valid" / "acousticrooms-scene"
SOURCE_02 = ROOT / "Fixtures" / "VAO" / "valid" / "minimal-playable-string-instrument"
ACOUSTIC_SOURCE_02 = ROOT / "Fixtures" / "VAO" / "valid" / "minimal-acoustic-room"
SAMPLED_SOURCE_02 = ROOT / "Fixtures" / "VAO" / "valid" / "minimal-experiential-instrument"
DESCRIPTORS = ROOT / "Fixtures" / "VAO03" / "descriptors"
KINOORGEL_FIXTURE = DESCRIPTORS / "kinoorgel-interaction.example.json"


def manifest_fixture() -> dict:
    return json.loads((FIXTURE / vao03.MANIFEST_NAME).read_text(encoding="utf-8"))


def acoustic_manifest_fixture() -> dict:
    return json.loads((ACOUSTIC_FIXTURE / vao03.MANIFEST_NAME).read_text(encoding="utf-8"))


def playable_manifest_fixture() -> dict:
    value = manifest_fixture()
    realization = value["realizations"][0]
    realization["mediaType"] = "audio/wav"
    realization["technicalMetadata"] = {
        "kind": "audio", "sampleRate": 48000, "sampleFormat": "signed-integer",
        "bitDepth": 24, "channelCount": 2, "frameCount": 100,
        "channelLabels": ["left", "right"], "audioContainer": "WAVE",
    }
    value["conformsTo"].append(vao03.PLAYABLE_PROFILE)
    interaction_id = "urn:uuid:03000000-0000-4000-8000-000000000100"
    ontology = "https://w3id.org/modavis/vao/ontology#"
    value["entities"].append({
        "id": interaction_id,
        "kind": "interaction",
        "types": [ontology + "Interaction"],
        "labels": {"en": "Play note"},
        "properties": {
            ontology + "interactionType": "https://w3id.org/modavis/vao/vocab/interaction/note-on",
            ontology + "controlProtocol": "host-note-gate",
            ontology + "controlDomain": "MIDI key and velocity",
            ontology + "timingPolicy": "note-on/note-off",
        },
    })
    value["relations"].append({
        "id": "urn:uuid:03000000-0000-4000-8000-000000000099",
        "subjectId": interaction_id,
        "predicate": ontology + "activates",
        "objectId": value["primaryEntityId"],
        "status": "asserted",
    })
    value["profiles"].append({
        "id": vao03.PLAYABLE_PROFILE,
        "version": "0.3",
        "requiredCapabilities": [
            vao03.INTERACTION, vao03.SAMPLED_INSTRUMENT_PLAYBACK, vao03.SAMPLE_LOOPING,
            vao03.RECORDED_RELEASE, vao03.SOURCE_SAMPLER_SEMANTICS,
        ],
    })
    realization_id = realization["id"]
    loop_region = "urn:uuid:03000000-0000-4000-8000-000000000101"
    release_region = "urn:uuid:03000000-0000-4000-8000-000000000102"
    loop_id = "urn:uuid:03000000-0000-4000-8000-000000000103"
    note_on = "urn:uuid:03000000-0000-4000-8000-000000000104"
    note_off = "urn:uuid:03000000-0000-4000-8000-000000000105"
    value["playable"] = {
        "signalRegions": [
            {"id": loop_region, "realizationId": realization_id, "role": "sustain-loop", "startFrameInclusive": 10, "endFrameExclusive": 21, "status": "asserted", "source": "embedded-metadata"},
            {"id": release_region, "realizationId": realization_id, "role": "release", "startFrameInclusive": 60, "endFrameExclusive": 100, "status": "asserted", "source": "native-definition"},
        ],
        "loopPointSets": [
            {"id": loop_id, "regionIds": [loop_region], "mode": "forward", "selectionPolicy": "ordered", "exitPolicy": "recorded-release", "crossfadeFrames": 4, "status": "asserted", "source": "embedded-metadata"},
        ],
        "tuningMaps": [],
        "perspectiveGroups": [],
        "sampleVariants": [
            {"id": note_on, "realizationId": realization_id, "trigger": "note-on", "signalRole": "attack-sustain", "loopPointSetIds": [loop_id], "sourceLocator": "[Rank001].Pipe001", "status": "asserted", "source": "native-definition"},
            {"id": note_off, "realizationId": realization_id, "trigger": "note-off", "signalRole": "release", "signalRegionIds": [release_region], "sourceLocator": "[Rank001].Pipe001Release001", "status": "asserted", "source": "native-definition"},
        ],
        "sampleMappings": [
            {"id": "urn:uuid:03000000-0000-4000-8000-000000000106", "instrumentEntityId": value["primaryEntityId"], "keyRange": {"minimum": 36, "maximum": 36}, "velocityRange": {"minimum": 1, "maximum": 127}, "variantIds": [note_on, note_off], "selectionPolicy": "single", "noteOffPolicy": "recorded-release", "sourceLocator": "[Rank001].Pipe001", "status": "asserted", "source": "native-definition"},
        ],
    }
    return value


def expect_manifest_failure(name: str, mutate) -> tuple[str, bool, str]:
    value = manifest_fixture()
    mutate(value)
    report = vao03.validate_manifest(value)
    return name, not report["valid"], report["errors"][0] if report["errors"] else "unexpectedly valid"


def add_second_group(value: dict, *, dependency: bool = False, fallback: bool = False) -> None:
    group = copy.deepcopy(value["assetGroups"][0])
    group["id"] = "urn:uuid:03000000-0000-4000-8000-000000000031"
    group["labels"] = {"en": "Second group"}
    if dependency:
        value["assetGroups"][0]["dependsOnGroupIds"] = [group["id"]]
        group["dependsOnGroupIds"] = [value["assetGroups"][0]["id"]]
    if fallback:
        value["assetGroups"][0]["fallbackGroupId"] = group["id"]
        group["fallbackGroupId"] = value["assetGroups"][0]["id"]
    value["assetGroups"].append(group)


def manifest_cases() -> list[tuple[str, bool, str]]:
    cases = [
        expect_manifest_failure("wrong schema IRI", lambda m: m.__setitem__("$schema", "https://example.org/wrong")),
        expect_manifest_failure("unknown root field", lambda m: m.__setitem__("instanceId", "urn:uuid:bad")),
        expect_manifest_failure("0.2 profile reuse", lambda m: m["profiles"][0].__setitem__("id", "https://w3id.org/modavis/vao/profile/core/0.2")),
        expect_manifest_failure("missing Core profile", lambda m: m["profiles"].pop(0)),
        expect_manifest_failure("missing Dynamic profile", lambda m: m["profiles"].pop()),
        expect_manifest_failure("unjustified Zenodo profile", lambda m: m["profiles"].append({"id": vao03.ZENODO_PROFILE, "version": "0.3", "requiredCapabilities": []})),
        expect_manifest_failure("duplicate registry id", lambda m: m["assetGroups"][0].__setitem__("id", m["logicalAssets"][0]["id"])),
        expect_manifest_failure("unresolved focus entity", lambda m: m["focusEntityIds"].append("urn:uuid:missing")),
        expect_manifest_failure("logical asset inverse", lambda m: m["realizations"][0].__setitem__("assetId", "urn:uuid:missing")),
        expect_manifest_failure("unresolved distribution", lambda m: m["realizations"][0]["distributionIds"].append("urn:uuid:missing")),
        expect_manifest_failure("unresolved rights", lambda m: m["realizations"][0].__setitem__("rightsIds", ["urn:uuid:missing"])),
        expect_manifest_failure("rights coverage gap", lambda m: m["rights"][0]["appliesToIds"].remove(m["realizations"][0]["id"])),
        expect_manifest_failure("incorrect group total", lambda m: m["assetGroups"][0].__setitem__("totalByteSize", 70)),
        expect_manifest_failure("dependency cycle", lambda m: add_second_group(m, dependency=True)),
        expect_manifest_failure("fallback cycle", lambda m: add_second_group(m, fallback=True)),
        expect_manifest_failure("empty bootstrap group", lambda m: (m["assetGroups"][0].__setitem__("realizationIds", []), m["assetGroups"][0].__setitem__("totalByteSize", 0))),
        expect_manifest_failure("embedded/materializable overlap", lambda m: m["materializableProfiles"].append({"id": vao03.CORE_PROFILE, "version": "0.3", "requiredCapabilities": [], "groupIds": [m["assetGroups"][0]["id"]]})),
    ]

    def bad_ambisonics(m: dict) -> None:
        m["realizations"][0]["technicalMetadata"] = {"kind": "audio", "sampleRate": 48000, "channelCount": 15, "ambisonicsOrder": 3, "ambisonicsDimensionality": "3D", "ambisonicsChannelOrder": "ACN", "ambisonicsNormalization": "SN3D"}
    cases.append(expect_manifest_failure("Ambisonics channel mismatch", bad_ambisonics))

    def concept_as_exact(m: dict) -> None:
        binding_id = "urn:uuid:zenodo-binding"
        distribution_id = "urn:uuid:zenodo-distribution"
        m["repositoryBindings"] = [{"id": binding_id, "repositoryType": "https://w3id.org/modavis/vao/repository/zenodo", "instance": "https://sandbox.zenodo.org", "apiProfile": "https://w3id.org/modavis/vao/repository/zenodo/records-api/1", "resolutionPolicy": "version-pid-record-file"}]
        doi = "https://doi.org/10.5072/zenodo.1234"
        m["distributions"] = [{"id": distribution_id, "kind": "repository", "repositoryBindingId": binding_id, "persistentIdentifier": doi, "conceptIdentifier": doi, "recordIdentifier": "1234", "fileIdentifier": "asset.bin", "access": "public"}]
        m["realizations"][0]["distributionIds"] = [distribution_id]
        m["profiles"].append({"id": vao03.ZENODO_PROFILE, "version": "0.3", "requiredCapabilities": []})
        m["conformsTo"].append(vao03.ZENODO_PROFILE)
    cases.append(expect_manifest_failure("concept DOI used for acquisition", concept_as_exact))
    return cases


def carrier_case(name: str, mutate) -> tuple[str, bool, str]:
    with tempfile.TemporaryDirectory() as temporary:
        workspace = Path(temporary) / "fixture"
        shutil.copytree(FIXTURE, workspace)
        mutate(workspace)
        report = vao03.validate_workspace(workspace)
        return name, not report["valid"], report["errors"][0] if report["errors"] else "unexpectedly valid"


def carrier_cases() -> list[tuple[str, bool, str]]:
    def edit_carrier(workspace: Path, operation) -> None:
        path = workspace / vao03.CARRIER_NAME
        value = json.loads(path.read_text(encoding="utf-8"))
        operation(value)
        path.write_bytes(vao03.json_bytes(value))

    return [
        carrier_case("manifest digest mismatch", lambda p: edit_carrier(p, lambda c: c.__setitem__("manifestSHA256", "0" * 64))),
        carrier_case("manifest size mismatch", lambda p: edit_carrier(p, lambda c: c.__setitem__("manifestByteSize", 1))),
        carrier_case("carrier release mismatch", lambda p: edit_carrier(p, lambda c: c.__setitem__("releaseId", "urn:uuid:wrong"))),
        carrier_case("corrupt embedded bytes", lambda p: (p / "payload/evidence/source.txt").write_text("corrupt\n", encoding="utf-8")),
        carrier_case("unindexed payload", lambda p: (p / "payload/evidence/hidden.txt").write_text("hidden\n", encoding="utf-8")),
        carrier_case("unknown mapped realization", lambda p: edit_carrier(p, lambda c: c["embeddedRealizations"][0].__setitem__("realizationId", "urn:uuid:missing"))),
        carrier_case("unsafe mapped path", lambda p: edit_carrier(p, lambda c: c["embeddedRealizations"][0].__setitem__("path", "payload/../escape"))),
        carrier_case("incomplete marked group", lambda p: edit_carrier(p, lambda c: c.__setitem__("embeddedRealizations", []))),
        carrier_case("false preservation closure", lambda p: edit_carrier(p, lambda c: (c.__setitem__("carrierMode", "preservation-closure"), c.__setitem__("completeGroupIds", [])))),
        carrier_case("workspace mimetype bytes", lambda p: (p / "mimetype").write_text(vao03.MIMETYPE + "\n", encoding="utf-8")),
    ]


def acoustic_cases() -> list[tuple[str, bool, str]]:
    def expect(name: str, mutate) -> tuple[str, bool, str]:
        value = acoustic_manifest_fixture()
        mutate(value)
        report = vao03.validate_manifest(value)
        return name, not report["valid"], report["errors"][0] if report["errors"] else "unexpectedly valid"

    def profile(value: dict, profile_id: str) -> dict:
        return next(record for record in value["profiles"] if record["id"] == profile_id)

    def unnormalized_quaternion(value: dict) -> None:
        value["acoustics"]["poses"][0]["orientationXYZW"] = [0, 0, 0, 0.5]

    def cycle_frames(value: dict) -> None:
        frames = value["acoustics"]["coordinateFrames"]
        frames[0]["parentFrameId"] = frames[1]["id"]
        frames[0]["transformToParent"] = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]

    def pose_subject_mismatch(value: dict) -> None:
        value["acoustics"]["poses"][0]["subjectId"] = "urn:vao:fixture:acousticrooms:receiver:11"

    def wrong_measurement_mapping(value: dict) -> None:
        value["realizations"][2]["technicalMetadata"]["impulseResponse"]["measurementMappings"][0]["measurementId"] = "urn:vao:missing"

    def channel_out_of_range(value: dict) -> None:
        value["realizations"][2]["technicalMetadata"]["impulseResponse"]["measurementMappings"][0]["channelIndices"] = [1]

    def response_status_mismatch(value: dict) -> None:
        value["acoustics"]["responseSets"][0]["representationStatus"] = "measured"

    def unregistered_geometry(value: dict) -> None:
        frames = value["acoustics"]["coordinateFrames"]
        frames[1].pop("parentFrameId")
        frames[1].pop("transformToParent")
        value["realizations"][0]["technicalMetadata"]["coordinateFrameId"] = frames[1]["id"]

    def missing_spatial_profile(value: dict) -> None:
        value["profiles"] = [record for record in value["profiles"] if record["id"] != vao03.SPATIAL_PROFILE]

    def false_measured_capability(value: dict) -> None:
        profile(value, vao03.ACOUSTICS_PROFILE)["requiredCapabilities"].append(vao03.MEASURED_IMPULSE_RESPONSE)

    def duplicate_acoustic_id(value: dict) -> None:
        value["acoustics"]["measurements"][0]["id"] = value["acoustics"]["poses"][0]["id"]

    return [
        expect("acoustic pose quaternion normalization", unnormalized_quaternion),
        expect("coordinate-frame cycle", cycle_frames),
        expect("measurement pose/subject agreement", pose_subject_mismatch),
        expect("RIR measurement mapping closure", wrong_measurement_mapping),
        expect("RIR channel mapping bounds", channel_out_of_range),
        expect("response realization status agreement", response_status_mismatch),
        expect("visual/acoustic frame registration", unregistered_geometry),
        expect("Acoustics profile requires Spatial", missing_spatial_profile),
        expect("measured capability needs measured data", false_measured_capability),
        expect("acoustic registry identifiers are global", duplicate_acoustic_id),
    ]


def playable_cases() -> list[tuple[str, bool, str]]:
    value = playable_manifest_fixture()
    positive = vao03.validate_manifest(value)
    outcomes = [("playable source loops and recorded release", positive["valid"], positive["errors"][0] if positive["errors"] else "valid")]

    interaction_only = playable_manifest_fixture()
    del interaction_only["playable"]
    interaction_only["profiles"][-1]["requiredCapabilities"] = [vao03.INTERACTION]
    report = vao03.validate_manifest(interaction_only)
    outcomes.append(("playable interaction without sample implementation", report["valid"], report["errors"][0] if report["errors"] else "valid"))

    missing_sample_contract = playable_manifest_fixture()
    del missing_sample_contract["playable"]
    report = vao03.validate_manifest(missing_sample_contract)
    outcomes.append(("sampled playback requires playable registries", not report["valid"] and any("closed top-level playable object" in error for error in report["errors"]), report["errors"][0] if report["errors"] else "unexpectedly valid"))

    out_of_bounds = playable_manifest_fixture()
    out_of_bounds["playable"]["signalRegions"][0]["endFrameExclusive"] = 101
    report = vao03.validate_manifest(out_of_bounds)
    outcomes.append(("playable loop bounds", not report["valid"] and any("frameCount" in error for error in report["errors"]), report["errors"][0] if report["errors"] else "unexpectedly valid"))

    laundering = playable_manifest_fixture()
    loop = laundering["playable"]["loopPointSets"][0]
    loop["source"] = "algorithmic"
    loop["status"] = "asserted"
    report = vao03.validate_manifest(laundering)
    outcomes.append(("playable evidence-state laundering", not report["valid"] and any("algorithmic output as asserted" in error for error in report["errors"]), report["errors"][0] if report["errors"] else "unexpectedly valid"))

    false_release = playable_manifest_fixture()
    false_release["playable"]["sampleVariants"].pop()
    false_release["playable"]["sampleMappings"][0]["variantIds"].pop()
    report = vao03.validate_manifest(false_release)
    outcomes.append(("false recorded-release claim", not report["valid"] and any("claims recorded-release" in error for error in report["errors"]), report["errors"][0] if report["errors"] else "unexpectedly valid"))

    detached = playable_manifest_fixture()
    detached["profiles"][-1]["requiredCapabilities"].extend([vao03.TUNING_MAP, vao03.MULTI_PERSPECTIVE_SAMPLING])
    detached["playable"]["signalRegions"][1]["status"] = "rejected"
    next(entity for entity in detached["entities"] if entity["id"] == detached["primaryEntityId"])["kind"] = "component"
    report = vao03.validate_manifest(detached)
    expected = ("unreviewed inferred region", "does not identify an instrument", "usable sample mapping bound to a tuning map", "at least two perspective groups")
    outcomes.append(("playable capability and evidence closure", not report["valid"] and all(any(fragment in error for error in report["errors"]) for fragment in expected), report["errors"][0] if report["errors"] else "unexpectedly valid"))
    return outcomes


def complex_interaction_cases() -> list[tuple[str, bool, str]]:
    def fixture() -> dict:
        return json.loads(KINOORGEL_FIXTURE.read_text(encoding="utf-8"))

    def expect(name: str, mutate, fragment: str) -> tuple[str, bool, str]:
        value = fixture()
        mutate(value)
        report = vao03.validate_manifest(value)
        passed = not report["valid"] and any(fragment in error for error in report["errors"])
        return name, passed, report["errors"][0] if report["errors"] else "unexpectedly valid"

    positive = vao03.validate_manifest(fixture())
    outcomes = [(
        "Kinoorgel compositional interaction fixture",
        positive["valid"], positive["errors"][0] if positive["errors"] else "valid",
    )]
    outcomes.append(expect(
        "complex capability requires interaction model",
        lambda value: value.pop("interactionModel"),
        "require the closed top-level interactionModel",
    ))
    outcomes.append(expect(
        "MIDI bindings require explicit numbering bases",
        lambda value: value["interactionModel"]["protocolBindings"][0].pop("channelNumberingBase"),
        "requires explicit channelNumberingBase",
    ))
    outcomes.append(expect(
        "interaction records cannot embed scripts",
        lambda value: value["interactionModel"]["transitions"][0].__setitem__("script", "run()"),
        "unknown property 'script'",
    ))
    outcomes.append(expect(
        "declarative action targets remain type-compatible",
        lambda value: value["interactionModel"]["processModels"][1]["actions"][0].__setitem__(
            "targetId", "urn:vao:fixture:kinoorgel:state:tibia-enabled"
        ),
        "unresolved or incompatible targetId",
    ))
    outcomes.append(expect(
        "velocity-insensitive mappings omit velocity ranges",
        lambda value: value["playable"]["sampleMappings"][0].__setitem__(
            "velocityRange", {"minimum": 1, "maximum": 127}
        ),
        "matches a prohibited shape",
    ))
    outcomes.append(expect(
        "unbounded repeating process is rejected",
        lambda value: value["interactionModel"]["processModels"][0].update({"terminationPolicy": "completed"}),
        "potentially unbounded",
    ))
    outcomes.append(expect(
        "compound actuation needs multiple operations",
        lambda value: value["interactionModel"]["processModels"][1].__setitem__(
            "actions", value["interactionModel"]["processModels"][1]["actions"][:1]
        ),
        "requires at least two actions",
    ))
    outcomes.append(expect(
        "timing bounds remain ordered",
        lambda value: value["interactionModel"]["timingConstraints"][0].update({"minimum": 200}),
        "inconsistent minimum/typical/maximum",
    ))
    outcomes.append(expect(
        "event alignment stays within audio frames",
        lambda value: value["captureDocumentation"]["eventAlignments"][0]["eventMappings"][0].update({"endFrameExclusive": 200000}),
        "exceeds audio frameCount",
    ))

    def routing_cycle(value: dict) -> None:
        value["interactionModel"]["routingRules"].append({
            "id": "urn:vao:fixture:kinoorgel:route:cycle",
            "sourceEntityId": "urn:vao:fixture:kinoorgel:rank:tibia",
            "targetEntityId": "urn:vao:fixture:kinoorgel:manual:great",
            "routingBehavior": "copies",
            "inputKeyMeaning": "sounding-key",
            "outputKeyMeaning": "played-key",
            "inputRange": {"minimum": 36, "maximum": 84},
            "keyTransform": {"kind": "identity"},
            "status": "asserted",
            "source": "authored",
        })
    outcomes.append(expect("coupler routing cycles are rejected", routing_cycle, "routing graph contains a cycle"))

    def derivation_cycle(value: dict) -> None:
        value["captureDocumentation"]["derivationMaps"].append({
            "id": "urn:vao:fixture:kinoorgel:derivation:cycle",
            "sourceRealizationId": "urn:vao:fixture:kinoorgel:realization:tibia:44100",
            "derivedRealizationId": "urn:vao:fixture:kinoorgel:realization:tibia:192000",
            "operations": [{"kind": "resample"}],
            "status": "asserted",
            "source": "authored",
        })
    outcomes.append(expect("capture derivation cycles are rejected", derivation_cycle, "derivation graph contains a cycle"))
    return outcomes


def unicode_carrier_case() -> tuple[str, bool, str]:
    manifest_data = (FIXTURE / vao03.MANIFEST_NAME).read_bytes()
    carrier_data = (FIXTURE / vao03.CARRIER_NAME).read_bytes()
    actual = "payload/evidence/source.txt"
    names = [actual, "payload/Caf\u00e9.wav", "payload/Cafe\u0301.wav"]
    source_digest, source_size = vao03.sha256_file(FIXTURE / actual)

    def reader(name: str) -> tuple[str, int]:
        return source_digest, source_size

    report = vao03.validate_carrier_parts(manifest_data, carrier_data, names, reader)
    passed = not report["valid"] and any("collide after NFC normalization" in error for error in report["errors"])
    return "Unicode-equivalent carrier paths collide", passed, report["errors"][0] if report["errors"] else "unexpectedly valid"


def publication_cases() -> list[tuple[str, bool, str]]:
    single_release = DESCRIPTORS / "release-single-record.example.json"
    single_metadata = DESCRIPTORS / "zenodo-metadata-single-record.example.json"
    family_release = DESCRIPTORS / "release-record-family.example.json"
    family_metadata = [
        DESCRIPTORS / "zenodo-metadata-family-root.example.json",
        DESCRIPTORS / "zenodo-metadata-family-model.example.json",
        DESCRIPTORS / "zenodo-metadata-family-audio.example.json",
    ]
    single = vao03.validate_publication_set(single_release, [single_metadata])
    family = vao03.validate_publication_set(family_release, family_metadata)
    outcomes = [
        ("single modular Zenodo record topology", single["valid"], single["errors"][0] if single["errors"] else "valid"),
        ("related Zenodo record family topology", family["valid"], family["errors"][0] if family["errors"] else "valid"),
    ]
    with tempfile.TemporaryDirectory() as temporary:
        temporary_path = Path(temporary)

        bad_single = json.loads(single_release.read_text(encoding="utf-8"))
        family_value = json.loads(family_release.read_text(encoding="utf-8"))
        bad_single["publication"]["familyMembers"] = [family_value["publication"]["familyMembers"][0]]
        bad_single_path = temporary_path / "bad-single.json"
        vao03.write_json(bad_single_path, bad_single)
        report = vao03.validate_release_descriptor(bad_single_path)
        outcomes.append(("single-record topology rejects family members", not report["valid"], report["errors"][0] if report["errors"] else "unexpectedly valid"))

        bad_exclusive = copy.deepcopy(family_value)
        bad_exclusive["publication"]["familyMembers"][0]["relationFromRoot"] = "requires"
        bad_exclusive_path = temporary_path / "bad-exclusive.json"
        vao03.write_json(bad_exclusive_path, bad_exclusive)
        report = vao03.validate_release_descriptor(bad_exclusive_path)
        outcomes.append(("exclusive family member requires hasPart/isPartOf", not report["valid"], report["errors"][0] if report["errors"] else "unexpectedly valid"))

        concept_as_version = copy.deepcopy(family_value)
        root = concept_as_version["publication"]["rootRecord"]
        root["versionPersistentIdentifier"] = root["conceptPersistentIdentifier"]
        concept_path = temporary_path / "concept-as-version.json"
        vao03.write_json(concept_path, concept_as_version)
        report = vao03.validate_release_descriptor(concept_path)
        outcomes.append(("publication descriptor rejects concept PID as exact PID", not report["valid"], report["errors"][0] if report["errors"] else "unexpectedly valid"))

        incomplete_root = json.loads(family_metadata[0].read_text(encoding="utf-8"))
        incomplete_root["metadata"]["related_identifiers"] = incomplete_root["metadata"]["related_identifiers"][1:]
        incomplete_root_path = temporary_path / "incomplete-root-metadata.json"
        vao03.write_json(incomplete_root_path, incomplete_root)
        report = vao03.validate_publication_set(family_release, [incomplete_root_path, *family_metadata[1:]])
        outcomes.append(("root metadata must project exact family relations", not report["valid"], report["errors"][0] if report["errors"] else "unexpectedly valid"))
    return outcomes


def main() -> int:
    outcomes: list[tuple[str, bool, str]] = []
    positive = vao03.validate_workspace(FIXTURE)
    outcomes.append(("repository-free embedded fixture", positive["valid"], positive["errors"][0] if positive["errors"] else "valid"))
    acoustic_positive = vao03.validate_workspace(ACOUSTIC_FIXTURE)
    outcomes.append(("CC BY visual-acoustic dataset fixture", acoustic_positive["valid"], acoustic_positive["errors"][0] if acoustic_positive["errors"] else "valid"))
    outcomes.extend(manifest_cases())
    outcomes.extend(acoustic_cases())
    outcomes.extend(playable_cases())
    outcomes.extend(complex_interaction_cases())
    outcomes.extend(carrier_cases())
    outcomes.append(unicode_carrier_case())
    outcomes.extend(publication_cases())
    with tempfile.TemporaryDirectory() as temporary:
        destination = Path(temporary) / "migrated"
        migration = vao03.migrate_02(SOURCE_02, destination)
        migrated = vao03.validate_workspace(destination)
        outcomes.append(("0.2 to 0.3 migration", migrated["valid"] and migration["sourceFormatVersion"] == "0.2.2", "valid" if migrated["valid"] else "; ".join(migrated["errors"][:2])))
        archive = Path(temporary) / "migrated.vao"
        vao03.pack_workspace(destination, archive)
        archived = vao03.validate_archive(archive)
        outcomes.append(("deterministic carrier pack/read", archived["valid"], "valid" if archived["valid"] else "; ".join(archived["errors"][:2])))
        receipt = Path(temporary) / "receipt.json"
        vao03.create_receipt(destination, receipt, "urn:uuid:03000000-0000-4000-8000-000000009999")
        receipt_report = vao03.validate_descriptor(receipt, vao03.RECEIPT_SCHEMA)
        outcomes.append(("materialization receipt", receipt_report["valid"], "valid" if receipt_report["valid"] else "; ".join(receipt_report["errors"][:2])))

        acoustic_destination = Path(temporary) / "acoustic-migration-needs-enrichment"
        try:
            vao03.migrate_02(ACOUSTIC_SOURCE_02, acoustic_destination)
            acoustic_boundary = False
            acoustic_detail = "unexpectedly migrated without producer enrichment"
        except vao03.VAO03Error as exc:
            acoustic_boundary = "producer enrichment" in str(exc) and not acoustic_destination.exists()
            acoustic_detail = str(exc)
        outcomes.append(("0.2 acoustic migration stops before inventing metadata", acoustic_boundary, acoustic_detail))

        sampled_destination = Path(temporary) / "sampled-migration-needs-enrichment"
        try:
            vao03.migrate_02(SAMPLED_SOURCE_02, sampled_destination)
            sampled_boundary = False
            sampled_detail = "unexpectedly migrated without producer enrichment"
        except vao03.VAO03Error as exc:
            sampled_boundary = "sampled-instrument migration requires producer enrichment" in str(exc) and not sampled_destination.exists()
            sampled_detail = str(exc)
        outcomes.append(("0.2 sampled migration stops before inventing mappings", sampled_boundary, sampled_detail))

    passed = sum(success for _, success, _ in outcomes)
    for name, success, detail in outcomes:
        print(f"{'PASS' if success else 'FAIL'} {name}: {detail}")
    print(json.dumps({"caseCount": len(outcomes), "passed": passed, "failed": len(outcomes) - passed}, sort_keys=True))
    return 0 if passed == len(outcomes) else 1


if __name__ == "__main__":
    raise SystemExit(main())
