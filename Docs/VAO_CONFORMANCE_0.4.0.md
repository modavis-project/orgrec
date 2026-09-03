# VAO 0.4.0 conformance

## Targets

A package conforms only when its immutable identifiers, JSON Schema, semantic references, profiles, carrier, exact bytes, rights, and every claimed capability pass. Implementations claim roles separately: validator, reader, writer, extractor, materializer, linked-data projector, repository projector, deterministic runtime, or profile processor.

## Required sequence

1. Parse strict UTF-8 JSON; reject duplicate properties and non-finite numbers.
2. Require the exact 0.4.0 schema and context IRIs.
3. Validate the closed JSON Schema.
4. Build one identifier registry and reject collisions and unresolved local references.
5. Validate retained Core, Spatial/Acoustics, Playable, interaction, capture, delivery, rights, and carrier semantics.
6. Validate typed scientific activity/protocol/software/calibration/observation/analysis/claim/review/consent chains.
7. Validate timebases, tracks, piecewise mappings, discontinuities, annotations, and uncertainty.
8. Validate physical components, ports, connections, sensors, actuators, and state bindings.
9. Reject zero-delay routing cycles; validate delayed edges and bounded processes.
10. Require complete MIDI 2 UMP metadata and reproducible stochastic definitions.
11. Execute and compare every deterministic conformance trace.
12. Verify alternate digests, chunk coverage, indices, carrier closure, byte sizes, and SHA-256.
13. Validate performer/community/consent references and discovery Agents.
14. For RDF claims, run the lossless projection and SHACL validation.

## Reference commands

```sh
python3 Tools/build_vao04_spec.py
python3 Tools/build_vao04_fixture.py
python3 Tools/test_vao04_conformance.py
python3 Tools/vao04.py validate Fixtures/VAO04/descriptors/kinoorgel-multimodal-scientific.example.json
python3 Tools/vao04_rdf.py Fixtures/VAO04/descriptors/kinoorgel-multimodal-scientific.example.json --round-trip-check
swift test --filter VAO04Tests
swift test
swift build -c release
```

The Python suite covers schema, semantics, migration, carrier/archive, exact bytes, runtime, linked-data round trip, release-bundle digests, RO-Crate, DataCite, IIIF, and OCFL projections. Swift independently decodes the typed 0.4.0 model, projects retained semantics through the native 0.3.3 validator, validates new registries, and executes the golden Kinoorgel trace.

The fixture is synthetic; it validates exchange semantics and does not claim scientific validity for placeholder media hashes or a public instrument dataset.
