#!/usr/bin/env python3
"""Positive, negative, migration, runtime, RDF, interop, and carrier tests for VAO 0.4.0."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import shutil
import tempfile

import vao04
import vao04_interop
import vao04_rdf
from vao04_runtime import Interpreter, trace_digest, verify_trace


ROOT = Path(__file__).resolve().parent.parent
FIXTURE = ROOT / "Fixtures/VAO04/descriptors/kinoorgel-multimodal-scientific.example.json"
SOURCE03 = ROOT / "Fixtures/VAO03/valid/embedded-private"
ACOUSTIC_SOURCE03 = ROOT / "Fixtures/VAO03/valid/acousticrooms-scene"


def fixture() -> dict:
    return json.loads(FIXTURE.read_text(encoding="utf-8"))


def outcome(name: str, passed: bool, detail: str = "") -> tuple[str, bool, str]:
    return name, passed, detail or ("ok" if passed else "failed")


def reject(name: str, mutate) -> tuple[str, bool, str]:
    value = fixture(); mutate(value); report = vao04.validate_manifest(value)
    return outcome(name, not report["valid"], report["errors"][0] if report["errors"] else "unexpectedly valid")


def manifest_cases() -> list[tuple[str, bool, str]]:
    value = fixture(); report = vao04.validate_manifest(value)
    cases = [outcome("multimodal Kinoorgel fixture", report["valid"], "; ".join(report["errors"][:2]))]
    cases += [
        reject("immutable schema namespace", lambda m: m.__setitem__("$schema", "https://w3id.org/modavis/vao/0.4/schema/manifest.json")),
        reject("immutable context namespace", lambda m: m.__setitem__("@context", ["https://w3id.org/modavis/vao/0.4/context.jsonld"])),
        reject("exact format version", lambda m: m.__setitem__("formatVersion", "0.4")),
        reject("closed root", lambda m: m.__setitem__("script", "unsafe()")),
        reject("typed analysis required", lambda m: m["scientific"]["analyses"].append({"id": "urn:minimal", "script": "opaque()"})),
        reject("analysis activity resolves", lambda m: m["scientific"]["analyses"][0].__setitem__("activityId", "urn:missing")),
        reject("seeded analysis resolves random source", lambda m: (m["scientific"]["analyses"][0].__setitem__("reproducibility", "seeded"), m["scientific"]["analyses"][0].__setitem__("randomSourceId", "urn:missing"))),
        reject("claim exactly-one value", lambda m: m["scientific"]["claims"].append({"id": "urn:claim", "subjectId": m["id"], "predicate": "https://example.org/p", "objectId": m["id"], "literal": {"value": "also"}, "status": "asserted", "evidenceIds": [m["scientific"]["observations"][0]["id"]]})),
        reject("consent agent resolves", lambda m: m["scientific"]["consents"][0].__setitem__("grantedByAgentId", "urn:missing")),
        reject("track timebase resolves", lambda m: m["multimodal"]["tracks"][0].__setitem__("timebaseId", "urn:missing")),
        reject("clock segments do not overlap", lambda m: m["multimodal"]["synchronizationMappings"][0]["segments"].append(copy.deepcopy(m["multimodal"]["synchronizationMappings"][0]["segments"][0]))),
        reject("clock mapping cannot self-map", lambda m: m["multimodal"]["synchronizationMappings"][0].__setitem__("targetTimebaseId", m["multimodal"]["synchronizationMappings"][0]["sourceTimebaseId"])),
        reject("annotation track resolves", lambda m: m["multimodal"]["annotations"][0]["target"].__setitem__("trackId", "urn:missing")),
        reject("physical port component resolves", lambda m: m["physicalSystem"]["ports"][0].__setitem__("componentId", "urn:missing")),
        reject("physical connection ports resolve", lambda m: m["physicalSystem"]["connections"][0].__setitem__("targetPortId", "urn:missing")),
        reject("sensor protocol resolves", lambda m: m["physicalSystem"]["sensors"][0].__setitem__("protocolId", "urn:missing")),
        reject("MIDI 2 UMP group required", lambda m: next(x for x in m["interactionModel"]["protocolBindings"] if x["protocol"] == "MIDI-2.0").pop("umpGroup")),
        reject("MIDI 2 JR timestamp required", lambda m: next(x for x in m["interactionModel"]["protocolBindings"] if x["protocol"] == "MIDI-2.0").__setitem__("jrTimestamp", False)),
        reject("stochastic process declares distribution", lambda m: (m["interactionModel"]["processModels"][0].__setitem__("processKind", "stochastic"), m["interactionModel"]["processModels"][0].__setitem__("ordering", "stochastic"))),
        reject("transfer domain non-empty", lambda m: m["interactionModel"]["transferFunctions"][0].update({"validDomain": [[1, 1]], "extrapolationPolicy": "reject"})),
        reject("content digest agrees with sha256", lambda m: m["realizations"][0].__setitem__("contentDigests", [{"algorithm": "sha256", "value": "0" * 64}])),
        reject("chunk indices contiguous", lambda m: m["realizations"][0].__setitem__("chunking", {"strategy": "fixed-size", "chunks": [{"index": 1, "offset": 0, "length": m["realizations"][0]["byteSize"], "digest": {"algorithm": "sha256", "value": m["realizations"][0]["sha256"]}}]})),
        reject("Merkle root follows canonical tree", lambda m: m["realizations"][0].__setitem__("chunking", {"strategy": "fixed-size", "merkleRoot": {"algorithm": "sha256", "value": "0" * 64}, "chunks": [{"index": 0, "offset": 0, "length": m["realizations"][0]["byteSize"], "digest": {"algorithm": "sha256", "value": m["realizations"][0]["sha256"]}}]})),
        reject("rights consent resolves", lambda m: m["rights"][0].__setitem__("consentIds", ["urn:missing"])),
        reject("community authority required", lambda m: m["rights"][0].__setitem__("privacyClassification", "community-governed")),
        reject("discovery creator resolves", lambda m: m["discovery"].__setitem__("creatorAgentIds", ["urn:missing"])),
        reject("scientific profile required", lambda m: (m.__setitem__("profiles", [x for x in m["profiles"] if x["id"] != vao04.SCIENTIFIC_PROFILE]), m.__setitem__("conformsTo", [x for x in m["conformsTo"] if x != vao04.SCIENTIFIC_PROFILE]))),
        reject("multimodal profile required", lambda m: (m.__setitem__("profiles", [x for x in m["profiles"] if x["id"] != vao04.MULTIMODAL_PROFILE]), m.__setitem__("conformsTo", [x for x in m["conformsTo"] if x != vao04.MULTIMODAL_PROFILE]))),
        reject("runtime profile required for traces", lambda m: (m.__setitem__("profiles", [x for x in m["profiles"] if x["id"] != vao04.RUNTIME_PROFILE]), m.__setitem__("conformsTo", [x for x in m["conformsTo"] if x != vao04.RUNTIME_PROFILE]))),
    ]
    return cases


def trace_cases() -> list[tuple[str, bool, str]]:
    value = fixture(); trace = value["runtime"]["conformanceTraces"][0]
    result = Interpreter(value).execute(trace["inputEvents"], trace.get("initialState"))
    cases = [outcome("reference interpreter matches golden trace", result == trace["expected"])]
    cases.append(outcome("canonical trace digest verifies", not verify_trace(value, trace)))
    corrupted = copy.deepcopy(trace); corrupted["expected"]["state"]["urn:vao:fixture:kinoorgel:state:tibia-enabled"] = False
    cases.append(outcome("trace tampering rejected", bool(verify_trace(value, corrupted))))
    return cases


def linked_data_cases() -> list[tuple[str, bool, str]]:
    value = fixture(); projected = vao04_rdf.project_jsonld(value)
    context = json.loads((ROOT / "Schemas/vao-context-0.4.0.jsonld").read_text(encoding="utf-8"))
    opaque = [key for key, item in context["@context"].items() if isinstance(item, dict) and item.get("@type") == "@json"]
    return [
        outcome("context has no opaque @json domain records", not opaque, str(opaque)),
        outcome("JSON-LD projection is lossless", vao04_rdf.inverse_projection(projected) == value),
        outcome("scientific observations are RDF nodes", projected["scientific"]["observations"][0]["type"] == "http://www.w3.org/ns/sosa/Observation"),
        outcome("SHACL shapes published", "sh:NodeShape" in (ROOT / "Schemas/vao-shapes-0.4.0.ttl").read_text(encoding="utf-8")),
    ]


def interop_cases() -> list[tuple[str, bool, str]]:
    value = fixture()
    return [
        outcome("RO-Crate projection", any(x.get("@type") == "File" for x in vao04_interop.ro_crate(value)["@graph"])),
        outcome("DataCite 4 projection", vao04_interop.datacite(value)["data"]["attributes"]["creators"][0]["name"] == "Synthetic fixture performer"),
        outcome("IIIF Presentation projection", len(vao04_interop.iiif_presentation(value)["items"]) == 2),
        outcome("OCFL inventory projection", vao04_interop.ocfl_inventory(value)["head"] == "v1"),
    ]


def bundle_cases() -> list[tuple[str, bool, str]]:
    bundle = json.loads((ROOT / "Schemas/vao-release-bundle-0.4.0.json").read_text(encoding="utf-8")); cases = []
    for record in bundle["artifacts"]:
        data = (ROOT / record["path"]).read_bytes()
        cases.append(outcome(f"bundle digest {record['path']}", len(data) == record["byteSize"] and hashlib.sha256(data).hexdigest() == record["sha256"]))
    return cases


def carrier_cases() -> list[tuple[str, bool, str]]:
    cases = []
    with tempfile.TemporaryDirectory() as temporary:
        root = Path(temporary); workspace = root / "fixture"; archive = root / "fixture.vao"
        vao04.migrate_03_workspace(SOURCE03, workspace)
        report = vao04.validate_workspace(workspace); cases.append(outcome("0.3.3 workspace migration", report["valid"], "; ".join(report["errors"][:2])))
        manifest = json.loads((workspace / vao04.MANIFEST_NAME).read_text(encoding="utf-8")); carrier = json.loads((workspace / vao04.CARRIER_NAME).read_text(encoding="utf-8"))
        payload = (workspace / "payload/evidence/source.txt").read_bytes(); digest = hashlib.sha256(payload).hexdigest()
        chunks = [{"index": 0, "offset": 0, "length": len(payload), "digest": {"algorithm": "sha256", "value": digest}}]
        manifest["realizations"][0]["chunking"] = {"strategy": "fixed-size", "chunkSize": len(payload), "merkleRoot": {"algorithm": "sha256", "value": vao04.merkle_root(chunks, "sha256")}, "chunks": chunks}
        data = vao04.json_bytes(manifest); carrier["manifestSHA256"] = hashlib.sha256(data).hexdigest(); carrier["manifestByteSize"] = len(data)
        vao04.write_json(workspace / vao04.MANIFEST_NAME, manifest); vao04.write_json(workspace / vao04.CARRIER_NAME, carrier)
        cases.append(outcome("embedded chunk digests verify", vao04.validate_workspace(workspace)["valid"]))
        vao04.pack_workspace(workspace, archive); report = vao04.validate_archive(archive); cases.append(outcome("0.4.0 archive round trip", report["valid"], "; ".join(report["errors"][:2])))
        broken = root / "broken"; shutil.copytree(workspace, broken); (broken / "payload/evidence/source.txt").write_text("corrupt\n", encoding="utf-8")
        cases.append(outcome("carrier rejects corrupt realization", not vao04.validate_workspace(broken)["valid"]))
        wrong = root / "wrong-chunk"; shutil.copytree(workspace, wrong); manifest = json.loads((wrong / vao04.MANIFEST_NAME).read_text(encoding="utf-8")); carrier = json.loads((wrong / vao04.CARRIER_NAME).read_text(encoding="utf-8"))
        manifest["realizations"][0]["chunking"]["chunks"][0]["digest"]["value"] = "0" * 64
        manifest["realizations"][0]["chunking"]["merkleRoot"]["value"] = vao04.merkle_root(manifest["realizations"][0]["chunking"]["chunks"], "sha256")
        data = vao04.json_bytes(manifest); carrier["manifestSHA256"] = hashlib.sha256(data).hexdigest(); carrier["manifestByteSize"] = len(data)
        vao04.write_json(wrong / vao04.MANIFEST_NAME, manifest); vao04.write_json(wrong / vao04.CARRIER_NAME, carrier)
        cases.append(outcome("embedded chunk-byte mismatch rejected", not vao04.validate_workspace(wrong)["valid"]))
        acoustic = root / "acoustic"
        vao04.migrate_03_workspace(ACOUSTIC_SOURCE03, acoustic)
        report = vao04.validate_workspace(acoustic)
        cases.append(outcome("0.3 acoustic provenance migration", report["valid"], "; ".join(report["errors"][:2])))
    return cases


def main() -> int:
    outcomes = manifest_cases() + trace_cases() + linked_data_cases() + interop_cases() + bundle_cases() + carrier_cases()
    for name, passed, detail in outcomes: print(f"{'PASS' if passed else 'FAIL'} {name}: {detail}")
    passed = sum(1 for _, ok, _ in outcomes if ok); print(f"\n{passed}/{len(outcomes)} VAO 0.4.0 conformance checks passed")
    return 0 if passed == len(outcomes) else 1


if __name__ == "__main__": raise SystemExit(main())
