#!/usr/bin/env python3
"""Build the normative VAO 0.4.0 multimodal Kinoorgel conformance fixture."""

from __future__ import annotations

import json
from pathlib import Path

import vao04
from vao04_runtime import Interpreter, trace_digest


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Fixtures/VAO03/descriptors/kinoorgel-interaction.example.json"
OUTPUT = ROOT / "Fixtures/VAO04/descriptors/kinoorgel-multimodal-scientific.example.json"


def add_profile(value: dict, profile: str, capabilities: list[str]) -> None:
    if profile not in value["conformsTo"]: value["conformsTo"].append(profile)
    if profile not in {record["id"] for record in value["profiles"]}:
        value["profiles"].append({"id": profile, "version": vao04.FORMAT_VERSION, "requiredCapabilities": capabilities})


def main() -> None:
    source = json.loads(SOURCE.read_text(encoding="utf-8"))
    value = vao04.migrate_03_manifest(source)
    cap = vao04.CAPABILITY_BASE
    add_profile(value, vao04.MULTIMODAL_PROFILE, [cap + "multimodal-synchronization"])
    add_profile(value, vao04.PHYSICAL_PROFILE, [cap + "physical-system-topology"])
    add_profile(value, vao04.RUNTIME_PROFILE, [cap + "deterministic-render-trace", cap + "midi-2-ump"])

    person = "urn:vao:fixture:kinoorgel:agent:performer"
    protocol = "urn:vao:fixture:kinoorgel:protocol:measurement"
    capture = "urn:vao:fixture:kinoorgel:activity:capture"
    observation = "urn:vao:fixture:kinoorgel:observation:latency"
    analysis = "urn:vao:fixture:kinoorgel:analysis:latency"
    consent = "urn:vao:fixture:kinoorgel:consent:performer"
    scientific = value["scientific"]
    scientific["agents"].append({"id": person, "agentKind": "person", "labels": {"en": "Synthetic fixture performer"}, "roles": ["https://credit.niso.org/contributor-roles/investigation/"]})
    scientific["protocols"].append({"id": protocol, "labels": {"en": "Synchronized audio and MIDI capture"}, "procedure": "Drive the instrument from the event stream and measure physical-input to acoustic-onset delay.", "version": "1", "standardIRI": "https://www.midi.org/specifications-old/item/the-midi-1-0-specification"})
    scientific["activities"].append({"id": capture, "activityKind": "measurement", "startedAt": "2026-08-25T10:00:00Z", "endedAt": "2026-08-25T10:01:00Z", "agentIds": [person], "protocolId": protocol, "inputIds": ["urn:vao:fixture:kinoorgel:instrument"], "outputIds": ["urn:vao:fixture:kinoorgel:realization:tibia:192000", "urn:vao:fixture:kinoorgel:realization:midi"]})
    scientific["observations"].append({"id": observation, "observedProperty": "https://w3id.org/modavis/vao/vocab/quantity/input-acoustic-latency", "featureOfInterestId": "urn:vao:fixture:kinoorgel:instrument", "result": {"value": 174, "unit": "http://qudt.org/vocab/unit/MilliSEC", "uncertainty": {"kind": "standard", "value": 2.1, "unit": "http://qudt.org/vocab/unit/MilliSEC", "method": "repeated-onset-detection"}, "sampleCount": 12, "censoring": "none"}, "resultTime": "2026-08-25T10:01:00Z", "activityId": capture, "protocolId": protocol, "rawResultRealizationId": "urn:vao:fixture:kinoorgel:realization:midi", "processedResultRealizationId": "urn:vao:fixture:kinoorgel:realization:tibia:192000", "status": "accepted", "qualityFlags": []})
    scientific["analyses"].append({"id": analysis, "analysisKind": "https://w3id.org/modavis/vao/vocab/analysis/onset-latency", "activityId": capture, "inputIds": ["urn:vao:fixture:kinoorgel:realization:midi", "urn:vao:fixture:kinoorgel:realization:tibia:192000"], "outputIds": [observation], "softwareEnvironmentId": scientific["softwareEnvironments"][0]["id"], "parameters": {"https://w3id.org/modavis/vao/ontology#thresholdDB": -48}, "reproducibility": "deterministic", "fitResidual": {"value": 0.8, "unit": "http://qudt.org/vocab/unit/MilliSEC"}, "validationIds": [observation]})
    scientific["consents"].append({"id": consent, "grantedByAgentId": person, "appliesToIds": [value["id"]], "decision": "granted", "recordedAt": "2026-08-25T09:59:00Z", "conditions": {"en": "Synthetic fixture may be redistributed."}})
    value["discovery"] = {"resourceType": "Dataset", "creatorAgentIds": [person], "contributorAgentIds": [scientific["agents"][0]["id"]], "relatedIdentifiers": [{"identifier": "https://doi.org/10.0000/vao.fixture", "relationType": "IsDocumentedBy", "resourceType": "Text"}], "fundingReferences": [{"funderName": "Synthetic Fixture Fund", "funderIdentifier": "https://ror.org/00dummy000", "awardNumber": "VAO-040"}], "subjects": [{"subject": "cinema organ", "subjectScheme": "MIMO"}], "instrumentIdentifiers": ["https://example.org/mimo/instrument/cinema-organ"]}

    audio_clock = "urn:vao:fixture:kinoorgel:timebase:audio"
    midi_clock = "urn:vao:fixture:kinoorgel:timebase:midi"
    audio_track = "urn:vao:fixture:kinoorgel:track:audio"
    midi_track = "urn:vao:fixture:kinoorgel:track:midi"
    value["multimodal"] = {
        "timebases": [
            {"id": audio_clock, "kind": "media", "unit": "http://qudt.org/vocab/unit/SAMPLE", "rate": 192000, "origin": 0},
            {"id": midi_clock, "kind": "musical", "unit": "http://qudt.org/vocab/unit/UNITLESS", "rate": 960, "origin": 0},
        ],
        "tracks": [
            {"id": audio_track, "modality": "audio", "timebaseId": audio_clock, "realizationId": "urn:vao:fixture:kinoorgel:realization:tibia:192000", "continuity": "continuous"},
            {"id": midi_track, "modality": "event", "timebaseId": midi_clock, "realizationId": "urn:vao:fixture:kinoorgel:realization:midi", "continuity": "sparse"},
        ],
        "synchronizationMappings": [{"id": "urn:vao:fixture:kinoorgel:sync:midi-audio", "sourceTimebaseId": midi_clock, "targetTimebaseId": audio_clock, "method": "event-matching", "segments": [{"sourceStart": 0, "sourceEndExclusive": 960, "scale": 200, "offset": 0, "residualUncertainty": {"kind": "standard", "value": 2.1, "unit": "http://qudt.org/vocab/unit/MilliSEC", "method": "onset-fit"}, "discontinuityAfter": "none"}], "activityId": capture, "jitter": {"kind": "standard", "value": 0.4, "unit": "http://qudt.org/vocab/unit/MilliSEC", "method": "timestamp-residual"}}],
        "annotations": [{"id": "urn:vao:fixture:kinoorgel:annotation:onset", "motivation": "http://www.w3.org/ns/oa#classifying", "target": {"trackId": audio_track, "start": 0, "endExclusive": 48000, "eventLocator": "track=reg11,event=1"}, "body": {"value": "Tibia onset", "language": "en"}, "createdByAgentId": person, "createdAt": "2026-08-25T10:02:00Z", "activityId": capture}],
    }

    component_manual = "urn:vao:fixture:kinoorgel:physical:manual"
    component_rank = "urn:vao:fixture:kinoorgel:physical:tibia"
    port_key = "urn:vao:fixture:kinoorgel:port:key-output"
    port_valve = "urn:vao:fixture:kinoorgel:port:valve-input"
    value["physicalSystem"] = {
        "components": [
            {"id": component_manual, "entityId": "urn:vao:fixture:kinoorgel:manual:great", "componentKind": "https://w3id.org/modavis/vao/vocab/component/manual", "portIds": [port_key]},
            {"id": component_rank, "entityId": "urn:vao:fixture:kinoorgel:rank:tibia", "componentKind": "https://w3id.org/modavis/vao/vocab/component/pipe-rank", "portIds": [port_valve]},
        ],
        "ports": [
            {"id": port_key, "componentId": component_manual, "direction": "output", "signalKind": "control"},
            {"id": port_valve, "componentId": component_rank, "direction": "input", "signalKind": "electrical"},
        ],
        "connections": [{"id": "urn:vao:fixture:kinoorgel:connection:key-valve", "sourcePortId": port_key, "targetPortId": port_valve, "connectionKind": "signal", "delayConstraintId": "urn:vao:fixture:kinoorgel:timing:thunder-latency", "bidirectional": False}],
        "sensors": [{"id": "urn:vao:fixture:kinoorgel:sensor:midi", "componentId": component_manual, "observedProperty": "https://w3id.org/modavis/vao/vocab/quantity/key-state", "outputPortId": port_key, "protocolId": protocol}],
        "actuators": [{"id": "urn:vao:fixture:kinoorgel:actuator:valve", "componentId": component_rank, "actedOnProperty": "https://w3id.org/modavis/vao/vocab/quantity/valve-state", "inputPortId": port_valve, "protocolId": protocol}],
        "stateBindings": [{"id": "urn:vao:fixture:kinoorgel:state-binding:tibia", "stateVariableId": "urn:vao:fixture:kinoorgel:state:tibia-enabled", "componentId": component_rank, "stateRole": "commanded"}],
    }

    midi2 = {"id": "urn:vao:fixture:kinoorgel:binding:shutter-midi2", "controlId": "urn:vao:fixture:kinoorgel:control:shutter", "eventTypeId": "urn:vao:fixture:kinoorgel:event:control-on", "protocol": "MIDI-2.0", "direction": "input", "messageType": "control-change", "channel": 0, "number": 11, "channelNumberingBase": 0, "dataNumberingBase": 0, "umpGroup": 0, "functionBlock": 0, "umpMessageType": 4, "dataResolutionBits": 32, "jrTimestamp": True, "midiCIProfileIRI": "https://midi.org/midi-ci/profile/drawbar-organ", "propertyExchangeResourceIRI": "https://midi.org/midi-ci/resource/vao-state", "status": "asserted", "source": "documented"}
    value["interactionModel"]["protocolBindings"].append(midi2)
    value["rights"][0].update({"performerAgentIds": [person], "consentIds": [consent], "privacyClassification": "public", "carePrinciples": ["collective-benefit", "authority-to-control", "responsibility", "ethics"]})

    event = {"timestamp": 0, "eventTypeId": "urn:vao:fixture:kinoorgel:event:control-on", "controlId": "urn:vao:fixture:kinoorgel:control:tibia-stop", "priority": 0, "sequence": 0}
    expected = Interpreter(value).execute([event], {})
    trace = {"id": "urn:vao:fixture:kinoorgel:trace:tibia-toggle", "initialState": {}, "inputEvents": [event], "expected": expected}
    trace["digest"] = {"algorithm": "sha256", "value": trace_digest({}, [event], expected)}
    value["runtime"]["conformanceTraces"] = [trace]

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(value, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
