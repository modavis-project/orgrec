#!/usr/bin/env python3
"""Build the VAO 0.4.0 Cuntz Positiv + AcousticRooms Unity test package.

By default the fixture embeds a representative five-sample subset of the
rights-restricted Cuntz corpus. ``--full-corpus`` embeds all 225 available
source recordings (five stops across the observed 45-key manual). Both modes
also embed the newest AcousticRooms conformance scene, the current OrgRec
timbre report, a key-addressable Cuntz FBX model, legacy Unity animation evidence, and the MIDI
file from which the legacy animation workflow was derived.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
import struct
from typing import Any

import vao04
from vao04_runtime import Interpreter, trace_digest


ROOT = Path(__file__).resolve().parent.parent
ACOUSTIC_SOURCE = ROOT / "Fixtures/VAO03/valid/acousticrooms-scene"
TIMBRE_REPORT = ROOT / "Artifacts/PositivXR/TIMBRE_VALIDATION_0.2.0.json"

WORKSPACE = ROOT / "Fixtures/VAO04/valid/cuntz-positiv-acoustic-test"
DESCRIPTOR = ROOT / "Fixtures/VAO04/descriptors/cuntz-positiv-acoustic-test.example.json"
ARCHIVE = ROOT / "Artifacts/CuntzPositivVAO04/Cuntz-Positiv-Acoustic-Test-VAO-0.4.0.vao"

PREFIX = "urn:vao:test:cuntz-positiv"
MANIFEST_ID = PREFIX
RELEASE_ID = PREFIX + ":release:1"
INSTRUMENT_ID = PREFIX + ":instrument"
MANUAL_ID = PREFIX + ":manual"
RIGHTS_ID = PREFIX + ":rights:restricted"
INTEGRATION_ACTIVITY = PREFIX + ":activity:fixture-integration"
TIMBRE_ACTIVITY = PREFIX + ":activity:timbre-analysis"
INSTRUMENT_PROTOCOL = PREFIX + ":protocol:sampled-instrument"
INTEGRATOR_AGENT = PREFIX + ":agent:builder"
INTEGRATOR_SOFTWARE = PREFIX + ":software:builder"
TIMBRE_SOFTWARE = PREFIX + ":software:orgrec-0.2.0-build-2"

STOPS = [
    ("ged", "Gedackt 8′", 0, "4010243_ged_60_0.wav"),
    ("princ4", "Principal 4′", 12, "4010243_princ4_60.wav"),
    ("princ2", "Principal 2′", 24, "4010243_princ2_60.wav"),
    ("qui223", "Quint 2 2/3′", 19, "4010243_qui223_60.wav"),
    ("reg8", "Regal 8′", 0, "4010243_reg8_60.wav"),
]
OBSERVED_KEYS = [36, 38, 40, 41, 43, *range(45, 85)]


def sample_filename(token: str, note: int) -> str:
    return f"4010243_{token}_{note}{'_0' if token == 'ged' else ''}.wav"


def exact_replace(value: Any, replacements: dict[str, str]) -> Any:
    if isinstance(value, dict): return {key: exact_replace(item, replacements) for key, item in value.items()}
    if isinstance(value, list): return [exact_replace(item, replacements) for item in value]
    if isinstance(value, str): return replacements.get(value, value)
    return value


def add_profile(manifest: dict[str, Any], profile: str, capabilities: list[str]) -> None:
    if profile not in manifest["conformsTo"]: manifest["conformsTo"].append(profile)
    if profile not in {record["id"] for record in manifest["profiles"]}:
        manifest["profiles"].append({"id": profile, "version": vao04.FORMAT_VERSION, "requiredCapabilities": capabilities})


def sha256(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""): hasher.update(block)
    return hasher.hexdigest()


def wav_metadata(path: Path) -> dict[str, Any]:
    with path.open("rb") as stream:
        if stream.read(4) != b"RIFF": raise ValueError(f"Not a RIFF WAVE file: {path}")
        stream.seek(8)
        if stream.read(4) != b"WAVE": raise ValueError(f"Not a WAVE file: {path}")
        audio_format = channels = rate = block_align = bits = data_size = None
        while True:
            header = stream.read(8)
            if len(header) != 8: break
            kind, length = header[:4], struct.unpack("<I", header[4:])[0]
            data = stream.read(length)
            if length % 2: stream.read(1)
            if kind == b"fmt " and len(data) >= 16:
                audio_format, channels, rate, _, block_align, bits = struct.unpack("<HHIIHH", data[:16])
            elif kind == b"data": data_size = length
        if None in (audio_format, channels, rate, block_align, bits, data_size):
            raise ValueError(f"Incomplete WAVE metadata: {path}")
        return {
            "kind": "audio", "audioContainer": "WAVE", "sampleRate": rate,
            "channelCount": channels, "bitDepth": bits,
            "sampleFormat": "floating-point" if audio_format == 3 else "signed-integer",
            "frameCount": data_size // block_align,
        }


def logical_asset(identifier: str, label: str, roles: list[str], about: list[str], realization_id: str) -> dict[str, Any]:
    return {
        "id": identifier, "type": "LogicalAsset", "labels": {"en": label},
        "roles": roles, "aboutEntityIds": about, "realizationIds": [realization_id], "properties": {},
    }


def realization(
    identifier: str, asset_id: str, path: Path, media_type: str, technical: dict[str, Any],
    representation: str, quality: str = "preservation", provenance: list[str] | None = None,
) -> dict[str, Any]:
    digest = sha256(path)
    return {
        "id": identifier, "type": "Realization", "assetId": asset_id,
        "variantSetId": identifier.rsplit(":", 1)[-1], "qualityTier": quality,
        "mediaType": media_type, "byteSize": path.stat().st_size, "sha256": digest,
        "contentDigests": [{"algorithm": "sha256", "value": digest}],
        "representationStatus": representation, "rightsIds": [RIGHTS_ID],
        "provenanceIds": provenance or [], "technicalMetadata": technical, "distributionIds": [],
    }


def build_manifest(
    cuntz_audio: Path,
    legacy_unity: Path,
    legacy_midi: Path,
    full_corpus: bool = False,
) -> tuple[dict[str, Any], list[tuple[str, str, Path]]]:
    full_cuntz_audio = legacy_unity / "Assets/Resources/Audio"
    cuntz_model = legacy_unity / "Assets/Models/4010243_segmented_03b2.fbx"
    source = json.loads((ACOUSTIC_SOURCE / vao04.MANIFEST_NAME).read_text(encoding="utf-8"))
    old_id, old_release = source["id"], source["release"]["id"]
    manifest = exact_replace(vao04.migrate_03_manifest(source), {old_id: MANIFEST_ID, old_release: RELEASE_ID})
    manifest.update({
        "id": MANIFEST_ID,
        "release": {"id": RELEASE_ID, "revision": 1, "contentVersion": "0.4.0-unity-full-1" if full_corpus else "0.4.0-unity-test-1"},
        "createdAt": "2026-08-25T22:00:00Z", "modifiedAt": "2026-08-25T22:00:00Z",
        "title": {"en": "Cuntz Positiv in an AcousticRooms test environment"},
        "description": {"en": ("Rights-restricted local VAO 0.4.0 full-corpus integration carrier: 225 Cuntz samples across five stops and the observed 45-key manual" if full_corpus else "Rights-restricted local VAO 0.4.0 compact integration fixture: five representative Cuntz samples") + ", a key-addressable Unity model, linked MIDI and animation evidence, the current OrgRec timbre report, and the AcousticRooms S000/R0011 hybrid virtual acoustic environment."},
        "primaryEntityId": INSTRUMENT_ID,
        "focusEntityIds": [INSTRUMENT_ID, "urn:vao:fixture:acousticrooms:space"],
    })

    cap = vao04.CAPABILITY_BASE
    add_profile(manifest, vao04.PLAYABLE_PROFILE, [cap + "interaction", cap + "sampled-instrument-playback", cap + "stateful-interaction", cap + "conditional-routing"])
    add_profile(manifest, vao04.MULTIMODAL_PROFILE, [cap + "multimodal-synchronization"])
    add_profile(manifest, vao04.PHYSICAL_PROFILE, [cap + "physical-system-topology"])
    add_profile(manifest, vao04.RUNTIME_PROFILE, [cap + "deterministic-render-trace", cap + "midi-2-ump"])

    manifest["entities"].extend([
        {"id": INSTRUMENT_ID, "kind": "instrument", "types": ["https://w3id.org/modavis/ontology/instrument#PipeOrgan"], "labels": {"en": "Cuntz Positiv (source record 4010243)"}, "externalIdentifiers": [{"scheme": "SOURCE:musixplora", "value": "4010243"}], "properties": {"https://w3id.org/modavis/vao/ontology#identityStatus": "source-bound; canonical MODAVIS identity unresolved"}},
        {"id": MANUAL_ID, "kind": "component", "types": ["https://w3id.org/modavis/ontology/instrument#Manual"], "labels": {"en": "Observed 45-key manual"}, "properties": {"https://w3id.org/modavis/vao/ontology#observedMidiKeys": OBSERVED_KEYS}},
        {"id": PREFIX + ":interaction", "kind": "interaction", "types": ["https://w3id.org/modavis/vao/ontology#Interaction"], "labels": {"en": "Cuntz sampled-organ controls"}, "properties": {"https://w3id.org/modavis/vao/ontology#interactionType": "https://w3id.org/modavis/vao/vocab/interaction/stateful-control", "https://w3id.org/modavis/vao/ontology#controlProtocol": "MIDI 1.0 and MIDI 2.0", "https://w3id.org/modavis/vao/ontology#controlDomain": "45 observed keys and five independent stop toggles", "https://w3id.org/modavis/vao/ontology#timingPolicy": "event-triggered sampled playback with a 0.3-second note-off envelope prior"}},
        *[{"id": PREFIX + f":stop:{token}", "kind": "component", "types": ["https://w3id.org/modavis/ontology/instrument#Stop"], "labels": {"en": label}, "properties": {"https://w3id.org/modavis/vao/ontology#sourceToken": token, "https://w3id.org/modavis/vao/ontology#soundingSemitoneOffsetPrior": offset}} for token, label, offset, _ in STOPS],
    ])
    manifest["relations"].extend([
        {"id": PREFIX + ":relation:located-in-test-room", "subjectId": INSTRUMENT_ID, "predicate": "http://purl.org/dc/terms/spatial", "objectId": "urn:vao:fixture:acousticrooms:space", "status": "asserted", "evidenceIds": [PREFIX + ":asset:timbre-report"]},
        {"id": PREFIX + ":relation:has-manual", "subjectId": INSTRUMENT_ID, "predicate": "https://w3id.org/modavis/ontology/instrument#hasComponent", "objectId": MANUAL_ID, "status": "accepted"},
        {"id": PREFIX + ":relation:interaction", "subjectId": PREFIX + ":interaction", "predicate": "https://w3id.org/modavis/vao/ontology#activates", "objectId": INSTRUMENT_ID, "status": "accepted"},
        *[{"id": PREFIX + f":relation:has-stop:{token}", "subjectId": INSTRUMENT_ID, "predicate": "https://w3id.org/modavis/ontology/instrument#hasComponent", "objectId": PREFIX + f":stop:{token}", "status": "accepted"} for token, _, _, _ in STOPS],
    ])

    payloads: list[tuple[str, str, Path]] = []
    new_realization_ids: list[str] = []
    sample_mappings: list[dict[str, Any]] = []
    sample_variants: list[dict[str, Any]] = []
    sample_realizations: list[str] = []
    sample_ids_by_stop: dict[str, list[str]] = {token: [] for token, *_ in STOPS}
    mapping_ids_by_stop: dict[str, list[str]] = {token: [] for token, *_ in STOPS}
    selected_keys = OBSERVED_KEYS if full_corpus else [60]
    for token, label, offset, compact_filename in STOPS:
        for note in selected_keys:
            filename = sample_filename(token, note) if full_corpus else compact_filename
            source_path = (full_cuntz_audio if full_corpus else cuntz_audio) / filename
            asset_id = PREFIX + f":asset:sample:{token}:{note}"
            realization_id = PREFIX + f":realization:sample:{token}:{note}"
            stop_id = PREFIX + f":stop:{token}"
            carrier_path = f"payload/cuntz/audio/{token}/{filename}"
            manifest["logicalAssets"].append(logical_asset(asset_id, f"{label} MIDI {note} sample", ["https://w3id.org/modavis/vao/vocab/asset-role/instrument-sample", "https://w3id.org/modavis/vao/vocab/asset-role/audio-master"], [INSTRUMENT_ID, stop_id], realization_id))
            manifest["realizations"].append(realization(realization_id, asset_id, source_path, "audio/wav", wav_metadata(source_path), "https://w3id.org/modavis/vao/vocab/representation-status/captured"))
            payloads.append((realization_id, carrier_path, source_path)); new_realization_ids.append(realization_id); sample_realizations.append(realization_id); sample_ids_by_stop[token].append(realization_id)
            variant_id = PREFIX + f":variant:{token}:{note}"
            mapping_id = PREFIX + f":mapping:{token}:{note}"
            mapping_ids_by_stop[token].append(mapping_id)
            sample_variants.append({"id": variant_id, "realizationId": realization_id, "trigger": "note-on", "signalRole": "attack-sustain", "status": "accepted", "source": "documented", "sourceLocator": filename})
            sample_mappings.append({"id": mapping_id, "instrumentEntityId": INSTRUMENT_ID, "rankEntityId": stop_id, "keyRange": {"minimum": note, "maximum": note}, "velocitySensitivity": "none", "controlKeyMeaning": "played-key", "soundingKeyOffset": offset, "sampleRootKey": note, "variantIds": [variant_id], "selectionPolicy": "single", "noteOffPolicy": "envelope", "status": "accepted", "source": "documented", "sourceLocator": filename})
            manifest["relations"].append({"id": PREFIX + f":relation:sample:{token}:{note}", "subjectId": stop_id, "predicate": "https://w3id.org/modavis/vao/ontology#usesSample", "objectId": asset_id, "status": "accepted"})

    midi_asset, midi_realization = PREFIX + ":asset:midi:pachelbel", PREFIX + ":realization:midi:pachelbel"
    anim_source = legacy_unity / "Assets/Animations/pachelbel.anim"
    anim_asset, anim_realization = PREFIX + ":asset:animation:pachelbel", PREFIX + ":realization:animation:pachelbel"
    model_asset, model_realization = PREFIX + ":asset:model:keyboard", PREFIX + ":realization:model:keyboard"
    report_asset, report_realization = PREFIX + ":asset:timbre-report", PREFIX + ":realization:timbre-report"
    for asset in [
        logical_asset(midi_asset, "Pachelbel MIDI performance source", ["https://w3id.org/modavis/vao/vocab/asset-role/capture-event-log", "https://w3id.org/modavis/vao/vocab/asset-role/animation-source"], [INSTRUMENT_ID], midi_realization),
        logical_asset(anim_asset, "Legacy Unity key animation", ["https://w3id.org/modavis/vao/vocab/asset-role/animation", "https://w3id.org/modavis/vao/vocab/asset-role/source-evidence"], [INSTRUMENT_ID, MANUAL_ID], anim_realization),
        logical_asset(model_asset, "Cuntz Positiv key-addressable Unity FBX", ["https://w3id.org/modavis/vao/vocab/asset-role/three-dimensional-model", "https://w3id.org/modavis/vao/vocab/asset-role/spatial-model"], [INSTRUMENT_ID, MANUAL_ID], model_realization),
        logical_asset(report_asset, "OrgRec full-corpus timbre validation", ["https://w3id.org/modavis/vao/vocab/asset-role/analysis-result"], [INSTRUMENT_ID], report_realization),
    ]: manifest["logicalAssets"].append(asset)

    animation_clock = PREFIX + ":timebase:animation"
    midi_clock = PREFIX + ":timebase:midi"
    new_realizations = [
        realization(midi_realization, midi_asset, legacy_midi, "audio/midi", {"kind": "event-stream", "eventEncoding": "Standard MIDI File type 0; 96 PPQN", "timebaseId": midi_clock}, "https://w3id.org/modavis/vao/vocab/representation-status/authored"),
        realization(anim_realization, anim_asset, anim_source, "application/vnd.unity.animation+yaml", {"kind": "motion-capture", "timebaseId": animation_clock}, "https://w3id.org/modavis/vao/vocab/representation-status/derived"),
        realization(model_realization, model_asset, cuntz_model, "application/vnd.autodesk.fbx", {"kind": "geometry", "coordinateFrameId": PREFIX + ":frame:model", "coordinateUnit": "http://qudt.org/vocab/unit/M", "handedness": "right", "upAxis": "Y", "lod": 0, "purposeLimitations": ["Source scale has not been verified by physical survey.", "The legacy model exposes 45 M1 key transforms; performance notes outside MIDI 36–84 are intentionally not animated."]}, "https://w3id.org/modavis/vao/vocab/representation-status/derived", "production"),
        realization(report_realization, report_asset, TIMBRE_REPORT, "application/json", {"kind": "data"}, "https://w3id.org/modavis/vao/vocab/representation-status/derived", provenance=[TIMBRE_ACTIVITY]),
    ]
    manifest["realizations"].extend(new_realizations)
    for realization_id, carrier_path, source_path in [
        (midi_realization, "payload/cuntz/animation/pachelbel.mid", legacy_midi),
        (anim_realization, "payload/cuntz/animation/pachelbel.anim", anim_source),
        (model_realization, "payload/cuntz/models/4010243_segmented_03b2.fbx", cuntz_model),
        (report_realization, "payload/cuntz/evidence/TIMBRE_VALIDATION_0.2.0.json", TIMBRE_REPORT),
    ]:
        payloads.append((realization_id, carrier_path, source_path)); new_realization_ids.append(realization_id)

    manifest["relations"].extend([
        {"id": PREFIX + ":relation:model", "subjectId": INSTRUMENT_ID, "predicate": "https://w3id.org/modavis/vao/ontology#hasRepresentation", "objectId": model_asset, "status": "accepted"},
        {"id": PREFIX + ":relation:midi-drives-animation", "subjectId": midi_asset, "predicate": "https://w3id.org/modavis/vao/ontology#drivesAnimation", "objectId": anim_asset, "status": "accepted", "properties": {"https://w3id.org/modavis/vao/unity#targetPathPattern": "M1.{midiNote}", "https://w3id.org/modavis/vao/unity#minimumMidiNote": 36, "https://w3id.org/modavis/vao/unity#maximumMidiNote": 84, "https://w3id.org/modavis/vao/unity#outOfRangePolicy": "ignore", "https://w3id.org/modavis/vao/unity#rotationAxis": "x", "https://w3id.org/modavis/vao/unity#pressedAngleDegrees": -4.0}},
        {"id": PREFIX + ":relation:animation-target", "subjectId": anim_asset, "predicate": "https://w3id.org/modavis/vao/ontology#targetsAnimation", "objectId": model_asset, "status": "accepted"},
    ])

    manifest["playable"] = {"sampleMappings": sample_mappings, "sampleVariants": sample_variants, "signalRegions": [], "loopPointSets": [], "perspectiveGroups": [], "tuningMaps": []}
    semantics = copy.deepcopy(manifest["runtime"]["executionSemantics"])
    note_on, note_off, control_on = PREFIX + ":event:note-on", PREFIX + ":event:note-off", PREFIX + ":event:control-on"
    key_control = PREFIX + ":control:key"
    controls = [{"id": key_control, "entityId": MANUAL_ID, "labels": {"en": "Manual key"}, "valueType": "integer", "controlBehavior": "gate", "minimumValue": 36, "maximumValue": 84, "status": "accepted", "source": "documented"}]
    event_types = [
        {"id": note_on, "labels": {"en": "Note on"}, "eventKind": "note-on", "valueDomain": "midi-key", "status": "accepted", "source": "documented"},
        {"id": note_off, "labels": {"en": "Note off"}, "eventKind": "note-off", "valueDomain": "midi-key", "status": "accepted", "source": "documented"},
        {"id": control_on, "labels": {"en": "Stop toggle"}, "eventKind": "control-on", "valueDomain": "boolean", "status": "accepted", "source": "documented"},
    ]
    states: list[dict[str, Any]] = []
    transitions: list[dict[str, Any]] = []
    render_bindings: list[dict[str, Any]] = []
    routing_rules: list[dict[str, Any]] = []
    # VAO 0.4.0 deliberately requires a concrete data number for MIDI note
    # bindings.  Describe the complete compass with one binding per observed
    # note instead of relying on an implementation-specific wildcard.
    binding_notes = selected_keys if full_corpus else [60]
    protocol_bindings = []
    for note in binding_notes:
        suffix = f":{note}" if full_corpus else ""
        protocol_bindings.extend([
            {"id": PREFIX + ":binding:key-midi1" + suffix, "controlId": key_control, "eventTypeId": note_on, "protocol": "MIDI-1.0", "direction": "input", "messageType": "note", "channel": 1, "number": note, "channelNumberingBase": 1, "dataNumberingBase": 0, "status": "accepted", "source": "documented"},
            {"id": PREFIX + ":binding:key-midi2" + suffix, "controlId": key_control, "eventTypeId": note_on, "protocol": "MIDI-2.0", "direction": "input", "messageType": "note", "channel": 0, "number": note, "channelNumberingBase": 0, "dataNumberingBase": 0, "umpGroup": 0, "functionBlock": 0, "umpMessageType": 4, "dataResolutionBits": 32, "jrTimestamp": True, "status": "accepted", "source": "documented"},
        ])
    for index, (token, label, offset, _) in enumerate(STOPS, 1):
        stop_id = PREFIX + f":stop:{token}"
        control_id = PREFIX + f":control:stop:{token}"
        state_id = PREFIX + f":state:stop:{token}"
        controls.append({"id": control_id, "entityId": stop_id, "labels": {"en": label}, "valueType": "boolean", "controlBehavior": "toggle", "defaultValue": False, "status": "accepted", "source": "documented"})
        states.append({"id": state_id, "labels": {"en": f"{label} enabled"}, "subjectEntityId": stop_id, "valueType": "boolean", "persistence": "latched", "defaultValue": False, "status": "accepted", "source": "documented"})
        transitions.append({"id": PREFIX + f":transition:stop:{token}", "controlId": control_id, "eventTypeId": control_on, "actions": [{"operation": "toggle-state", "targetId": state_id}], "atomic": True, "conflictPolicy": "last-event-wins", "status": "accepted", "source": "documented"})
        render_bindings.append({"id": PREFIX + f":render:{token}", "eventTypeId": note_on, "conditions": [{"stateVariableId": state_id, "operator": "equals", "value": True}], "sampleMappingIds": mapping_ids_by_stop[token], "selectionPolicy": "state-dependent", "status": "accepted", "source": "documented"})
        routing_rules.append({"id": PREFIX + f":route:{token}", "sourceControlId": key_control, "sourceEntityId": MANUAL_ID, "targetEntityId": stop_id, "routingBehavior": "activates", "inputKeyMeaning": "played-key", "outputKeyMeaning": "sounding-key", "inputRange": {"minimum": min(selected_keys), "maximum": max(selected_keys)}, "keyTransform": {"kind": "transpose", "semitoneOffset": offset}, "conditions": [{"stateVariableId": state_id, "operator": "equals", "value": True}], "status": "accepted", "source": "documented"})
        protocol_bindings.append({"id": PREFIX + f":binding:stop:{token}", "controlId": control_id, "eventTypeId": control_on, "protocol": "MIDI-1.0", "direction": "input", "messageType": "program-change", "channel": 1, "number": index, "channelNumberingBase": 1, "dataNumberingBase": 0, "activationValue": 1, "deactivationValue": 0, "status": "accepted", "source": "documented"})
    manifest["interactionModel"] = {"controls": controls, "eventTypes": event_types, "stateVariables": states, "transitions": transitions, "routingRules": routing_rules, "processModels": [], "timingConstraints": [], "transferFunctions": [], "protocolBindings": protocol_bindings, "renderBindings": render_bindings, "executionSemantics": semantics, "randomSources": []}
    manifest["captureDocumentation"] = {"captureStates": [], "takeSets": [], "eventAlignments": [], "derivationMaps": []}

    manifest["multimodal"] = {
        "timebases": [{"id": midi_clock, "kind": "musical", "unit": "http://qudt.org/vocab/unit/UNITLESS", "rate": 96, "origin": 0}, {"id": animation_clock, "kind": "media", "unit": "http://qudt.org/vocab/unit/SEC", "rate": 60, "origin": 0}],
        "tracks": [{"id": PREFIX + ":track:midi", "modality": "event", "timebaseId": midi_clock, "realizationId": midi_realization, "continuity": "sparse"}, {"id": PREFIX + ":track:animation", "modality": "motion-capture", "timebaseId": animation_clock, "realizationId": anim_realization, "coordinateFrameId": PREFIX + ":frame:model", "continuity": "continuous"}],
        "synchronizationMappings": [],
        "annotations": [{"id": PREFIX + ":annotation:animation-link", "motivation": "http://www.w3.org/ns/oa#linking", "target": {"trackId": PREFIX + ":track:animation", "eventLocator": "Unity transform curves on M1.<MIDI note>"}, "body": {"value": "MIDI note gates drive keyboard-key X rotation.", "language": "en"}, "createdByAgentId": INTEGRATOR_AGENT, "createdAt": "2026-08-25T22:00:00Z", "activityId": INTEGRATION_ACTIVITY}],
    }

    manual_component = PREFIX + ":physical:manual"
    key_port = PREFIX + ":port:key-output"
    components = [{"id": manual_component, "entityId": MANUAL_ID, "componentKind": "https://w3id.org/modavis/vao/vocab/component/manual", "portIds": [key_port]}]
    ports = [{"id": key_port, "componentId": manual_component, "direction": "output", "signalKind": "control"}]
    connections: list[dict[str, Any]] = []
    actuators: list[dict[str, Any]] = []
    state_bindings: list[dict[str, Any]] = []
    for token, _, _, _ in STOPS:
        component_id, port_id = PREFIX + f":physical:stop:{token}", PREFIX + f":port:stop:{token}"
        components.append({"id": component_id, "entityId": PREFIX + f":stop:{token}", "componentKind": "https://w3id.org/modavis/vao/vocab/component/pipe-rank", "portIds": [port_id]})
        ports.append({"id": port_id, "componentId": component_id, "direction": "input", "signalKind": "digital"})
        connections.append({"id": PREFIX + f":connection:{token}", "sourcePortId": key_port, "targetPortId": port_id, "connectionKind": "signal", "bidirectional": False})
        actuators.append({"id": PREFIX + f":actuator:{token}", "componentId": component_id, "actedOnProperty": "https://w3id.org/modavis/vao/vocab/quantity/sample-voice-state", "inputPortId": port_id, "protocolId": INSTRUMENT_PROTOCOL})
        state_bindings.append({"id": PREFIX + f":state-binding:{token}", "stateVariableId": PREFIX + f":state:stop:{token}", "componentId": component_id, "stateRole": "simulated"})
    manifest["physicalSystem"] = {"components": components, "ports": ports, "connections": connections, "sensors": [{"id": PREFIX + ":sensor:midi", "componentId": manual_component, "observedProperty": "https://w3id.org/modavis/vao/vocab/quantity/key-state", "outputPortId": key_port, "protocolId": INSTRUMENT_PROTOCOL}], "actuators": actuators, "stateBindings": state_bindings}

    report = json.loads(TIMBRE_REPORT.read_text(encoding="utf-8"))
    builder_digest = sha256(Path(__file__))
    manifest["scientific"]["agents"].append({"id": INTEGRATOR_AGENT, "agentKind": "software-agent", "labels": {"en": "Cuntz VAO 0.4.0 fixture builder"}})
    manifest["scientific"]["protocols"].append({"id": INSTRUMENT_PROTOCOL, "labels": {"en": "Source-audited sampled-instrument mapping"}, "procedure": ("Retain every available source recording across all five stops and 45 observed keys" if full_corpus else "Retain one representative MIDI 60 sample per documented Cuntz stop") + "; preserve recorded pitch; bind source MIDI and Unity animation without executing active content.", "version": "1"})
    manifest["scientific"]["softwareEnvironments"].extend([
        {"id": INTEGRATOR_SOFTWARE, "name": "build_cuntz_positiv_vao04.py", "version": "0.4.0", "identity": {"algorithm": "sha256", "value": builder_digest}},
        {"id": TIMBRE_SOFTWARE, "name": "OrgRec", "version": "0.2.0 build 2", "identity": {"algorithm": "sha256", "value": report["parameterSHA256"]}, "extensions": {"https://w3id.org/modavis/vao/ontology#identityScope": "Frozen timbre-analysis parameter identity; executable digest was not recorded in the report."}},
    ])
    manifest["scientific"]["activities"].extend([
        {"id": INTEGRATION_ACTIVITY, "activityKind": "processing", "startedAt": "2026-08-25T22:00:00Z", "endedAt": "2026-08-25T22:00:00Z", "agentIds": [INTEGRATOR_AGENT], "protocolId": INSTRUMENT_PROTOCOL, "softwareEnvironmentId": INTEGRATOR_SOFTWARE, "inputIds": new_realization_ids, "outputIds": [RELEASE_ID], "notes": "Local integration fixture assembly; source packages were read only."},
        {"id": TIMBRE_ACTIVITY, "activityKind": "inference", "startedAt": report["generatedAt"], "endedAt": report["generatedAt"], "agentIds": [INTEGRATOR_AGENT], "protocolId": INSTRUMENT_PROTOCOL, "softwareEnvironmentId": TIMBRE_SOFTWARE, "inputIds": sample_realizations, "outputIds": [report_realization], "parameterValues": {"https://w3id.org/modavis/vao/ontology#parameterSHA256": report["parameterSHA256"], "https://w3id.org/modavis/vao/ontology#referenceA4Hz": report["referenceA4Hz"]}, "notes": "The embedded report covers the complete 225-file corpus; " + ("all analyzed source inputs are embedded." if full_corpus else "this compact carrier embeds five representative inputs only.")},
    ])
    manifest["scientific"]["analyses"].append({"id": PREFIX + ":analysis:timbre", "analysisKind": "https://w3id.org/modavis/vao/vocab/analysis/timbre-family-validation", "activityId": TIMBRE_ACTIVITY, "inputIds": sample_realizations, "outputIds": [report_realization], "softwareEnvironmentId": TIMBRE_SOFTWARE, "parameters": {"https://w3id.org/modavis/vao/ontology#parameterSHA256": report["parameterSHA256"], "https://w3id.org/modavis/vao/ontology#methodology": report["methodologyAlgorithm"]}, "reproducibility": "deterministic"})

    manifest["acoustics"]["coordinateFrames"].append({"id": PREFIX + ":frame:model", "dimension": 3, "coordinateType": "cartesian", "unit": "http://qudt.org/vocab/unit/M", "handedness": "right", "upAxis": "+Y", "forwardAxis": "+Z", "notes": "glTF runtime frame; source model scale is not a verified physical survey."})
    manifest["acoustics"]["poses"].append({"id": PREFIX + ":pose:instrument", "subjectId": INSTRUMENT_ID, "frameId": "urn:vao:fixture:acousticrooms:frame:dataset", "position": [2.3496, 0.7269, 0.0], "orientationXYZW": [0, 0, 0, 1], "interpolation": "none", "generatedById": INTEGRATION_ACTIVITY})
    manifest["acoustics"]["geometryBindings"].append({"id": PREFIX + ":geometry-binding:model", "subjectId": INSTRUMENT_ID, "logicalAssetId": model_asset, "role": "runtime-visual", "generatedById": INTEGRATION_ACTIVITY})

    event = {"timestamp": 0, "eventTypeId": control_on, "controlId": PREFIX + ":control:stop:ged", "priority": 0, "sequence": 0}
    expected = Interpreter(manifest).execute([event], {})
    trace = {"id": PREFIX + ":trace:gedackt-toggle", "initialState": {}, "inputEvents": [event], "expected": expected}
    trace["digest"] = {"algorithm": "sha256", "value": trace_digest({}, [event], expected)}
    manifest["runtime"]["conformanceTraces"] = [trace]
    manifest["runtime"]["renderers"] = [{"id": PREFIX + ":renderer:unity", "name": "VAO Unity Plugin", "version": "0.2.0", "capabilities": [cap + "sampled-instrument-playback", cap + "stateful-interaction", cap + "conditional-routing", cap + "midi-2-ump", cap + "visual-acoustic-scene", cap + "position-registered-acoustic-scene", cap + "simulated-impulse-response", cap + "linked-animation"], "softwareEnvironmentId": INTEGRATOR_SOFTWARE, "sandboxPolicy": "declarative-only", "deterministic": True}]

    record_by_id = {record["id"]: record for record in manifest["realizations"]}
    support_ids = [midi_realization, anim_realization, model_realization, report_realization]
    support_group = PREFIX + ":group:unity-support"
    manifest["assetGroups"].append({"id": support_group, "type": "AssetGroup", "labels": {"en": "Cuntz Unity model, animation, and evidence"}, "selectionSetId": "cuntz-unity-support", "qualityTier": "production", "availability": "offline-required", "selectionPolicy": "independent", "realizationIds": support_ids, "dependsOnGroupIds": [manifest["assetGroups"][0]["id"]], "totalByteSize": sum(record_by_id[item]["byteSize"] for item in support_ids), "requiredCapabilities": [cap + "multimodal-synchronization", cap + "physical-system-topology", cap + "deterministic-render-trace"], "materializesProfileIds": [vao04.MULTIMODAL_PROFILE, vao04.PHYSICAL_PROFILE, vao04.RUNTIME_PROFILE], "cachePolicy": {"evictable": False, "priority": 100}})
    for token, label, _, _ in STOPS:
        ids = sample_ids_by_stop[token]
        manifest["assetGroups"].append({"id": PREFIX + f":group:samples:{token}", "type": "AssetGroup", "labels": {"en": f"{label} sampled compass"}, "selectionSetId": "cuntz-stop-samples", "qualityTier": "production", "availability": "offline-required", "selectionPolicy": "independent", "realizationIds": ids, "dependsOnGroupIds": [support_group], "totalByteSize": sum(record_by_id[item]["byteSize"] for item in ids), "requiredCapabilities": [cap + "sampled-instrument-playback"], "materializesProfileIds": [vao04.PLAYABLE_PROFILE], "cachePolicy": {"evictable": True, "priority": 80}})

    applies_to = [MANIFEST_ID, INSTRUMENT_ID, MANUAL_ID, *[PREFIX + f":stop:{token}" for token, _, _, _ in STOPS], *[item["id"] for item in manifest["logicalAssets"] if item["id"].startswith(PREFIX)], *new_realization_ids]
    manifest["rights"].append({"id": RIGHTS_ID, "appliesToIds": applies_to, "statement": {"en": "Cuntz source bytes are embedded for local, rights-restricted interoperability testing only. No redistribution license, performer consent, or canonical historical identity is inferred."}, "access": "restricted", "privacyClassification": "restricted"})
    manifest["discovery"].update({"resourceType": "Dataset", "contributorAgentIds": sorted(set(manifest["discovery"].get("contributorAgentIds", []) + [INTEGRATOR_AGENT])), "subjects": manifest["discovery"].get("subjects", []) + [{"subject": "Cuntz Positiv"}, {"subject": "Unity VAO interoperability"}], "instrumentIdentifiers": ["SOURCE:musixplora:4010243"]})
    return manifest, payloads


def build(
    workspace: Path,
    descriptor: Path,
    archive: Path,
    cuntz_audio: Path,
    legacy_unity: Path,
    legacy_midi: Path,
    full_corpus: bool = False,
) -> dict[str, Any]:
    for target in (workspace, descriptor, archive):
        if target.exists(): raise vao04.VAO04Error(f"Output already exists: {target}")
    source_audio = legacy_unity / "Assets/Resources/Audio" if full_corpus else cuntz_audio
    required = [
        ACOUSTIC_SOURCE,
        source_audio,
        legacy_unity / "Assets/Models/4010243_segmented_03b2.fbx",
        legacy_unity / "Assets/Animations/pachelbel.anim",
        legacy_midi,
        TIMBRE_REPORT,
    ]
    missing = [path for path in required if not path.exists()]
    if missing: raise vao04.VAO04Error("Missing source: " + ", ".join(str(path) for path in missing))
    manifest, payloads = build_manifest(cuntz_audio, legacy_unity, legacy_midi, full_corpus)
    shutil.copytree(ACOUSTIC_SOURCE, workspace)
    carrier = json.loads((workspace / vao04.CARRIER_NAME).read_text(encoding="utf-8"))
    for realization_id, carrier_path, source_path in payloads:
        target = workspace / carrier_path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source_path, target)
        carrier["embeddedRealizations"].append({"realizationId": realization_id, "path": carrier_path})
    carrier.update({"$schema": vao04.BASE + "/schema/carrier.json", "formatVersion": vao04.FORMAT_VERSION, "releaseId": RELEASE_ID, "carrierMode": "preservation-closure", "completeGroupIds": [item["id"] for item in manifest["assetGroups"]]})
    vao04.write_json(workspace / vao04.MANIFEST_NAME, manifest)
    manifest_data = (workspace / vao04.MANIFEST_NAME).read_bytes()
    carrier["manifestSHA256"] = hashlib.sha256(manifest_data).hexdigest()
    carrier["manifestByteSize"] = len(manifest_data)
    vao04.write_json(workspace / vao04.CARRIER_NAME, carrier)
    report = vao04.validate_workspace(workspace)
    if not report["valid"]: raise vao04.VAO04Error("Generated workspace is invalid: " + "; ".join(report["errors"][:12]))
    descriptor.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(workspace / vao04.MANIFEST_NAME, descriptor)
    archive.parent.mkdir(parents=True, exist_ok=True)
    vao04.pack_workspace(workspace, archive)
    return vao04.validate_archive(archive)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, default=WORKSPACE)
    parser.add_argument("--descriptor", type=Path, default=DESCRIPTOR)
    parser.add_argument("--archive", type=Path, default=ARCHIVE)
    parser.add_argument("--cuntz-audio", type=Path, required=True, help="Directory containing the compact Cuntz WAV subset.")
    parser.add_argument("--legacy-unity", type=Path, required=True, help="Root of the locally held legacy Unity project.")
    parser.add_argument("--legacy-midi", type=Path, required=True, help="Path to the locally held source MIDI file.")
    parser.add_argument("--full-corpus", action="store_true", help="Embed all 225 locally available Cuntz source recordings instead of the compact five-sample test set.")
    args = parser.parse_args()
    try:
        report = build(
            args.workspace,
            args.descriptor,
            args.archive,
            args.cuntz_audio,
            args.legacy_unity,
            args.legacy_midi,
            args.full_corpus,
        )
    except (OSError, ValueError, vao04.VAO04Error) as exc:
        print(f"build-cuntz-positiv-vao04: {exc}")
        return 2
    print(json.dumps({"workspace": str(args.workspace), "descriptor": str(args.descriptor), "archive": str(args.archive), **report}, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__": raise SystemExit(main())
