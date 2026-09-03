# VAO 0.3.2 decision and changelog

Status: implemented private editor's draft  
Date: 2026-08-24

## Decision

VAO 0.3.2 makes a position-registered visual-acoustic scene a first-class, testable contract. VAO 0.2.2 had a broad acoustic model, but 0.3.1 temporarily admitted `acoustics` as an opaque JSON object and therefore could not prove that a room mesh, impulse responses, and source/receiver positions actually described one coordinate system. This update closes that gap without making a 3D scene, an RIR, Blender, or a repository mandatory for ordinary VAOs.

The unit of meaning is a logical source–receiver measurement with a stable ID. The storage layout of that measurement is realization-specific. This separation permits the same response set to have a single-pair WAVE derivative, a multi-measurement SOFA preservation realization, or another array encoding without changing pose identity or inventing separate acoustic scenes.

## Normative changes

- Exact `formatVersion` is now `0.3.2`; unpublished 0.3.0 and 0.3.1 draft artifacts require regeneration.
- The top-level `acoustics` object is closed and has nine registries: coordinate frames, poses, geometry bindings, material models, measurements, response sets, metric sets, audio scenes, and render configurations.
- Coordinate-frame graphs require resolvable parents, invertible row-major 4×4 transforms, and no cycles. Poses require dimension agreement and normalized XYZW quaternions when orientation is known.
- Geometry bindings now target logical assets. Geometry encodings carry their own frame metadata, so an OBJ preservation source and a +Y-up glTF visualization derivative can coexist with a declared transform.
- Stable `measurements` bind source/receiver entities and poses. `responseSets` name those measurement IDs but do not contain byte-array indices.
- Audio realization metadata now has a closed `impulseResponse` block with encoding, exact sample count, time-zero/normalization policy, response-set ID, and measurement-to-data/channel mappings.
- The Playable profile preserves 0.2's protocol-independent interaction baseline for sampled, synthesized, modelled, and externally rendered instruments. Its optional `sampled-instrument-playback` capability now has a closed normative `playable` object for signal regions, multiple loop points, tuning maps, microphone perspectives, sample variants, rank/key/velocity mappings, round robin, and recorded releases.
- Playable ranges use one half-open frame convention; RIFF `smpl` inclusive ends have an explicit lossless conversion rule. `frameCount` was added to audio technical metadata for bounds validation.
- Every playable record separates metadata source from evidence status. Algorithmic/inferred results require provenance and cannot be presented as asserted embedded/native facts.
- WAVE and FLAC are limited to one fixed pair per realization. SOFA requires its convention; its `M` layout is made explicit through `dataIRIndex`.
- New machine-checked capabilities are `simulated-impulse-response`, `position-registered-acoustic-scene`, and `visual-acoustic-scene`. Existing measured, response-field, spatial-audio, semantic-building, and renderer claims receive corresponding truth checks.
- JSON-LD context and RDF vocabulary terms now cover coordinate, measurement, response, scene, and logical-asset links.

## Public test evidence

The reference fixture uses the CC BY 4.0 AcousticRooms dataset at Git commit `3c87318a0188e1b441fc75846d54b487ca215fbb`. It selects `Bathrooms/Bathrooms_idx_0` and response pair `S000_R0011`, retaining the exact OBJ, normalized hybrid WAV RIR, pair metadata, simulation configuration, upstream README/license, and content/provenance hashes. The source position is `[2.3496, 0.7269, 1.353]` metres and the receiver position is `[2.8176, 0.9871, 1.4665]` metres in the dataset's +Z-up frame.

Blender 5.1.1 generated a glTF Binary visualization derivative. The source OBJ remains the preservation/simulation realization. The GLB uses its own +Y-up frame and the manifest supplies the exact transform into the dataset frame. This proves the proposed visualization workflow at the exchange-contract level without claiming that VAO requires Blender or that the add-on already implements 0.3.2.

## Compatibility

VAO 0.2.2 remains valid under its own schema. Baseline Playable interactions migrate without forcing a sample implementation. Sampled-instrument and acoustic migrations must convert their old records into the new closed registries and byte-layout mappings. If exact variants, mappings, samples, channels, conventions, or frame transforms cannot be established, a migrator must request enrichment or retain only explicit migration evidence; it may not fabricate metadata or claim the affected capability.

The published Sandbox 0.3.0 record remains immutable historical repository-adapter evidence. No Sandbox/production record or repository metadata was created or changed for 0.3.2.

## Status boundary

This is an implemented reference contract, not an approved public standard. Governance, public W3ID control, licensing of the standard itself, dependency pins, media-type registration, security review, and independent interoperability remain publication gates.
