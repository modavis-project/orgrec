#!/usr/bin/env python3
"""Normative lossless VAO 0.4.0 JSON-LD projection helper."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any

import vao04


TYPE_BY_REGISTRY = {
    "agents": "http://www.w3.org/ns/prov#Agent", "activities": "http://www.w3.org/ns/prov#Activity",
    "observations": "http://www.w3.org/ns/sosa/Observation", "analyses": "https://w3id.org/modavis/vao/ontology#Analysis",
    "calibrations": "https://w3id.org/modavis/vao/ontology#Calibration", "protocols": "http://www.w3.org/ns/sosa/Procedure",
    "softwareEnvironments": "https://w3id.org/modavis/vao/ontology#SoftwareEnvironment",
    "claims": "https://w3id.org/modavis/vao/ontology#ScientificClaim", "reviews": "https://w3id.org/modavis/vao/ontology#Review",
    "consents": "https://w3id.org/modavis/vao/ontology#Consent", "timebases": "https://w3id.org/modavis/vao/ontology#Timebase",
    "tracks": "https://w3id.org/modavis/vao/ontology#Track", "synchronizationMappings": "https://w3id.org/modavis/vao/ontology#SynchronizationMapping",
    "annotations": "http://www.w3.org/ns/oa#Annotation", "components": "https://w3id.org/modavis/vao/ontology#PhysicalComponent",
    "ports": "https://w3id.org/modavis/vao/ontology#Port", "connections": "https://w3id.org/modavis/vao/ontology#Connection",
    "sensors": "http://www.w3.org/ns/sosa/Sensor", "actuators": "http://www.w3.org/ns/sosa/Actuator",
    "stateBindings": "https://w3id.org/modavis/vao/ontology#StateBinding", "randomSources": "https://w3id.org/modavis/vao/ontology#RandomSource",
    "renderers": "https://w3id.org/modavis/vao/ontology#RendererDescriptor", "conformanceTraces": "https://w3id.org/modavis/vao/ontology#ConformanceTrace",
    "logicalAssets": "https://w3id.org/modavis/vao/ontology#LogicalAsset", "realizations": "https://w3id.org/modavis/vao/ontology#Realization",
}
CONTAINER_TYPES = {
    "scientific": "https://w3id.org/modavis/vao/ontology#ScientificRecordSet",
    "multimodal": "https://w3id.org/modavis/vao/ontology#MultimodalTimeline",
    "physicalSystem": "https://w3id.org/modavis/vao/ontology#PhysicalSystem",
    "runtime": "https://w3id.org/modavis/vao/ontology#RuntimeContract",
}


def project_jsonld(manifest: dict[str, Any]) -> dict[str, Any]:
    report = vao04.validate_manifest(manifest)
    if not report["valid"]: raise ValueError("Cannot project invalid VAO 0.4.0: " + "; ".join(report["errors"][:3]))
    value = copy.deepcopy(manifest)
    value["type"] = "https://w3id.org/modavis/vao/ontology#VirtualAcousticObject"

    def visit(node: Any, pointer: str = "") -> None:
        if isinstance(node, dict):
            for key, child in list(node.items()):
                child_pointer = pointer + "/" + key.replace("~", "~0").replace("/", "~1")
                if key in CONTAINER_TYPES and isinstance(child, dict):
                    child.setdefault("type", CONTAINER_TYPES[key]); child["vao:jsonPointer"] = child_pointer
                if key in TYPE_BY_REGISTRY and isinstance(child, list):
                    for index, record in enumerate(child):
                        if isinstance(record, dict):
                            record.setdefault("type", TYPE_BY_REGISTRY[key])
                            record["vao:jsonPointer"] = f"{child_pointer}/{index}"
                visit(child, child_pointer)
        elif isinstance(node, list):
            for index, child in enumerate(node): visit(child, f"{pointer}/{index}")
    visit(value)
    return value


def inverse_projection(projected: dict[str, Any]) -> dict[str, Any]:
    value = copy.deepcopy(projected)
    value["type"] = "VirtualAcousticObject"
    def visit(node: Any, parent_key: str | None = None) -> None:
        if isinstance(node, dict):
            node.pop("vao:jsonPointer", None)
            if parent_key in CONTAINER_TYPES and node.get("type") == CONTAINER_TYPES[parent_key]: node.pop("type")
            for key, child in list(node.items()): visit(child, key)
        elif isinstance(node, list):
            for child in node:
                if isinstance(child, dict) and parent_key in TYPE_BY_REGISTRY and child.get("type") == TYPE_BY_REGISTRY[parent_key]: child.pop("type")
                visit(child, parent_key)
    visit(value)
    return value


def main() -> None:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("manifest", type=Path); parser.add_argument("--round-trip-check", action="store_true")
    args = parser.parse_args(); manifest = json.loads(args.manifest.read_text(encoding="utf-8")); projected = project_jsonld(manifest)
    if args.round_trip_check and inverse_projection(projected) != manifest: raise SystemExit("Projection is not lossless")
    print(json.dumps(projected, indent=2, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__": main()
