#!/usr/bin/env python3
"""Repository-neutral VAO 0.4.0 projections for adjacent standards."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import vao04


def _label(value: dict[str, str]) -> str:
    return value.get("en") or value.get("und") or next(iter(value.values()))


def ro_crate(manifest: dict[str, Any]) -> dict[str, Any]:
    graph: list[dict[str, Any]] = [
        {"@id": "ro-crate-metadata.json", "@type": "CreativeWork", "about": {"@id": "./"}, "conformsTo": {"@id": "https://w3id.org/ro/crate/1.2"}},
        {"@id": "./", "@type": "Dataset", "name": _label(manifest["title"]), "identifier": manifest["id"], "hasPart": [{"@id": r["id"]} for r in manifest["realizations"]]},
    ]
    for agent in manifest["scientific"]["agents"]:
        graph.append({"@id": agent["id"], "@type": "Person" if agent["agentKind"] == "person" else "Organization", "name": _label(agent["labels"])})
    for realization in manifest["realizations"]:
        graph.append({"@id": realization["id"], "@type": "File", "encodingFormat": realization["mediaType"], "contentSize": realization["byteSize"], "sha256": realization["sha256"]})
    for activity in manifest["scientific"]["activities"]:
        graph.append({"@id": activity["id"], "@type": "CreateAction", "agent": [{"@id": x} for x in activity["agentIds"]], "object": [{"@id": x} for x in activity["inputIds"]], "result": [{"@id": x} for x in activity["outputIds"]]})
    return {"@context": "https://w3id.org/ro/crate/1.2/context", "@graph": graph}


def datacite(manifest: dict[str, Any]) -> dict[str, Any]:
    agents = {x["id"]: x for x in manifest["scientific"]["agents"]}
    discovery = manifest["discovery"]
    def person(identifier: str) -> dict[str, Any]:
        agent = agents[identifier]; result: dict[str, Any] = {"name": _label(agent["labels"]), "nameType": "Personal" if agent["agentKind"] == "person" else "Organizational"}
        if agent.get("orcid"): result["nameIdentifiers"] = [{"nameIdentifier": agent["orcid"], "nameIdentifierScheme": "ORCID", "schemeUri": "https://orcid.org"}]
        return result
    return {"data": {"type": "dois", "attributes": {
        "titles": [{"title": _label(manifest["title"])}], "publisher": "VAO repository", "publicationYear": manifest["createdAt"][:4],
        "types": {"resourceTypeGeneral": discovery["resourceType"]}, "creators": [person(x) for x in discovery["creatorAgentIds"]],
        "contributors": [{**person(x), "contributorType": "Other"} for x in discovery["contributorAgentIds"]],
        "subjects": discovery["subjects"], "fundingReferences": discovery["fundingReferences"],
        "relatedIdentifiers": [{"relatedIdentifier": x["identifier"], "relatedIdentifierType": "URL", "relationType": x["relationType"]} for x in discovery["relatedIdentifiers"]],
        "schemaVersion": "http://datacite.org/schema/kernel-4",
    }}}


def iiif_presentation(manifest: dict[str, Any]) -> dict[str, Any]:
    realizations = {x["id"]: x for x in manifest["realizations"]}
    canvases = []
    for track in manifest["multimodal"]["tracks"]:
        realization = realizations[track["realizationId"]]; duration = realization["technicalMetadata"].get("durationSeconds")
        if duration is None and realization["technicalMetadata"].get("frameCount") and realization["technicalMetadata"].get("sampleRate"):
            duration = realization["technicalMetadata"]["frameCount"] / realization["technicalMetadata"]["sampleRate"]
        canvas = {"id": track["id"], "type": "Canvas", "label": {"en": [track["modality"]]}, "items": [{"id": track["id"] + "/page", "type": "AnnotationPage", "items": [{"id": track["id"] + "/body", "type": "Annotation", "motivation": "painting", "body": {"id": realization["id"], "type": "Sound" if track["modality"] == "audio" else "Video", "format": realization["mediaType"]}, "target": track["id"]}]}]}
        if duration is not None: canvas["duration"] = duration
        canvases.append(canvas)
    return {"@context": "http://iiif.io/api/presentation/3/context.json", "id": manifest["id"] + "/iiif", "type": "Manifest", "label": {"en": [_label(manifest["title"])]}, "items": canvases}


def ocfl_inventory(manifest: dict[str, Any]) -> dict[str, Any]:
    state = {realization["sha256"]: [f"payload/by-id/{realization['id'].replace(':', '_')}"] for realization in manifest["realizations"]}
    return {"id": manifest["id"], "type": "https://ocfl.io/1.1/spec/#inventory", "digestAlgorithm": "sha256", "head": "v1", "manifest": state, "versions": {"v1": {"created": manifest["createdAt"], "message": "VAO semantic release", "state": state}}}


PROJECTIONS = {"ro-crate": ro_crate, "datacite": datacite, "iiif": iiif_presentation, "ocfl": ocfl_inventory}


def main() -> None:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("projection", choices=PROJECTIONS); parser.add_argument("manifest", type=Path)
    args = parser.parse_args(); manifest = json.loads(args.manifest.read_text(encoding="utf-8")); report = vao04.validate_manifest(manifest)
    if not report["valid"]: raise SystemExit("Invalid VAO 0.4.0: " + "; ".join(report["errors"][:3]))
    print(json.dumps(PROJECTIONS[args.projection](manifest), indent=2, ensure_ascii=False, sort_keys=True))


if __name__ == "__main__": main()
