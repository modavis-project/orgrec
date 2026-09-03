#!/usr/bin/env python3
"""Build the immutable VAO 0.4.0 schema bundle from the reviewed 0.3.3 line.

The 0.4 manifest deliberately retains every closed 0.3 domain definition and
then replaces the draft's open scientific records and underspecified runtime,
protocol, delivery, and multimodal records.  Generated JSON is canonicalized so
the release-bundle digest is reproducible.
"""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SCHEMAS = ROOT / "Schemas"
VERSION = "0.4.0"
BASE = f"https://w3id.org/modavis/vao/{VERSION}"


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, sort_keys=False) + "\n", encoding="utf-8")


def identifier(ref: str = "#/$defs/identifier") -> dict[str, str]:
    return {"$ref": ref}


def array_of(ref: str, *, minimum: int = 0) -> dict[str, object]:
    result: dict[str, object] = {"type": "array", "items": {"$ref": ref}}
    if minimum:
        result["minItems"] = minimum
    return result


def evidence_properties(defs: dict[str, object]) -> dict[str, object]:
    return {
        "status": {"$ref": "#/$defs/evidenceStatus"},
        "source": {"$ref": "#/$defs/playbackMetadataSource"},
        "generatedById": identifier(),
        "reviewedById": identifier(),
        "sourceLocator": {"type": "string", "minLength": 1},
        "notes": {"type": "string"},
    }


def record(required: list[str], properties: dict[str, object]) -> dict[str, object]:
    return {
        "type": "object",
        "required": required,
        "properties": properties,
        "additionalProperties": False,
    }


