# VAO 0.3.3 release checklist

## Completed implementation gates

- [x] Separate 0.3 schema, context, vocabulary, profile IRIs, and compatibility dispatch.
- [x] Carrier-independent manifest and exact carrier descriptor.
- [x] Logical asset / realization / distribution separation.
- [x] Realization-level representation status, provenance, rights, fixity, and typed technical metadata.
- [x] Closed Spatial/Acoustics registries with stable measurements and realization-specific RIR mappings.
- [x] Backward-compatible Playable interaction baseline plus a closed capability-qualified sampled-instrument contract.
- [x] Optional closed complex-instrument interaction and capture-lineage contracts with capability truth checks.
- [x] Persistent control/event separation, shared-rank key transforms, bounded process semantics, timing and actuator transfer functions.
- [x] Explicit MIDI numbering bases and velocity-insensitive sample mappings.
- [x] Unicode NFC carrier-path collision rejection in Python and Swift.
- [x] Kinoorgel-derived positive and negative conformance fixture.
- [x] Half-open multi-loop, tuning, variant, perspective, release, and source/evidence validation in Python and Swift.
- [x] Coordinate-frame/pose/geometry transform validation and truthful visual-acoustic capability negotiation.
- [x] Redistributable AcousticRooms public fixture with exact RIR, positions, source OBJ, GLB derivative, license, and provenance.
- [x] Asset-group selection sets, dependencies, fallbacks, totals, and cycle checks.
- [x] Generic repository binding with local trust policy.
- [x] Optional Zenodo adapter; repository-free/private fixture passes.
- [x] Release, pack, carrier, receipt, and optional Zenodo metadata schemas with coherent examples.
- [x] One modular record is the default; a record family is explicit and justified rather than assumed.
- [x] Exclusive/shared member semantics and exact version-PID relations are schema- and code-validated.
- [x] Single-record and record-family metadata projections exercise Zenodo creators, contributors, access/license, discovery fields, and `related_identifiers`.
- [x] Non-destructive 0.2.2-to-0.3 migration and retained source-manifest hash; sampled-instrument and acoustic sources stop for required producer enrichment rather than receiving invented metadata.
- [x] Python validation, packing, receipt, migration, and Zenodo resolution.
- [x] Swift models, format dispatch, semantic validation, carrier validation, and tests.
- [x] OrgRec app dispatch, streaming carrier reader, lossless managed workspace import, typed acoustic/playable inspection, and corrupt-payload rejection.
- [x] Positive/negative conformance suite.
- [x] Historical 0.3.0 Zenodo Sandbox metadata resolution, download, size/SHA-256 verification, and byte comparison; no historical bytes rewritten.
- [x] Deterministic editor-draft release bundle.

## Public publication gates not yet satisfiable

- [ ] Governance approval and named responsible editors/reviewers.
- [ ] Public W3ID redirects controlled and tested.
- [ ] Media type registered or a documented standards-tree registration plan approved.
- [ ] MODAVIS ontology, mapping, and vocabulary releases checksum-pinned rather than marked `development`.
- [ ] Approved standard/source license, copyright notice, and contributor agreement policy.
- [ ] Production Zenodo/community publication decision and approved metadata.
- [ ] Independent implementation/interoperability report.
- [ ] Security review of resolver and archive limits.

The first section establishes implementation readiness for an editor's draft. The unchecked items prevent describing 0.3.3 as an approved public standard or production release; they do not prevent development, testing, private sharing, or repository-free use.
