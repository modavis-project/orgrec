#!/usr/bin/env python3
"""VAO 0.4.0 reference validator, carrier writer, and 0.3.3 migrator."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import sys
import tempfile
import unicodedata
import uuid
import zipfile
from typing import Any, Callable, Iterable

import vao03
from vao04_runtime import verify_trace


FORMAT_VERSION = "0.4.0"
MIMETYPE = vao03.MIMETYPE
MANIFEST_NAME = vao03.MANIFEST_NAME
CARRIER_NAME = vao03.CARRIER_NAME
BASE = f"https://w3id.org/modavis/vao/{FORMAT_VERSION}"
SCHEMA_URI = f"{BASE}/schema/manifest.json"
CONTEXT_URI = f"{BASE}/context.jsonld"
PROFILE_BASE = "https://w3id.org/modavis/vao/profile/"
CORE_PROFILE = PROFILE_BASE + f"core/{FORMAT_VERSION}"
DYNAMIC_PROFILE = PROFILE_BASE + f"dynamic-delivery/{FORMAT_VERSION}"
SCIENTIFIC_PROFILE = PROFILE_BASE + f"scientific/{FORMAT_VERSION}"
MULTIMODAL_PROFILE = PROFILE_BASE + f"multimodal/{FORMAT_VERSION}"
PHYSICAL_PROFILE = PROFILE_BASE + f"physical-instrument/{FORMAT_VERSION}"
RUNTIME_PROFILE = PROFILE_BASE + f"deterministic-runtime/{FORMAT_VERSION}"
SPATIAL_PROFILE = PROFILE_BASE + f"spatial/{FORMAT_VERSION}"
ACOUSTICS_PROFILE = PROFILE_BASE + f"acoustics/{FORMAT_VERSION}"
PLAYABLE_PROFILE = PROFILE_BASE + f"playable/{FORMAT_VERSION}"
ZENODO_PROFILE = PROFILE_BASE + f"repository/zenodo/{FORMAT_VERSION}"
CAPABILITY_BASE = "https://w3id.org/modavis/vao/vocab/capability/"
SCHEMA_DIR = Path(__file__).resolve().parent.parent / "Schemas"
MANIFEST_SCHEMA = SCHEMA_DIR / f"vao-manifest-{FORMAT_VERSION}.schema.json"
CARRIER_SCHEMA = SCHEMA_DIR / f"vao-carrier-{FORMAT_VERSION}.schema.json"
RELEASE_SCHEMA = SCHEMA_DIR / f"vao-release-{FORMAT_VERSION}.schema.json"
PACK_SCHEMA = SCHEMA_DIR / f"vao-pack-manifest-{FORMAT_VERSION}.schema.json"
RECEIPT_SCHEMA = SCHEMA_DIR / f"vao-materialization-receipt-{FORMAT_VERSION}.schema.json"
ZENODO_METADATA_SCHEMA = SCHEMA_DIR / f"vao-zenodo-metadata-{FORMAT_VERSION}.schema.json"


class VAO04Error(vao03.VAO03Error):
    pass


json_bytes = vao03.json_bytes
sha256_bytes = vao03.sha256_bytes
sha256_file = vao03.sha256_file
strict_json_bytes = vao03.strict_json_bytes
load_json = vao03.load_json
write_json = vao03.write_json
is_identifier = vao03.is_identifier
is_safe_path = vao03.is_safe_path
normalized_carrier_path = vao03.normalized_carrier_path


def _digest_bytes(algorithm: str, data: bytes) -> bytes:
    if algorithm == "sha256": return hashlib.sha256(data).digest()
    if algorithm == "sha512": return hashlib.sha512(data).digest()
    raise VAO04Error(f"Unsupported digest algorithm {algorithm!r}.")


def merkle_root(chunks: list[dict[str, Any]], algorithm: str) -> str:
    if not chunks: raise VAO04Error("Cannot calculate a Merkle root without chunks.")
    level = [_digest_bytes(algorithm, b"\x00" + bytes.fromhex(chunk["digest"]["value"])) for chunk in chunks]
    while len(level) > 1:
        if len(level) % 2: level.append(level[-1])
        level = [_digest_bytes(algorithm, b"\x01" + level[index] + level[index + 1]) for index in range(0, len(level), 2)]
    return level[0].hex()


def validate_chunk_stream(realization: dict[str, Any], stream: Any) -> list[str]:
    errors: list[str] = []
    chunking = realization.get("chunking")
    if not isinstance(chunking, dict) or not chunking.get("chunks"): return errors
    position = 0
    for chunk in sorted(chunking["chunks"], key=lambda item: item["index"]):
        if chunk["offset"] != position: break
        remaining = chunk["length"]; algorithm = chunk["digest"]["algorithm"]
        hasher = hashlib.sha256() if algorithm == "sha256" else hashlib.sha512()
        while remaining:
            block = stream.read(min(vao03.CHUNK, remaining))
            if not block: errors.append(f"Realization {realization['id']!r} ends inside chunk {chunk['index']}."); return errors
            hasher.update(block); remaining -= len(block); position += len(block)
        if hasher.hexdigest() != chunk["digest"]["value"]:
            errors.append(f"Realization {realization['id']!r} chunk {chunk['index']} fails its {algorithm} digest.")
    return errors


def schema_errors(value: Any, path: Path) -> list[str]:
    return vao03.schema_errors(value, path)


def _replace_profile(value: str) -> str:
    if value.startswith(PROFILE_BASE) and value.endswith(f"/{FORMAT_VERSION}"):
        return value[: -len(FORMAT_VERSION)] + "0.3"
    return value


def project_to_03(manifest: dict[str, Any]) -> dict[str, Any]:
    """Lossless-for-0.3-semantics internal projection used to retain mature checks."""
    value = copy.deepcopy(manifest)
    value["$schema"] = vao03.SCHEMA_URI
    value["@context"] = [vao03.CONTEXT_URI if item == CONTEXT_URI else item for item in value.get("@context", [])]
    value["formatVersion"] = vao03.FORMAT_VERSION
    value["conformsTo"] = [_replace_profile(item) for item in value.get("conformsTo", [])]
    for registry in ("profiles", "materializableProfiles"):
        for profile in value.get(registry, []):
            profile["id"] = _replace_profile(profile["id"])
            profile["version"] = "0.3"

    scientific = value.pop("scientific", {})
    value["paradata"] = [
        *scientific.get("agents", []), *scientific.get("activities", []),
        *scientific.get("observations", []), *scientific.get("calibrations", []),
        *scientific.get("protocols", []), *scientific.get("softwareEnvironments", []),
        *scientific.get("consents", []),
    ]
    value["analyses"] = [*scientific.get("analyses", []), *scientific.get("claims", []), *scientific.get("reviews", [])]
    for key in ("multimodal", "physicalSystem", "runtime", "discovery"):
        value.pop(key, None)

    allowed_technical = set(json.loads(vao03.MANIFEST_SCHEMA.read_text(encoding="utf-8"))["$defs"]["technicalMetadata"]["properties"])
    for realization in value.get("realizations", []):
        realization.pop("contentDigests", None)
        realization.pop("chunking", None)
        realization.pop("streamingIndexRealizationId", None)
        realization.pop("authenticityEnvelopeRealizationId", None)
        technical = realization.get("technicalMetadata", {})
        if technical.get("kind") not in {"audio", "geometry", "image", "document", "data", "software", "other"}:
            technical["kind"] = "data"
        for key in list(technical):
            if key not in allowed_technical:
                technical.pop(key)

    allowed_rights = set(json.loads(vao03.MANIFEST_SCHEMA.read_text(encoding="utf-8"))["$defs"]["rights"]["properties"])
    for record in value.get("rights", []):
        for key in list(record):
            if key not in allowed_rights:
                record.pop(key)
    integrity = value.get("integrity", {})
    integrity.pop("schemaBundleDigest", None)
    integrity.pop("signatureEnvelopeRealizationId", None)

    model = value.get("interactionModel")
    if isinstance(model, dict):
        model.pop("executionSemantics", None)
        model.pop("randomSources", None)
        allowed_protocol = set(json.loads(vao03.MANIFEST_SCHEMA.read_text(encoding="utf-8"))["$defs"]["protocolBinding"]["properties"])
        for binding in model.get("protocolBindings", []):
            for key in list(binding):
                if key not in allowed_protocol: binding.pop(key)
        for route in model.get("routingRules", []):
            delayed = route.pop("delayConstraintId", None)
            if delayed is not None and route.get("routingBehavior") in {"copies", "transposes"}:
                route["routingBehavior"] = "activates"
        for process in model.get("processModels", []):
            process.pop("randomSourceId", None)
            process.pop("probabilityDistribution", None)
        for transfer in model.get("transferFunctions", []):
            for key in ("inputKinds", "validDomain", "extrapolationPolicy", "hysteresis", "dynamicModel", "fitResidual"):
                transfer.pop(key, None)
            for point in transfer.get("points", []):
                point.pop("inputs", None)
                point.pop("uncertainty", None)
    return value


def _registry(records: Any, label: str, errors: list[str], identifiers: dict[str, str]) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for index, record in enumerate(records if isinstance(records, list) else []):
        if not isinstance(record, dict) or not is_identifier(record.get("id")):
            errors.append(f"{label}[{index}] has an invalid id.")
            continue
        key = record["id"]
        if key in identifiers:
            errors.append(f"Identifier {key!r} is duplicated in {identifiers[key]} and {label}.")
        else:
            identifiers[key] = label
        result[key] = record
    return result


def _find_cycle(edges: dict[str, list[str]], label: str, errors: list[str]) -> None:
    visiting: set[str] = set()
    visited: set[str] = set()
    def visit(node: str) -> None:
        if node in visiting:
            errors.append(f"{label} contains an instantaneous cycle at {node!r}.")
            return
        if node in visited: return
        visiting.add(node)
        for target in edges.get(node, []):
            if target in edges: visit(target)
        visiting.remove(node)
        visited.add(node)
    for node in edges: visit(node)


def validate_scientific(manifest: dict[str, Any], known: set[str], errors: list[str]) -> dict[str, dict[str, dict[str, Any]]]:
    scientific = manifest.get("scientific", {})
    ids: dict[str, str] = {}
    registries = {name: _registry(scientific.get(name), f"scientific.{name}", errors, ids) for name in (
        "agents", "activities", "observations", "analyses", "calibrations", "protocols",
        "softwareEnvironments", "claims", "reviews", "consents",
    )}
    all_known = known | set(ids)
    def require(owner: str, reference: Any, allowed: set[str] | None = None) -> None:
        if reference is not None and reference not in (allowed if allowed is not None else all_known):
            errors.append(f"{owner} has unresolved reference {reference!r}.")
    for record in registries["activities"].values():
        if record["endedAt"] < record["startedAt"]: errors.append(f"Activity {record['id']!r} ends before it starts.")
        for ref in record["agentIds"]: require(f"Activity {record['id']!r} agentIds", ref, set(registries["agents"]))
        require(f"Activity {record['id']!r} protocolId", record["protocolId"], set(registries["protocols"]))
        require(f"Activity {record['id']!r} softwareEnvironmentId", record.get("softwareEnvironmentId"), set(registries["softwareEnvironments"]))
        for ref in record["inputIds"] + record["outputIds"]: require(f"Activity {record['id']!r}", ref)
        require(f"Activity {record['id']!r} randomSourceId", record.get("randomSourceId"))
    for record in registries["calibrations"].values():
        require(f"Calibration {record['id']!r} instrumentEntityId", record["instrumentEntityId"], known)
        require(f"Calibration {record['id']!r} protocolId", record["protocolId"], set(registries["protocols"]))
        for ref in record["performedByAgentIds"]: require(f"Calibration {record['id']!r}", ref, set(registries["agents"]))
        require(f"Calibration {record['id']!r} certificateRealizationId", record.get("certificateRealizationId"), known)
    for record in registries["observations"].values():
        require(f"Observation {record['id']!r} featureOfInterestId", record["featureOfInterestId"])
        require(f"Observation {record['id']!r} activityId", record["activityId"], set(registries["activities"]))
        require(f"Observation {record['id']!r} protocolId", record["protocolId"], set(registries["protocols"]))
        require(f"Observation {record['id']!r} calibrationId", record.get("calibrationId"), set(registries["calibrations"]))
        for key in ("rawResultRealizationId", "processedResultRealizationId"): require(f"Observation {record['id']!r} {key}", record.get(key), known)
    runtime_random = {r["id"] for r in manifest.get("runtime", {}).get("randomSources", [])}
    runtime_random |= {r["id"] for r in manifest.get("interactionModel", {}).get("randomSources", [])}
    for record in registries["analyses"].values():
        require(f"Analysis {record['id']!r} activityId", record["activityId"], set(registries["activities"]))
        require(f"Analysis {record['id']!r} softwareEnvironmentId", record["softwareEnvironmentId"], set(registries["softwareEnvironments"]))
        for ref in record["inputIds"] + record["outputIds"]: require(f"Analysis {record['id']!r}", ref)
        if record["reproducibility"] == "seeded" and record.get("randomSourceId") not in runtime_random:
            errors.append(f"Seeded analysis {record['id']!r} requires a declared random source.")
        if record["reproducibility"] == "deterministic" and record.get("randomSourceId") is not None:
            errors.append(f"Deterministic analysis {record['id']!r} must not declare randomSourceId.")
    for record in registries["claims"].values():
        require(f"Claim {record['id']!r} subjectId", record["subjectId"])
        if ("objectId" in record) == ("literal" in record): errors.append(f"Claim {record['id']!r} requires exactly one of objectId or literal.")
        require(f"Claim {record['id']!r} objectId", record.get("objectId"))
        for ref in record["evidenceIds"]: require(f"Claim {record['id']!r} evidenceIds", ref)
    for record in registries["reviews"].values():
        require(f"Review {record['id']!r} reviewedId", record["reviewedId"])
        require(f"Review {record['id']!r} reviewerAgentId", record["reviewerAgentId"], set(registries["agents"]))
    for record in registries["consents"].values():
        require(f"Consent {record['id']!r} grantedByAgentId", record["grantedByAgentId"], set(registries["agents"]))
        for ref in record["appliesToIds"]: require(f"Consent {record['id']!r}", ref)
    return registries


def validate_multimodal(manifest: dict[str, Any], known: set[str], errors: list[str]) -> dict[str, dict[str, Any]]:
    value = manifest.get("multimodal", {})
    ids: dict[str, str] = {}
    timebases = _registry(value.get("timebases"), "multimodal.timebases", errors, ids)
    tracks = _registry(value.get("tracks"), "multimodal.tracks", errors, ids)
    mappings = _registry(value.get("synchronizationMappings"), "multimodal.synchronizationMappings", errors, ids)
    annotations = _registry(value.get("annotations"), "multimodal.annotations", errors, ids)
    for track in tracks.values():
        if track["timebaseId"] not in timebases: errors.append(f"Track {track['id']!r} has unresolved timebaseId.")
        if track["realizationId"] not in known: errors.append(f"Track {track['id']!r} has unresolved realizationId.")
    for mapping in mappings.values():
        if mapping["sourceTimebaseId"] not in timebases or mapping["targetTimebaseId"] not in timebases:
            errors.append(f"Synchronization mapping {mapping['id']!r} has an unresolved timebase.")
        if mapping["sourceTimebaseId"] == mapping["targetTimebaseId"]: errors.append(f"Synchronization mapping {mapping['id']!r} maps a timebase to itself.")
        previous_end: float | None = None
        for segment in mapping["segments"]:
            if segment["sourceEndExclusive"] <= segment["sourceStart"]: errors.append(f"Synchronization mapping {mapping['id']!r} has an empty segment.")
            if previous_end is not None and segment["sourceStart"] < previous_end: errors.append(f"Synchronization mapping {mapping['id']!r} has overlapping segments.")
            previous_end = segment["sourceEndExclusive"]
    for annotation in annotations.values():
        target = annotation["target"]
        if target["trackId"] not in tracks: errors.append(f"Annotation {annotation['id']!r} has unresolved trackId.")
        if target.get("endExclusive") is not None and target.get("start") is not None and target["endExclusive"] <= target["start"]:
            errors.append(f"Annotation {annotation['id']!r} has an empty temporal selector.")
    return {**timebases, **tracks, **mappings, **annotations}


def validate_physical(manifest: dict[str, Any], known: set[str], scientific: dict[str, dict[str, dict[str, Any]]], errors: list[str]) -> None:
    value = manifest.get("physicalSystem", {})
    ids: dict[str, str] = {}
    components = _registry(value.get("components"), "physicalSystem.components", errors, ids)
    ports = _registry(value.get("ports"), "physicalSystem.ports", errors, ids)
    connections = _registry(value.get("connections"), "physicalSystem.connections", errors, ids)
    sensors = _registry(value.get("sensors"), "physicalSystem.sensors", errors, ids)
    actuators = _registry(value.get("actuators"), "physicalSystem.actuators", errors, ids)
    states = _registry(value.get("stateBindings"), "physicalSystem.stateBindings", errors, ids)
    interaction = manifest.get("interactionModel", {})
    state_ids = {x["id"] for x in interaction.get("stateVariables", [])}
    transfer_ids = {x["id"] for x in interaction.get("transferFunctions", [])}
    timing_ids = {x["id"] for x in interaction.get("timingConstraints", [])}
    for component in components.values():
        if component["entityId"] not in known: errors.append(f"Physical component {component['id']!r} has unresolved entityId.")
        if component.get("parentComponentId") not in (None, *components): errors.append(f"Physical component {component['id']!r} has unresolved parentComponentId.")
    for port in ports.values():
        if port["componentId"] not in components: errors.append(f"Physical port {port['id']!r} has unresolved componentId.")
    for connection in connections.values():
        if connection["sourcePortId"] not in ports or connection["targetPortId"] not in ports: errors.append(f"Physical connection {connection['id']!r} has an unresolved port.")
        if connection.get("delayConstraintId") not in (None, *timing_ids): errors.append(f"Physical connection {connection['id']!r} has unresolved delayConstraintId.")
    for sensor in sensors.values():
        if sensor["componentId"] not in components or sensor["outputPortId"] not in ports: errors.append(f"Sensor {sensor['id']!r} has unresolved topology.")
        if sensor["protocolId"] not in scientific["protocols"]: errors.append(f"Sensor {sensor['id']!r} has unresolved protocolId.")
        if sensor.get("calibrationId") not in (None, *scientific["calibrations"]): errors.append(f"Sensor {sensor['id']!r} has unresolved calibrationId.")
    for actuator in actuators.values():
        if actuator["componentId"] not in components or actuator["inputPortId"] not in ports: errors.append(f"Actuator {actuator['id']!r} has unresolved topology.")
        if actuator["protocolId"] not in scientific["protocols"]: errors.append(f"Actuator {actuator['id']!r} has unresolved protocolId.")
        if actuator.get("transferFunctionId") not in (None, *transfer_ids): errors.append(f"Actuator {actuator['id']!r} has unresolved transferFunctionId.")
    for state in states.values():
        if state["stateVariableId"] not in state_ids or state["componentId"] not in components: errors.append(f"State binding {state['id']!r} has unresolved state or component.")


def validate_runtime(manifest: dict[str, Any], errors: list[str]) -> None:
    runtime = manifest.get("runtime", {})
    random_ids: set[str] = set()
    for record in [*runtime.get("randomSources", []), *manifest.get("interactionModel", {}).get("randomSources", [])]:
        if record["id"] in random_ids: errors.append(f"Random source {record['id']!r} is duplicated.")
        random_ids.add(record["id"])
    for process in manifest.get("interactionModel", {}).get("processModels", []):
        if process["processKind"] == "stochastic" and process.get("randomSourceId") not in random_ids:
            errors.append(f"Stochastic process {process['id']!r} has unresolved randomSourceId.")
    for trace in runtime.get("conformanceTraces", []):
        errors.extend(verify_trace(manifest, trace))


def validate_interaction04(manifest: dict[str, Any], errors: list[str]) -> None:
    model = manifest.get("interactionModel") or {}
    timings = {x["id"] for x in model.get("timingConstraints", [])}
    route_edges: dict[str, list[str]] = {}
    for route in model.get("routingRules", []):
        if route.get("delayConstraintId") is not None and route["delayConstraintId"] not in timings:
            errors.append(f"Routing rule {route['id']!r} has unresolved delayConstraintId.")
        if route.get("routingBehavior") in {"copies", "transposes"} and route.get("delayConstraintId") is None:
            route_edges.setdefault(route["sourceEntityId"], []).append(route["targetEntityId"])
            route_edges.setdefault(route["targetEntityId"], [])
    _find_cycle(route_edges, "Zero-delay routing graph", errors)
    for binding in model.get("protocolBindings", []):
        if binding["protocol"] == "MIDI-2.0":
            for key in ("umpGroup", "functionBlock", "umpMessageType", "dataResolutionBits"):
                if key not in binding: errors.append(f"MIDI 2.0 binding {binding['id']!r} requires {key}.")
            if binding.get("jrTimestamp") is not True: errors.append(f"MIDI 2.0 binding {binding['id']!r} must declare JR timestamp handling.")
    for transfer in model.get("transferFunctions", []):
        domain = transfer.get("validDomain", [])
        if domain and any(bounds[1] <= bounds[0] for bounds in domain): errors.append(f"Transfer function {transfer['id']!r} has an empty valid domain.")
        if len(domain) > 1 and not transfer.get("inputKinds"): errors.append(f"Multivariate transfer function {transfer['id']!r} requires inputKinds.")


def validate_delivery(manifest: dict[str, Any], scientific: dict[str, dict[str, dict[str, Any]]], errors: list[str], warnings: list[str]) -> None:
    realization_ids = {x["id"] for x in manifest.get("realizations", [])}
    for realization in manifest.get("realizations", []):
        digests = {x["algorithm"]: x["value"] for x in realization.get("contentDigests", [])}
        if "sha256" in digests and digests["sha256"] != realization["sha256"]:
            errors.append(f"Realization {realization['id']!r} has conflicting SHA-256 identities.")
        chunking = realization.get("chunking")
        if chunking:
            chunks = sorted(chunking["chunks"], key=lambda x: x["index"])
            if [x["index"] for x in chunks] != list(range(len(chunks))): errors.append(f"Realization {realization['id']!r} has non-contiguous chunk indices.")
            if chunks:
                expected_offset = 0
                for chunk in chunks:
                    if chunk["offset"] != expected_offset: errors.append(f"Realization {realization['id']!r} has non-contiguous chunk byte ranges.")
                    expected_offset = chunk["offset"] + chunk["length"]
                if expected_offset != realization["byteSize"]: errors.append(f"Realization {realization['id']!r} chunk coverage does not equal byteSize.")
            elif chunking["strategy"] not in {"external-index", "zarr", "pack-shard"}:
                errors.append(f"Realization {realization['id']!r} has no inline chunks for its chunking strategy.")
            if chunking.get("indexRealizationId") not in (None, *realization_ids): errors.append(f"Realization {realization['id']!r} has unresolved chunk index realization.")
            root = chunking.get("merkleRoot")
            if root and chunks:
                algorithms = {chunk["digest"]["algorithm"] for chunk in chunks}
                if algorithms != {root["algorithm"]}:
                    errors.append(f"Realization {realization['id']!r} Merkle root and chunk algorithms differ.")
                elif merkle_root(chunks, root["algorithm"]) != root["value"]:
                    errors.append(f"Realization {realization['id']!r} has an invalid Merkle root.")
        for key in ("streamingIndexRealizationId", "authenticityEnvelopeRealizationId"):
            if realization.get(key) not in (None, *realization_ids): errors.append(f"Realization {realization['id']!r} has unresolved {key}.")
    consent_ids = set(scientific["consents"])
    agent_ids = set(scientific["agents"])
    for rights in manifest.get("rights", []):
        for ref in rights.get("performerAgentIds", []) + rights.get("communityAuthorityIds", []):
            if ref not in agent_ids: errors.append(f"Rights record {rights['id']!r} has unresolved agent {ref!r}.")
        for ref in rights.get("consentIds", []):
            if ref not in consent_ids: errors.append(f"Rights record {rights['id']!r} has unresolved consent {ref!r}.")
        if rights.get("privacyClassification") == "community-governed" and not rights.get("communityAuthorityIds"):
            errors.append(f"Community-governed rights record {rights['id']!r} requires communityAuthorityIds.")
        if rights.get("embargoUntil") and not rights.get("embargoRationale"):
            errors.append(f"Embargoed rights record {rights['id']!r} requires embargoRationale.")


def _nested_identifiers(value: Any) -> set[str]:
    """Return identifiers declared by nested closed registries.

    Scientific activities may legitimately consume or produce records from the
    acoustics, playable, multimodal, physical, interaction, capture, and runtime
    registries. Those records are not all top-level arrays, so resolving only
    the core top-level registries incorrectly rejects valid provenance chains.
    """
    identifiers: set[str] = set()
    if isinstance(value, dict):
        identifier = value.get("id")
        if is_identifier(identifier): identifiers.add(identifier)
        for item in value.values(): identifiers.update(_nested_identifiers(item))
    elif isinstance(value, list):
        for item in value: identifiers.update(_nested_identifiers(item))
    return identifiers


def validate_manifest(manifest: dict[str, Any]) -> dict[str, Any]:
    errors = list(schema_errors(manifest, MANIFEST_SCHEMA))
    warnings: list[str] = []
    if manifest.get("$schema") != SCHEMA_URI: errors.append("Manifest uses the wrong immutable VAO 0.4.0 schema IRI.")
    if CONTEXT_URI not in manifest.get("@context", []): errors.append("Manifest does not contain the immutable VAO 0.4.0 context IRI.")
    if manifest.get("formatVersion") != FORMAT_VERSION: errors.append("Manifest formatVersion is not 0.4.0.")
    if errors:
        return {
            "valid": False, "formatVersion": manifest.get("formatVersion"), "id": manifest.get("id"),
            "releaseId": manifest.get("release", {}).get("id") if isinstance(manifest.get("release"), dict) else None,
            "logicalAssetCount": len(manifest.get("logicalAssets", [])) if isinstance(manifest.get("logicalAssets"), list) else 0,
            "realizationCount": len(manifest.get("realizations", [])) if isinstance(manifest.get("realizations"), list) else 0,
            "trackCount": len(manifest.get("multimodal", {}).get("tracks", [])) if isinstance(manifest.get("multimodal"), dict) else 0,
            "scientificRecordCount": 0, "errors": sorted(set(errors)), "warnings": [],
        }
    try:
        base = vao03.validate_manifest(project_to_03(manifest))
        errors.extend(error.replace("VAO 0.3", "VAO 0.4.0").replace("profile/0.3", "profile/0.4.0") for error in base["errors"])
        warnings.extend(base["warnings"])
    except (KeyError, TypeError, ValueError) as exc:
        errors.append(f"Cannot apply retained 0.3 semantic checks: {exc}")

    known = {manifest.get("id"), manifest.get("release", {}).get("id")}
    for registry in ("entities", "relations", "logicalAssets", "realizations", "distributions", "repositoryBindings", "assetGroups", "rights"):
        known |= {r.get("id") for r in manifest.get(registry, []) if isinstance(r, dict)}
    for registry in ("acoustics", "playable", "interactionModel", "captureDocumentation", "multimodal", "physicalSystem", "runtime"):
        known |= _nested_identifiers(manifest.get(registry, {}))
    known.discard(None)
    scientific = validate_scientific(manifest, known, errors)
    scientific_ids = {key for records in scientific.values() for key in records}
    known |= scientific_ids
    multimodal = validate_multimodal(manifest, known, errors)
    known |= set(multimodal)
    validate_physical(manifest, known, scientific, errors)
    validate_interaction04(manifest, errors)
    validate_runtime(manifest, errors)
    validate_delivery(manifest, scientific, errors, warnings)

    profiles = {r.get("id") for r in manifest.get("profiles", []) if isinstance(r, dict)}
    conforms = set(manifest.get("conformsTo", []))
    for required in (CORE_PROFILE, DYNAMIC_PROFILE):
        if required not in profiles or required not in conforms: errors.append(f"Every VAO 0.4.0 release must embed and claim {required}.")
    optional_requirements = [
        (SCIENTIFIC_PROFILE, any(scientific.values())),
        (MULTIMODAL_PROFILE, bool(multimodal)),
        (PHYSICAL_PROFILE, any(manifest.get("physicalSystem", {}).get(k) for k in ("components", "ports", "connections", "sensors", "actuators", "stateBindings"))),
        (RUNTIME_PROFILE, bool(manifest.get("runtime", {}).get("conformanceTraces"))),
    ]
    for profile, active in optional_requirements:
        if active and (profile not in profiles or profile not in conforms): errors.append(f"Content requires embedded and claimed profile {profile}.")
    creators = manifest.get("discovery", {}).get("creatorAgentIds", [])
    for creator in creators:
        if creator not in scientific["agents"]: errors.append(f"Discovery creatorAgentId {creator!r} does not resolve to an Agent.")

    return {
        "valid": not errors, "formatVersion": manifest.get("formatVersion"), "id": manifest.get("id"),
        "releaseId": manifest.get("release", {}).get("id") if isinstance(manifest.get("release"), dict) else None,
        "logicalAssetCount": len(manifest.get("logicalAssets", [])), "realizationCount": len(manifest.get("realizations", [])),
        "trackCount": len(manifest.get("multimodal", {}).get("tracks", [])),
        "scientificRecordCount": sum(len(x) for x in manifest.get("scientific", {}).values() if isinstance(x, list)),
        "errors": sorted(set(errors)), "warnings": sorted(set(warnings)),
    }


def validate_carrier_parts(manifest_data: bytes, carrier_data: bytes, payload_names: Iterable[str], payload_reader: Callable[[str], tuple[str, int]]) -> dict[str, Any]:
    try:
        manifest = strict_json_bytes(manifest_data, MANIFEST_NAME)
        carrier = strict_json_bytes(carrier_data, CARRIER_NAME)
    except vao03.VAO03Error as exc:
        return {"valid": False, "formatVersion": None, "errors": [str(exc)], "warnings": []}
    report = validate_manifest(manifest)
    errors, warnings = list(report["errors"]), list(report["warnings"])
    errors.extend(schema_errors(carrier, CARRIER_SCHEMA))
    if carrier.get("manifestSHA256") != sha256_bytes(manifest_data): errors.append("Carrier manifestSHA256 does not match exact manifest bytes.")
    if carrier.get("manifestByteSize") != len(manifest_data): errors.append("Carrier manifestByteSize does not match exact manifest bytes.")
    if carrier.get("releaseId") != manifest.get("release", {}).get("id"): errors.append("Carrier releaseId does not match manifest release.id.")
    realizations = {x["id"]: x for x in manifest.get("realizations", []) if isinstance(x, dict) and "id" in x}
    groups = {x["id"]: x for x in manifest.get("assetGroups", []) if isinstance(x, dict) and "id" in x}
    payload_map: dict[str, str] = {}
    for name in payload_names:
        normalized = unicodedata.normalize("NFC", name)
        if normalized in payload_map: errors.append(f"Carrier payload paths collide after NFC normalization: {payload_map[normalized]!r}, {name!r}.")
        payload_map[normalized] = name
    mapped: set[str] = set()
    embedded: set[str] = set()
    verified = 0
    for mapping in carrier.get("embeddedRealizations", []):
        rid, path = mapping.get("realizationId"), mapping.get("path")
        normalized = unicodedata.normalize("NFC", path) if isinstance(path, str) else "<invalid>"
        if rid in embedded: errors.append(f"Carrier maps realization {rid!r} more than once.")
        if normalized in mapped: errors.append(f"Carrier maps path {path!r} more than once.")
        embedded.add(rid); mapped.add(normalized)
        if rid not in realizations: errors.append(f"Carrier maps unknown realization {rid!r}."); continue
        if not is_safe_path(path, "payload"): errors.append(f"Carrier path {path!r} is unsafe."); continue
        if normalized not in payload_map: errors.append(f"Carrier path {path!r} is missing."); continue
        digest, size = payload_reader(payload_map[normalized]); verified += size
        if digest != realizations[rid]["sha256"] or size != realizations[rid]["byteSize"]: errors.append(f"Embedded realization {rid!r} fails exact byte verification.")
    if mapped != set(payload_map): errors.append("Carrier payload closure does not equal its embedded mapping.")
    for group_id in carrier.get("completeGroupIds", []):
        if group_id not in groups: errors.append(f"Carrier declares unknown complete group {group_id!r}.")
        elif not set(groups[group_id]["realizationIds"]) <= embedded: errors.append(f"Carrier complete group {group_id!r} is incomplete.")
    if carrier.get("carrierMode") == "preservation-closure" and set(realizations) != embedded: errors.append("Preservation closure does not embed every realization.")
    return {**report, "valid": not errors, "verifiedBytes": verified, "errors": sorted(set(errors)), "warnings": sorted(set(warnings))}


def validate_workspace(path: Path) -> dict[str, Any]:
    errors: list[str] = []
    if not path.is_dir(): return {"valid": False, "errors": ["VAO workspace is not a directory."], "warnings": []}
    if not (path / "mimetype").is_file() or (path / "mimetype").read_bytes() != MIMETYPE.encode(): errors.append("Workspace mimetype bytes are not exact.")
    try:
        manifest_data = (path / MANIFEST_NAME).read_bytes()
        carrier_data = (path / CARRIER_NAME).read_bytes()
    except OSError as exc:
        return {"valid": False, "errors": errors + [f"Cannot read structural file: {exc}"], "warnings": []}
    payload_names = [item.relative_to(path).as_posix() for item in (path / "payload").rglob("*") if item.is_file() and not item.is_symlink()] if (path / "payload").is_dir() else []
    def reader(name: str) -> tuple[str, int]: return sha256_file(path / name)
    report = validate_carrier_parts(manifest_data, carrier_data, payload_names, reader)
    try:
        manifest = strict_json_bytes(manifest_data, MANIFEST_NAME); carrier = strict_json_bytes(carrier_data, CARRIER_NAME)
        realizations = {item["id"]: item for item in manifest.get("realizations", []) if isinstance(item, dict) and "id" in item}
        for mapping in carrier.get("embeddedRealizations", []):
            realization = realizations.get(mapping.get("realizationId")); target = path / str(mapping.get("path", ""))
            if realization is not None and target.is_file():
                with target.open("rb") as stream: report["errors"].extend(validate_chunk_stream(realization, stream))
    except (OSError, vao03.VAO03Error, VAO04Error) as exc:
        report["errors"].append(f"Cannot verify embedded chunks: {exc}")
    report["errors"] = sorted(set(errors + report["errors"])); report["valid"] = not report["errors"]
    return report


def validate_archive(path: Path) -> dict[str, Any]:
    try:
        with zipfile.ZipFile(path) as archive:
            infos = archive.infolist(); names = [x.filename for x in infos]
            errors: list[str] = []
            if not infos or infos[0].filename != "mimetype" or infos[0].compress_type != zipfile.ZIP_STORED: errors.append("mimetype must be the first stored ZIP entry.")
            if len(names) != len(set(names)): errors.append("Archive contains duplicate paths.")
            for info in infos:
                path_value = PurePosixPath(info.filename)
                if path_value.is_absolute() or ".." in path_value.parts or "\\" in info.filename: errors.append(f"Unsafe archive path {info.filename!r}.")
                mode = info.external_attr >> 16
                if mode and stat.S_ISLNK(mode): errors.append(f"Archive entry {info.filename!r} is a symbolic link.")
            if archive.read("mimetype") != MIMETYPE.encode(): errors.append("Archive mimetype bytes are not exact.")
            manifest_data, carrier_data = archive.read(MANIFEST_NAME), archive.read(CARRIER_NAME)
            payload_names = [name for name in names if name.startswith("payload/") and not name.endswith("/")]
            def reader(name: str) -> tuple[str, int]:
                data = archive.read(name); return hashlib.sha256(data).hexdigest(), len(data)
            report = validate_carrier_parts(manifest_data, carrier_data, payload_names, reader)
            try:
                manifest = strict_json_bytes(manifest_data, MANIFEST_NAME); carrier = strict_json_bytes(carrier_data, CARRIER_NAME)
                realizations = {item["id"]: item for item in manifest.get("realizations", []) if isinstance(item, dict) and "id" in item}
                for mapping in carrier.get("embeddedRealizations", []):
                    realization = realizations.get(mapping.get("realizationId")); name = mapping.get("path")
                    if realization is not None and isinstance(name, str) and name in names:
                        with archive.open(name) as stream: report["errors"].extend(validate_chunk_stream(realization, stream))
            except (KeyError, vao03.VAO03Error, VAO04Error) as exc:
                report["errors"].append(f"Cannot verify embedded chunks: {exc}")
            report["errors"] = sorted(set(errors + report["errors"])); report["valid"] = not report["errors"]
            return report
    except (OSError, KeyError, zipfile.BadZipFile) as exc:
        return {"valid": False, "errors": [f"Cannot read VAO 0.4.0 archive: {exc}"], "warnings": []}


def validate(path: Path) -> dict[str, Any]:
    if path.is_dir(): return validate_workspace(path)
    if path.suffix.lower() == ".json":
        try: return validate_manifest(load_json(path)[0])
        except (OSError, vao03.VAO03Error) as exc: return {"valid": False, "errors": [str(exc)], "warnings": []}
    return validate_archive(path)


def pack_workspace(workspace: Path, output: Path) -> None:
    report = validate_workspace(workspace)
    if not report["valid"]: raise VAO04Error("Cannot pack invalid VAO 0.4.0 workspace: " + "; ".join(report["errors"][:3]))
    if output.exists(): raise VAO04Error(f"Output already exists: {output}")
    with zipfile.ZipFile(output, "w", allowZip64=True) as archive:
        archive.writestr(vao03.zip_info("mimetype"), MIMETYPE.encode())
        for name in (MANIFEST_NAME, CARRIER_NAME): archive.writestr(vao03.zip_info(name), (workspace / name).read_bytes())
        for path in sorted((workspace / "payload").rglob("*")):
            if path.is_file(): archive.write(path, path.relative_to(workspace).as_posix(), compress_type=zipfile.ZIP_STORED)
    final = validate_archive(output)
    if not final["valid"]: raise VAO04Error("Finished archive failed validation: " + "; ".join(final["errors"][:3]))


def _promote_legacy_activities(
    records: list[Any], modified_at: str, known: set[str], migrator_agent_id: str,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]]]:
    """Promote recognizable 0.3 provenance activities into typed 0.4 records.

    VAO 0.3 deliberately allowed open paradata. A record with an activity ID,
    inputs, outputs, method, and software is sufficiently structured to retain
    its references as a VAO 0.4 Activity. The original record is still kept in
    the migration activity parameters, so promotion is additive and lossless.
    """
    agents: dict[str, dict[str, Any]] = {}
    activities: list[dict[str, Any]] = []
    protocols: dict[str, dict[str, Any]] = {}
    software_environments: dict[str, dict[str, Any]] = {}
    for record in records:
        if not isinstance(record, dict) or not is_identifier(record.get("id")):
            continue
        method = record.get("method") if isinstance(record.get("method"), dict) else {}
        software = record.get("software") if isinstance(record.get("software"), dict) else {}
        method_type = str(method.get("methodType", "legacy-processing"))
        activity_type = str(record.get("activityType", method_type))
        lowered = f"{method_type} {activity_type}".lower()
        activity_kind = next((kind for kind in (
            "capture", "measurement", "digitization", "simulation", "inference",
            "annotation", "review", "migration", "render",
        ) if kind in lowered), "processing")
        fingerprint = hashlib.sha256(json_bytes({"activityType": activity_type, "method": method})).hexdigest()
        protocol_id = f"urn:vao:protocol:migrated:{fingerprint}"
        protocols.setdefault(protocol_id, {
            "id": protocol_id,
            "labels": {"en": f"Migrated {method_type} protocol declaration"},
            "procedure": f"VAO 0.3 declared activity type {activity_type!r}, method {method_type!r}, and representation status {method.get('representationStatus', 'not stated')!r}.",
            "version": "legacy-0.3-declaration",
        })

        software_id: str | None = None
        agent_id = migrator_agent_id
        if software:
            software_digest = hashlib.sha256(json_bytes(software)).hexdigest()
            software_id = f"urn:vao:software:migrated:{software_digest}"
            agent_id = f"urn:vao:agent:migrated-software:{software_digest}"
            name = str(software.get("name", "Unidentified legacy software"))
            version = str(software.get("version", "not stated"))
            agents.setdefault(agent_id, {
                "id": agent_id, "agentKind": "software-agent",
                "labels": {"en": f"{name} ({version}; migrated declaration)"},
            })
            software_environments.setdefault(software_id, {
                "id": software_id, "name": name, "version": version,
                "identity": {"algorithm": "sha256", "value": software_digest},
                "extensions": {
                    "https://w3id.org/modavis/vao/ontology#identityScope": "Digest of the preserved VAO 0.3 software declaration; executable identity was not supplied."
                },
            })

        inputs = [item for item in record.get("inputIds", []) if item in known]
        outputs = [item for item in record.get("outputIds", []) if item in known]
        started_at = record.get("startedAt", modified_at)
        ended_at = record.get("endedAt", started_at)
        activity: dict[str, Any] = {
            "id": record["id"], "activityKind": activity_kind,
            "startedAt": started_at, "endedAt": ended_at,
            "agentIds": [agent_id], "protocolId": protocol_id,
            "inputIds": inputs, "outputIds": outputs,
            "parameterValues": {
                "https://w3id.org/modavis/vao/ontology#legacyActivity": record,
            },
            "notes": "Promoted from a VAO 0.3 open paradata record; omitted input/output references remain preserved in legacyActivity.",
        }
        if software_id is not None: activity["softwareEnvironmentId"] = software_id
        activities.append(activity)
    return list(agents.values()), activities, list(protocols.values()), list(software_environments.values())


def migrate_03_manifest(source: dict[str, Any]) -> dict[str, Any]:
    if source.get("formatVersion") != vao03.FORMAT_VERSION: raise VAO04Error("Migration input must be VAO 0.3.3.")
    value = copy.deepcopy(source)
    value["$schema"] = SCHEMA_URI
    value["@context"] = [CONTEXT_URI if x == vao03.CONTEXT_URI else x for x in value["@context"]]
    value["formatVersion"] = FORMAT_VERSION
    for registry in ("profiles", "materializableProfiles"):
        for profile in value[registry]:
            profile["id"] = profile["id"].replace("/0.3", f"/{FORMAT_VERSION}")
            profile["version"] = FORMAT_VERSION
    value["conformsTo"] = [x.replace("/0.3", f"/{FORMAT_VERSION}") if x.startswith(PROFILE_BASE) else x for x in value["conformsTo"]]
    agent_id = "urn:vao:agent:vao04-migrator"
    protocol_id = "urn:vao:protocol:vao033-to-vao040"
    software_id = "urn:vao:software:vao04-reference"
    activity_id = f"urn:vao:activity:migrate:{hashlib.sha256(json_bytes(source)).hexdigest()}"
    legacy_paradata = value.pop("paradata", [])
    legacy_analyses = value.pop("analyses", [])
    known = _nested_identifiers(value) | {value["id"], value["release"]["id"]}
    promoted_agents, promoted_activities, promoted_protocols, promoted_software = _promote_legacy_activities(
        legacy_paradata, value["modifiedAt"], known, agent_id,
    )
    legacy = {"https://w3id.org/modavis/vao/ontology#legacyParadata": legacy_paradata, "https://w3id.org/modavis/vao/ontology#legacyAnalyses": legacy_analyses}
    value["scientific"] = {
        "agents": [{"id": agent_id, "agentKind": "software-agent", "labels": {"en": "VAO 0.4 reference migrator"}}, *promoted_agents],
        "activities": [{"id": activity_id, "activityKind": "migration", "startedAt": value["modifiedAt"], "endedAt": value["modifiedAt"], "agentIds": [agent_id], "protocolId": protocol_id, "softwareEnvironmentId": software_id, "inputIds": [value["id"]], "outputIds": [value["release"]["id"]], "parameterValues": legacy}, *promoted_activities],
        "observations": [], "analyses": [], "calibrations": [],
        "protocols": [{"id": protocol_id, "labels": {"en": "VAO 0.3.3 to 0.4.0 semantic migration"}, "procedure": "Preserve exact realization identities and project closed 0.3 registries into 0.4; retain legacy open records as namespaced migration parameters.", "version": FORMAT_VERSION}, *promoted_protocols],
        "softwareEnvironments": [{"id": software_id, "name": "vao04.py", "version": FORMAT_VERSION, "identity": {"algorithm": "sha256", "value": hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}}, *promoted_software],
        "claims": [], "reviews": [], "consents": [],
    }
    if SCIENTIFIC_PROFILE not in {profile["id"] for profile in value["profiles"]}:
        value["profiles"].append({
            "id": SCIENTIFIC_PROFILE, "version": FORMAT_VERSION,
            "requiredCapabilities": [CAPABILITY_BASE + "typed-scientific-provenance"],
        })
        value["conformsTo"].append(SCIENTIFIC_PROFILE)
    value["multimodal"] = {"timebases": [], "tracks": [], "synchronizationMappings": [], "annotations": []}
    value["physicalSystem"] = {"components": [], "ports": [], "connections": [], "sensors": [], "actuators": [], "stateBindings": []}
    semantics = {"timestampOrder": "ascending", "simultaneousEventOrder": "priority-then-event-id", "transitionEvaluation": "snapshot", "actionExecution": "execution-group-then-array-order", "runToCompletion": True, "reentrancyPolicy": "queue", "lateEventPolicy": "reject", "timeResolution": {"value": 1, "unit": "http://qudt.org/vocab/unit/MilliSEC"}, "maximumMicrosteps": 10000, "voiceAllocation": "lowest-free-then-oldest", "maximumVoices": 1024}
    value["runtime"] = {"executionSemantics": semantics, "randomSources": [], "renderers": [], "conformanceTraces": []}
    value["discovery"] = {"resourceType": "Dataset", "creatorAgentIds": [agent_id], "contributorAgentIds": [], "relatedIdentifiers": [], "fundingReferences": [], "subjects": []}
    if isinstance(value.get("interactionModel"), dict):
        value["interactionModel"]["executionSemantics"] = copy.deepcopy(semantics)
        value["interactionModel"]["randomSources"] = []
    for realization in value["realizations"]:
        realization["contentDigests"] = [{"algorithm": "sha256", "value": realization["sha256"]}]
    return value


def migrate_03_workspace(source: Path, destination: Path) -> None:
    if destination.exists(): raise VAO04Error(f"Destination already exists: {destination}")
    import shutil
    shutil.copytree(source, destination)
    manifest, _ = load_json(destination / MANIFEST_NAME)
    migrated = migrate_03_manifest(manifest)
    write_json(destination / MANIFEST_NAME, migrated)
    carrier, _ = load_json(destination / CARRIER_NAME)
    carrier["$schema"] = f"{BASE}/schema/carrier.json"; carrier["formatVersion"] = FORMAT_VERSION
    data = json_bytes(migrated); carrier["manifestSHA256"] = sha256_bytes(data); carrier["manifestByteSize"] = len(data)
    write_json(destination / CARRIER_NAME, carrier)


def print_report(report: dict[str, Any], as_json: bool) -> None:
    if as_json: print(json.dumps(report, indent=2, ensure_ascii=False)); return
    print("VALID" if report.get("valid") else "INVALID")
    for error in report.get("errors", []): print(f"ERROR: {error}")
    for warning in report.get("warnings", []): print(f"WARNING: {warning}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    validate_cmd = sub.add_parser("validate"); validate_cmd.add_argument("path", type=Path); validate_cmd.add_argument("--json", action="store_true")
    pack_cmd = sub.add_parser("pack"); pack_cmd.add_argument("workspace", type=Path); pack_cmd.add_argument("output", type=Path)
    migrate_cmd = sub.add_parser("migrate-0.3"); migrate_cmd.add_argument("source", type=Path); migrate_cmd.add_argument("destination", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == "validate":
            report = validate(args.path); print_report(report, args.json); return 0 if report["valid"] else 1
        if args.command == "pack": pack_workspace(args.workspace, args.output); return 0
        if args.command == "migrate-0.3": migrate_03_workspace(args.source, args.destination); return 0
    except (OSError, VAO04Error) as exc:
        print(f"ERROR: {exc}", file=sys.stderr); return 2
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