def build_manifest() -> dict[str, object]:
    source = json.loads((SCHEMAS / "vao-manifest-0.3.schema.json").read_text(encoding="utf-8"))
    schema = copy.deepcopy(source)
    schema["$id"] = f"{BASE}/schema/manifest.json"
    schema["title"] = "Virtual Acoustic Object 0.4.0 manifest"
    schema["description"] = (
        "Immutable multimodal scientific virtual-musical-instrument release with exact byte identity, "
        "typed provenance, deterministic interaction semantics, physical-system topology, and lossless linked-data projection."
    )
    required = schema["required"]
    required.remove("paradata")
    required.remove("analyses")
    insert_at = required.index("logicalAssets")
    required[insert_at:insert_at] = ["scientific", "multimodal", "physicalSystem", "runtime", "discovery"]
    properties = schema["properties"]
    properties["$schema"] = {"const": f"{BASE}/schema/manifest.json"}
    properties["@context"] = {
        "type": "array", "minItems": 1, "uniqueItems": True,
        "items": {"type": "string", "format": "uri"},
        "contains": {"const": f"{BASE}/context.jsonld"},
    }
    properties["formatVersion"] = {"const": VERSION}
    properties.pop("paradata")
    properties.pop("analyses")
    properties["scientific"] = {"$ref": "#/$defs/scientific"}
    properties["multimodal"] = {"$ref": "#/$defs/multimodal"}
    properties["physicalSystem"] = {"$ref": "#/$defs/physicalSystem"}
    properties["runtime"] = {"$ref": "#/$defs/runtime"}
    properties["discovery"] = {"$ref": "#/$defs/discovery"}

    defs = schema["$defs"]
    defs["profile"]["properties"]["version"] = {"const": VERSION}
    defs["materializableProfile"]["properties"]["version"] = {"const": VERSION}

    technical = defs["technicalMetadata"]
    technical["properties"]["kind"] = {"enum": [
        "audio", "video", "geometry", "image", "depth", "volumetric", "motion-capture",
        "event-stream", "sensor-data", "score", "document", "data", "software", "other",
    ]}
    technical["properties"].update({
        "durationSeconds": {"type": "number", "minimum": 0},
        "timebaseId": identifier(),
        "width": {"type": "integer", "minimum": 1},
        "height": {"type": "integer", "minimum": 1},
        "frameRate": {"type": "number", "exclusiveMinimum": 0},
        "codec": {"type": "string", "minLength": 1},
        "colorSpace": {"type": "string", "minLength": 1},
        "eventEncoding": {"type": "string", "minLength": 1},
        "sensorEncoding": {"type": "string", "minLength": 1},
        "scoreFormat": {"type": "string", "minLength": 1},
        "coordinateFrameId": identifier(),
        "trajectoryTrackId": identifier(),
    })
    technical["allOf"].extend([
        {"if": {"properties": {"kind": {"const": "video"}}}, "then": {"required": ["width", "height", "frameRate", "durationSeconds", "timebaseId"]}},
        {"if": {"properties": {"kind": {"enum": ["event-stream", "sensor-data", "motion-capture"]}}}, "then": {"required": ["timebaseId"]}},
    ])

    realization = defs["realization"]
    realization["properties"].update({
        "contentDigests": {"type": "array", "minItems": 1, "uniqueItems": True, "items": {"$ref": "#/$defs/contentDigest"}},
        "chunking": {"$ref": "#/$defs/chunking"},
        "streamingIndexRealizationId": identifier(),
        "authenticityEnvelopeRealizationId": identifier(),
    })
    defs["contentDigest"] = record(["algorithm", "value"], {
        "algorithm": {"enum": ["sha256", "sha512"]},
        "value": {"type": "string", "pattern": "^[0-9a-f]+$"},
    })
    defs["contentDigest"]["allOf"] = [
        {"if": {"properties": {"algorithm": {"const": "sha256"}}}, "then": {"properties": {"value": {"pattern": "^[0-9a-f]{64}$"}}}},
        {"if": {"properties": {"algorithm": {"const": "sha512"}}}, "then": {"properties": {"value": {"pattern": "^[0-9a-f]{128}$"}}}},
    ]
    defs["chunk"] = record(["index", "offset", "length", "digest"], {
        "index": {"type": "integer", "minimum": 0}, "offset": {"type": "integer", "minimum": 0},
        "length": {"type": "integer", "minimum": 1}, "digest": {"$ref": "#/$defs/contentDigest"},
    })
    defs["chunking"] = record(["strategy", "chunks"], {
        "strategy": {"enum": ["fixed-size", "content-defined", "external-index", "zarr", "pack-shard"]},
        "chunkSize": {"type": "integer", "minimum": 1},
        "merkleRoot": {"$ref": "#/$defs/contentDigest"},
        "chunks": {"type": "array", "items": {"$ref": "#/$defs/chunk"}},
        "indexRealizationId": identifier(),
    })

    rights = defs["rights"]
    rights["properties"].update({
        "performerAgentIds": {"$ref": "#/$defs/identifierList"},
        "consentIds": {"$ref": "#/$defs/identifierList"},
        "communityAuthorityIds": {"$ref": "#/$defs/identifierList"},
        "traditionalKnowledgeLabelIRIs": {"type": "array", "uniqueItems": True, "items": {"$ref": "#/$defs/iri"}},
        "privacyClassification": {"enum": ["public", "restricted", "sensitive-personal", "community-governed"]},
        "embargoUntil": {"$ref": "#/$defs/dateTime"},
        "embargoRationale": {"$ref": "#/$defs/localizedText"},
        "redactionOfRealizationIds": {"$ref": "#/$defs/identifierList"},
        "carePrinciples": {"type": "array", "uniqueItems": True, "items": {"enum": ["collective-benefit", "authority-to-control", "responsibility", "ethics"]}},
    })

    # Scientific records: closed, PROV/SOSA/CRMsci-compatible structures.
    defs["agent"] = record(["id", "agentKind", "labels"], {
        "id": identifier(), "agentKind": {"enum": ["person", "organization", "community", "software-agent"]},
        "labels": {"$ref": "#/$defs/localizedText"}, "orcid": {"$ref": "#/$defs/iri"},
        "ror": {"$ref": "#/$defs/iri"}, "roles": {"type": "array", "uniqueItems": True, "items": {"$ref": "#/$defs/iri"}},
        "contact": {"type": "string"}, "extensions": {"$ref": "#/$defs/extensions"},
    })
    defs["softwareEnvironment"] = record(["id", "name", "version", "identity"], {
        "id": identifier(), "name": {"type": "string", "minLength": 1}, "version": {"type": "string", "minLength": 1},
        "identity": {"$ref": "#/$defs/contentDigest"}, "sourceCodeIRI": {"$ref": "#/$defs/iri"},
        "softwareHeritageId": {"type": "string", "pattern": "^swh:1:"}, "containerDigest": {"$ref": "#/$defs/contentDigest"},
        "modelWeightDigest": {"$ref": "#/$defs/contentDigest"}, "dependencies": {"type": "array", "items": {"type": "string", "minLength": 1}},
        "runtime": {"type": "string", "minLength": 1}, "extensions": {"$ref": "#/$defs/extensions"},
    })
    defs["protocol"] = record(["id", "labels", "procedure", "version"], {
        "id": identifier(), "labels": {"$ref": "#/$defs/localizedText"}, "procedure": {"type": "string", "minLength": 1},
        "version": {"type": "string", "minLength": 1}, "documentRealizationId": identifier(),
        "standardIRI": {"$ref": "#/$defs/iri"}, "parameters": {"$ref": "#/$defs/extensions"},
    })
    defs["calibration"] = record(["id", "instrumentEntityId", "protocolId", "performedByAgentIds", "performedAt", "resultStatus"], {
        "id": identifier(), "instrumentEntityId": identifier(), "protocolId": identifier(),
        "performedByAgentIds": {"$ref": "#/$defs/uniqueIdentifiers"}, "performedAt": {"$ref": "#/$defs/dateTime"},
        "certificateRealizationId": identifier(), "resultStatus": {"enum": ["pass", "fail", "limited", "unknown"]},
        "uncertainty": {"$ref": "#/$defs/uncertainty"}, "validUntil": {"$ref": "#/$defs/dateTime"},
    })
    defs["activity"] = record(["id", "activityKind", "startedAt", "endedAt", "agentIds", "protocolId", "inputIds", "outputIds"], {
        "id": identifier(), "activityKind": {"enum": ["capture", "measurement", "digitization", "processing", "simulation", "inference", "annotation", "review", "migration", "render"]},
        "startedAt": {"$ref": "#/$defs/dateTime"}, "endedAt": {"$ref": "#/$defs/dateTime"},
        "agentIds": {"$ref": "#/$defs/uniqueIdentifiers"}, "protocolId": identifier(),
        "softwareEnvironmentId": identifier(), "inputIds": {"$ref": "#/$defs/identifierList"}, "outputIds": {"$ref": "#/$defs/identifierList"},
        "parameterValues": {"$ref": "#/$defs/extensions"}, "randomSourceId": identifier(),
        "environmentObservationIds": {"$ref": "#/$defs/identifierList"}, "notes": {"type": "string"},
    })
    defs["quantityValue"] = record(["value", "unit"], {
        "value": {}, "unit": {"$ref": "#/$defs/iri"}, "quantityKind": {"$ref": "#/$defs/iri"},
        "uncertainty": {"$ref": "#/$defs/uncertainty"}, "sampleCount": {"type": "integer", "minimum": 1},
        "censoring": {"enum": ["none", "left", "right", "interval"]}, "outlierPolicy": {"type": "string"},
    })
    defs["observation"] = record(["id", "observedProperty", "featureOfInterestId", "result", "resultTime", "activityId", "protocolId", "status"], {
        "id": identifier(), "observedProperty": {"$ref": "#/$defs/iri"}, "featureOfInterestId": identifier(),
        "result": {"$ref": "#/$defs/quantityValue"}, "resultTime": {"$ref": "#/$defs/dateTime"},
        "activityId": identifier(), "protocolId": identifier(), "sensorId": identifier(), "calibrationId": identifier(),
        "rawResultRealizationId": identifier(), "processedResultRealizationId": identifier(),
        "status": {"$ref": "#/$defs/evidenceStatus"}, "qualityFlags": {"type": "array", "uniqueItems": True, "items": {"type": "string", "minLength": 1}},
    })
    defs["analysis"] = record(["id", "analysisKind", "activityId", "inputIds", "outputIds", "softwareEnvironmentId", "parameters", "reproducibility"], {
        "id": identifier(), "analysisKind": {"$ref": "#/$defs/iri"}, "activityId": identifier(),
        "inputIds": {"$ref": "#/$defs/uniqueIdentifiers"}, "outputIds": {"$ref": "#/$defs/uniqueIdentifiers"},
        "softwareEnvironmentId": identifier(), "parameters": {"$ref": "#/$defs/extensions"},
        "randomSourceId": identifier(), "reproducibility": {"enum": ["deterministic", "seeded", "non-reproducible"]},
        "fitResidual": {"$ref": "#/$defs/quantityValue"}, "validationIds": {"$ref": "#/$defs/identifierList"},
    })
    defs["claim"] = record(["id", "subjectId", "predicate", "status", "evidenceIds"], {
        "id": identifier(), "subjectId": identifier(), "predicate": {"$ref": "#/$defs/iri"},
        "objectId": identifier(), "literal": {"$ref": "#/$defs/literal"}, "status": {"$ref": "#/$defs/evidenceStatus"},
        "confidence": {"type": "number", "minimum": 0, "maximum": 1}, "evidenceIds": {"$ref": "#/$defs/uniqueIdentifiers"},
        "generatedById": identifier(), "reviewIds": {"$ref": "#/$defs/identifierList"},
    })
    defs["review"] = record(["id", "reviewedId", "reviewerAgentId", "reviewedAt", "decision"], {
        "id": identifier(), "reviewedId": identifier(), "reviewerAgentId": identifier(), "reviewedAt": {"$ref": "#/$defs/dateTime"},
        "decision": {"enum": ["accepted", "rejected", "needs-revision", "not-assessed"]}, "rationale": {"type": "string", "minLength": 1},
    })
    defs["consent"] = record(["id", "grantedByAgentId", "appliesToIds", "decision", "recordedAt"], {
        "id": identifier(), "grantedByAgentId": identifier(), "appliesToIds": {"$ref": "#/$defs/uniqueIdentifiers"},
        "decision": {"enum": ["granted", "denied", "withdrawn", "conditional"]}, "recordedAt": {"$ref": "#/$defs/dateTime"},
        "conditions": {"$ref": "#/$defs/localizedText"}, "evidenceRealizationId": identifier(),
    })
    defs["scientific"] = record(
        ["agents", "activities", "observations", "analyses", "calibrations", "protocols", "softwareEnvironments", "claims", "reviews", "consents"],
        {name: array_of(f"#/$defs/{kind}") for name, kind in {
            "agents": "agent", "activities": "activity", "observations": "observation", "analyses": "analysis",
            "calibrations": "calibration", "protocols": "protocol", "softwareEnvironments": "softwareEnvironment",
            "claims": "claim", "reviews": "review", "consents": "consent",
        }.items()},
    )

    # Multimodal time/space, including piecewise clock mappings and annotations.
    defs["timebase"] = record(["id", "kind", "unit", "rate", "origin"], {
        "id": identifier(), "kind": {"enum": ["monotonic", "wall-clock", "media", "musical", "external-timecode"]},
        "unit": {"$ref": "#/$defs/iri"}, "rate": {"type": "number", "exclusiveMinimum": 0},
        "origin": {"type": "number"}, "epoch": {"$ref": "#/$defs/dateTime"}, "wrapPeriod": {"type": "number", "exclusiveMinimum": 0},
    })
    defs["track"] = record(["id", "modality", "timebaseId", "realizationId", "continuity"], {
        "id": identifier(), "modality": {"enum": ["audio", "video", "image-sequence", "depth", "volumetric", "motion-capture", "sensor", "event", "score", "annotation", "trajectory"]},
        "timebaseId": identifier(), "realizationId": identifier(), "coordinateFrameId": identifier(),
        "channelSelector": {"type": "string"}, "continuity": {"enum": ["continuous", "segmented", "sparse"]},
    })
    defs["clockSegment"] = record(["sourceStart", "sourceEndExclusive", "scale", "offset", "residualUncertainty"], {
        "sourceStart": {"type": "number"}, "sourceEndExclusive": {"type": "number"},
        "scale": {"type": "number"}, "offset": {"type": "number"}, "residualUncertainty": {"$ref": "#/$defs/uncertainty"},
        "discontinuityAfter": {"enum": ["none", "dropout", "clock-reset", "pause", "unknown"]},
    })
    defs["synchronizationMapping"] = record(["id", "sourceTimebaseId", "targetTimebaseId", "method", "segments", "activityId"], {
        "id": identifier(), "sourceTimebaseId": identifier(), "targetTimebaseId": identifier(),
        "method": {"enum": ["shared-clock", "timecode", "event-matching", "cross-correlation", "manual", "device-timestamp"]},
        "segments": array_of("#/$defs/clockSegment", minimum=1), "activityId": identifier(),
        "jitter": {"$ref": "#/$defs/uncertainty"},
    })
    defs["annotationSelector"] = record(["trackId"], {
        "trackId": identifier(), "start": {"type": "number"}, "endExclusive": {"type": "number"},
        "spatialFragment": {"type": "string"}, "svgSelector": {"type": "string"}, "eventLocator": {"type": "string"},
        "scoreElementId": {"type": "string"},
    })
    defs["annotation"] = record(["id", "motivation", "target", "body", "createdByAgentId"], {
        "id": identifier(), "motivation": {"$ref": "#/$defs/iri"}, "target": {"$ref": "#/$defs/annotationSelector"},
        "body": {"oneOf": [{"$ref": "#/$defs/literal"}, {"type": "object", "required": ["id"], "properties": {"id": identifier()}, "additionalProperties": False}]},
        "createdByAgentId": identifier(), "createdAt": {"$ref": "#/$defs/dateTime"}, "activityId": identifier(),
    })
    defs["multimodal"] = record(["timebases", "tracks", "synchronizationMappings", "annotations"], {
        "timebases": array_of("#/$defs/timebase"), "tracks": array_of("#/$defs/track"),
        "synchronizationMappings": array_of("#/$defs/synchronizationMapping"), "annotations": array_of("#/$defs/annotation"),
    })

    # Physical component/port/sensor/actuator topology.
    defs["physicalComponent"] = record(["id", "entityId", "componentKind"], {
        "id": identifier(), "entityId": identifier(), "componentKind": {"$ref": "#/$defs/iri"},
        "parentComponentId": identifier(), "portIds": {"$ref": "#/$defs/identifierList"},
    })
    defs["physicalPort"] = record(["id", "componentId", "direction", "signalKind"], {
        "id": identifier(), "componentId": identifier(), "direction": {"enum": ["input", "output", "bidirectional"]},
        "signalKind": {"enum": ["mechanical", "pneumatic", "electrical", "optical", "acoustic", "digital", "control", "energy"]},
        "quantityKind": {"$ref": "#/$defs/iri"},
    })
    defs["physicalConnection"] = record(["id", "sourcePortId", "targetPortId", "connectionKind"], {
        "id": identifier(), "sourcePortId": identifier(), "targetPortId": identifier(),
        "connectionKind": {"enum": ["signal", "energy", "material", "mechanical-coupling"]},
        "delayConstraintId": identifier(), "bidirectional": {"type": "boolean"},
    })
    defs["sensor"] = record(["id", "componentId", "observedProperty", "outputPortId", "protocolId"], {
        "id": identifier(), "componentId": identifier(), "observedProperty": {"$ref": "#/$defs/iri"},
        "outputPortId": identifier(), "protocolId": identifier(), "calibrationId": identifier(),
    })
    defs["actuator"] = record(["id", "componentId", "actedOnProperty", "inputPortId", "protocolId"], {
        "id": identifier(), "componentId": identifier(), "actedOnProperty": {"$ref": "#/$defs/iri"},
        "inputPortId": identifier(), "protocolId": identifier(), "transferFunctionId": identifier(),
    })
    defs["stateBinding"] = record(["id", "stateVariableId", "componentId", "stateRole"], {
        "id": identifier(), "stateVariableId": identifier(), "componentId": identifier(),
        "stateRole": {"enum": ["commanded", "observed", "estimated", "simulated"]}, "observationId": identifier(),
    })
    defs["physicalSystem"] = record(["components", "ports", "connections", "sensors", "actuators", "stateBindings"], {
        "components": array_of("#/$defs/physicalComponent"), "ports": array_of("#/$defs/physicalPort"),
        "connections": array_of("#/$defs/physicalConnection"), "sensors": array_of("#/$defs/sensor"),
        "actuators": array_of("#/$defs/actuator"), "stateBindings": array_of("#/$defs/stateBinding"),
    })

    # Deterministic runtime contract and reproducible random sources.
    defs["executionSemantics"] = record(
        ["timestampOrder", "simultaneousEventOrder", "transitionEvaluation", "actionExecution", "runToCompletion", "reentrancyPolicy", "lateEventPolicy", "timeResolution"],
        {
            "timestampOrder": {"const": "ascending"}, "simultaneousEventOrder": {"const": "priority-then-event-id"},
            "transitionEvaluation": {"const": "snapshot"}, "actionExecution": {"const": "execution-group-then-array-order"},
            "runToCompletion": {"const": True}, "reentrancyPolicy": {"enum": ["queue", "reject"]},
            "lateEventPolicy": {"enum": ["reject", "clamp", "queue-next-cycle"]}, "timeResolution": {"$ref": "#/$defs/quantityValue"},
            "maximumMicrosteps": {"type": "integer", "minimum": 1}, "voiceAllocation": {"enum": ["lowest-free-then-oldest", "round-robin", "monophonic-priority"]},
            "maximumVoices": {"type": "integer", "minimum": 1},
        },
    )
    defs["randomSource"] = record(["id", "algorithm", "seed", "stream"], {
        "id": identifier(), "algorithm": {"enum": ["pcg32", "xoshiro256-star-star"]},
        "seed": {"type": "string", "pattern": "^[0-9a-f]{16,64}$"}, "stream": {"type": "integer", "minimum": 0},
    })
    defs["renderer"] = record(["id", "name", "version", "capabilities", "softwareEnvironmentId", "sandboxPolicy"], {
        "id": identifier(), "name": {"type": "string", "minLength": 1}, "version": {"type": "string", "minLength": 1},
        "capabilities": {"type": "array", "uniqueItems": True, "items": {"$ref": "#/$defs/iri"}},
        "softwareEnvironmentId": identifier(), "sandboxPolicy": {"enum": ["declarative-only", "isolated-external-renderer"]},
        "deterministic": {"type": "boolean"},
    })
    defs["traceEvent"] = record(["timestamp", "eventTypeId", "sequence"], {
        "timestamp": {"type": "number"}, "eventTypeId": identifier(), "controlId": identifier(),
        "value": {}, "priority": {"type": "integer"}, "sequence": {"type": "integer", "minimum": 0},
    })
    defs["traceExpectation"] = record(["state", "emittedEvents", "renderBindingIds"], {
        "state": {"type": "object", "propertyNames": {"pattern": "^(urn:|https?:)"}, "additionalProperties": True},
        "emittedEvents": {"type": "array", "items": {"type": "object"}},
        "renderBindingIds": {"$ref": "#/$defs/identifierList"},
    })
    defs["conformanceTrace"] = record(["id", "inputEvents", "expected", "digest"], {
        "id": identifier(), "initialState": {"type": "object", "propertyNames": {"pattern": "^(urn:|https?:)"}, "additionalProperties": True},
        "inputEvents": array_of("#/$defs/traceEvent"), "expected": {"$ref": "#/$defs/traceExpectation"},
        "digest": {"$ref": "#/$defs/contentDigest"},
    })
    defs["runtime"] = record(["executionSemantics", "randomSources", "renderers", "conformanceTraces"], {
        "executionSemantics": {"$ref": "#/$defs/executionSemantics"}, "randomSources": array_of("#/$defs/randomSource"),
        "renderers": array_of("#/$defs/renderer"), "conformanceTraces": array_of("#/$defs/conformanceTrace"),
    })

    # Discovery/citation identifiers are repository-neutral and DataCite-ready.
    defs["fundingReference"] = record(["funderName"], {
        "funderName": {"type": "string", "minLength": 1}, "funderIdentifier": {"$ref": "#/$defs/iri"},
        "awardNumber": {"type": "string"}, "awardIRI": {"$ref": "#/$defs/iri"}, "awardTitle": {"type": "string"},
    })
    defs["discovery"] = record(["resourceType", "creatorAgentIds", "contributorAgentIds", "relatedIdentifiers", "fundingReferences", "subjects"], {
        "resourceType": {"const": "Dataset"}, "creatorAgentIds": {"$ref": "#/$defs/uniqueIdentifiers"},
        "contributorAgentIds": {"$ref": "#/$defs/identifierList"},
        "relatedIdentifiers": {"type": "array", "items": {"type": "object", "required": ["identifier", "relationType"], "properties": {"identifier": {"$ref": "#/$defs/iri"}, "relationType": {"type": "string", "minLength": 1}, "resourceType": {"type": "string"}}, "additionalProperties": False}},
        "fundingReferences": array_of("#/$defs/fundingReference"),
        "subjects": {"type": "array", "items": {"type": "object", "required": ["subject"], "properties": {"subject": {"type": "string", "minLength": 1}, "subjectScheme": {"type": "string"}, "valueIRI": {"$ref": "#/$defs/iri"}}, "additionalProperties": False}},
        "instrumentIdentifiers": {"type": "array", "uniqueItems": True, "items": {"$ref": "#/$defs/iri"}},
        "facilityIdentifiers": {"type": "array", "uniqueItems": True, "items": {"$ref": "#/$defs/iri"}},
    })

    # Upgrade interaction semantics without discarding the 0.3 registries.
    protocol = defs["protocolBinding"]
    protocol["properties"].update({
        "umpGroup": {"type": "integer", "minimum": 0, "maximum": 15},
        "functionBlock": {"type": "integer", "minimum": 0, "maximum": 31},
        "umpMessageType": {"type": "integer", "minimum": 0, "maximum": 15},
        "dataResolutionBits": {"enum": [7, 14, 16, 32]}, "perNoteControllerIndex": {"type": "integer", "minimum": 0, "maximum": 127},
        "jrTimestamp": {"type": "boolean"}, "midiCIProfileIRI": {"$ref": "#/$defs/iri"},
        "propertyExchangeResourceIRI": {"$ref": "#/$defs/iri"},
    })
    routing = defs["routingRule"]
    routing["properties"]["delayConstraintId"] = identifier()
    process = defs["processModel"]
    process["properties"].update({
        "randomSourceId": identifier(),
        "probabilityDistribution": {"type": "object", "required": ["kind", "parameters"], "properties": {
            "kind": {"enum": ["uniform", "categorical", "normal", "exponential"]},
            "parameters": {"type": "object", "minProperties": 1, "additionalProperties": {"type": "number"}},
        }, "additionalProperties": False},
    })
    process.setdefault("allOf", []).append({
        "if": {"properties": {"processKind": {"const": "stochastic"}}},
        "then": {"required": ["randomSourceId", "probabilityDistribution"]},
    })
    transfer_point = defs["transferPoint"]
    transfer_point["properties"].update({"inputs": {"type": "array", "minItems": 1, "items": {"type": "number"}}, "uncertainty": {"$ref": "#/$defs/uncertainty"}})
    transfer_function = defs["transferFunction"]
    transfer_function["properties"].update({
        "inputKinds": {"type": "array", "minItems": 1, "uniqueItems": True, "items": {"type": "string", "minLength": 1}},
        "validDomain": {"type": "array", "minItems": 1, "items": {"$ref": "#/$defs/vector2"}},
        "extrapolationPolicy": {"enum": ["reject", "clamp", "nearest", "linear"]},
        "hysteresis": {"type": "boolean"}, "dynamicModel": {"enum": ["static", "first-order", "state-space", "lookup-sequence"]},
        "fitResidual": {"$ref": "#/$defs/quantityValue"},
    })
    interaction = defs["interactionModel"]
    interaction["required"].insert(0, "executionSemantics")
    interaction["properties"]["executionSemantics"] = {"$ref": "#/$defs/executionSemantics"}
    interaction["properties"]["randomSources"] = array_of("#/$defs/randomSource")

    integrity = defs["integrity"]
    integrity["properties"].update({
        "schemaBundleDigest": {"$ref": "#/$defs/contentDigest"},
        "signatureEnvelopeRealizationId": identifier(),
    })
    return schema


def copy_descriptor(name: str) -> None:
    source = json.loads((SCHEMAS / f"{name}-0.3.schema.json").read_text(encoding="utf-8"))
    text = json.dumps(source)
    text = text.replace("/0.3/", "/0.4.0/").replace('"0.3.3"', '"0.4.0"').replace('"0.3"', '"0.4.0"')
    value = json.loads(text)
    value["$id"] = f"{BASE}/schema/{name.removeprefix('vao-')}.json"
    if "title" in value:
        value["title"] = str(value["title"]).replace("0.3.3", VERSION).replace("0.3", VERSION)
    write_json(SCHEMAS / f"{name}-{VERSION}.schema.json", value)


def write_bundle() -> None:
    artifacts = [
        f"Schemas/vao-manifest-{VERSION}.schema.json", f"Schemas/vao-context-{VERSION}.jsonld",
        f"Schemas/vao-vocabulary-{VERSION}.ttl", f"Schemas/vao-shapes-{VERSION}.ttl",
        *(f"Schemas/{name}-{VERSION}.schema.json" for name in (
            "vao-carrier", "vao-release", "vao-pack-manifest", "vao-materialization-receipt", "vao-zenodo-metadata"
        )),
        *(f"Docs/{name}" for name in (
            "VAO_STANDARD_0.4.0.md", "VAO_CONFORMANCE_0.4.0.md", "VAO_SCIENTIFIC_PROFILE_0.4.0.md",
            "VAO_MULTIMODAL_PROFILE_0.4.0.md", "VAO_PHYSICAL_INSTRUMENT_PROFILE_0.4.0.md",
            "VAO_PLAYABLE_PROFILE_0.4.0.md", "VAO_ACOUSTIC_SCENES_0.4.0.md", "VAO_ZENODO_PROFILE_0.4.0.md",
            "VAO_INTEROPERABILITY_0.4.0.md",
        )),
    ]
    records = []
    for name in artifacts:
        data = (ROOT / name).read_bytes()
        records.append({"path": name, "byteSize": len(data), "sha256": hashlib.sha256(data).hexdigest()})
    bundle = {
        "type": "VAOSpecificationBundle", "formatVersion": VERSION,
        "id": f"{BASE}/specification-bundle", "artifacts": records,
    }
    write_json(SCHEMAS / f"vao-release-bundle-{VERSION}.json", bundle)


def main() -> None:
    write_json(SCHEMAS / f"vao-manifest-{VERSION}.schema.json", build_manifest())
    for name in ("vao-carrier", "vao-release", "vao-pack-manifest", "vao-materialization-receipt", "vao-zenodo-metadata"):
        copy_descriptor(name)
    # Context, vocabulary, and SHACL are authored normative sources.  The bundle
    # is emitted only after they exist.
    required = [SCHEMAS / f"vao-context-{VERSION}.jsonld", SCHEMAS / f"vao-vocabulary-{VERSION}.ttl", SCHEMAS / f"vao-shapes-{VERSION}.ttl"]
    if all(path.is_file() for path in required):
        write_bundle()


if __name__ == "__main__":
    main()
