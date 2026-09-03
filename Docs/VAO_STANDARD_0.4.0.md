# Virtual Acoustic Object (VAO) Standard 0.4.0

Status: implemented private editor's draft  
Compatibility: breaking successor to the unpublished 0.3.3 draft  
Format version: `0.4.0`  
Provisional media type: `application/vnd.modavis.vao+zip`  
Immutable release base: `https://w3id.org/modavis/vao/0.4.0/`

The terms MUST, MUST NOT, REQUIRED, SHOULD, SHOULD NOT, and MAY are normative as defined by BCP 14. The JSON Schema, JSON-LD context, RDF vocabulary, SHACL shapes, conformance document, and release-bundle digest are normative parts of this draft.

## 1. Scope

VAO exchanges a scientific virtual representation of a musical instrument or other acoustic object. A release can preserve evidence, audio, video, images, geometry, depth, motion capture, event streams, sensor observations, scores, annotations, acoustic responses, instrument state, interaction behavior, rendering expectations, physical topology, derivation, rights, and discovery metadata.

VAO is an integration and preservation envelope. It does not replace AES69-SOFA, ADM, glTF, MEI, IIIF, MIDI, RO-Crate, BagIt, OCFL, PROV-O, SOSA/SSN, QUDT, DataCite, CIDOC CRM, or Local Contexts. A VAO realization binds the exact bytes of those formats and the VAO graph states why and how they belong to the instrument release.

## 2. Design invariants

1. A semantic release is immutable and independent of a carrier, repository, or runtime.
2. Logical asset identity is separate from exact byte realization identity.
3. Every realization has media type, byte size, lowercase SHA-256, representation status, rights, provenance, technical metadata, and distribution references.
4. Raw evidence, processed derivatives, simulations, inferences, reconstructions, and creative transformations are not interchangeable.
5. Filenames MUST NOT be the only copy of a scientific or playable relationship.
6. Units are IRIs; measured values retain uncertainty, protocol, activity, calibration, and raw/processed identity where available.
7. Every multimodal sample belongs to an explicit clock and, when spatial, an explicit coordinate frame.
8. Interaction is declarative. Opening or validating a VAO MUST NOT execute active content.
9. A deterministic claim is testable by a canonical input/state/output trace.
10. Absence of a license or consent never grants permission.
11. JSON and RDF projections are lossless and must not launder nested records into opaque JSON literals.
12. External acquisition is optional and untrusted until exact bytes have been verified locally.

## 3. Immutable release namespace

The manifest MUST contain:

- `$schema`: `https://w3id.org/modavis/vao/0.4.0/schema/manifest.json`;
- `@context`: including `https://w3id.org/modavis/vao/0.4.0/context.jsonld`;
- `formatVersion`: `0.4.0`.

The schema, context, vocabulary, SHACL shapes, carrier schema, release schema, pack schema, receipt schema, and repository projection schema are content-pinned by `Schemas/vao-release-bundle-0.4.0.json`. A deployed moving alias such as `latest` MUST NOT be written into a preserved release.

## 4. Release, carrier, and exact bytes

The 0.3.3 logical-asset, realization, distribution, repository-binding, asset-group, carrier, release, pack, materialization-receipt, Spatial, Acoustics, Playable, capture-state, take-set, and derivation semantics remain normative in 0.4.0 except where this document strengthens them.

The manifest contains no carrier paths. `META-INF/vao-carrier.json` maps realization IDs to safe NFC-distinct `payload/` paths, pins the exact manifest bytes, and declares complete groups. A preservation closure embeds every realization. Other carriers may embed a verified subset and materialize the remainder from exact distributions.

`contentDigests` adds SHA-512 identity without weakening the required SHA-256. When it repeats SHA-256 it MUST equal `sha256`. `chunking` defines fixed, content-defined, external-index, Zarr, or pack-shard delivery. Inline chunks MUST be consecutively indexed, byte-contiguous, and cover `byteSize`. An external index is itself an exact realization. Merkle roots and authenticity envelopes supplement but never replace realization fixity.

For an inline Merkle tree, every chunk digest uses the root algorithm. A leaf is `H(0x00 || chunkDigestBytes)` and an internal node is `H(0x01 || left || right)`; an unpaired node is duplicated. The root is the final lowercase digest. Embedded chunk bytes MUST be checked against every declared chunk digest before range-addressable use.

## 5. Manifest registries

Every 0.4.0 manifest contains these closed top-level records:

- `scientific`;
- `multimodal`;
- `physicalSystem`;
- `runtime`;
- `discovery`.

They may contain empty registries when the release has no data of that class. Non-empty optional-profile content requires the corresponding embedded and claimed profile. Core and Dynamic Delivery are always embedded and claimed.

## 6. Scientific records

`scientific` contains typed `agents`, `activities`, `observations`, `analyses`, `calibrations`, `protocols`, `softwareEnvironments`, `claims`, `reviews`, and `consents`. Arbitrary objects are not scientific records.

An Activity names its start and end, associated Agents, Protocol, inputs, outputs, and optional exact Software Environment, parameters, environment observations, and random source. An Analysis additionally states its kind, reproducibility class, parameters, outputs, validation evidence, and optional fit residual. `seeded` requires a declared random source; `deterministic` MUST NOT depend on one.

An Observation names its observed property, feature of interest, result time, Activity, Protocol, quantity value and QUDT unit. It may name sensor, calibration, raw realization, processed realization, uncertainty, sample count, censoring, quality flags, and outlier policy. Original contradictory or anomalous measurements remain evidence and are resolved through Claim and Review records rather than silent normalization.

A Claim has exactly one object IRI or literal, evidence references, epistemic status, and optional confidence and reviews. Consent names its granting Agent, subjects, decision, time, conditions, and optional evidence realization.

## 7. Multimodal Timeline profile

`multimodal` contains timebases, tracks, synchronization mappings, and Web-Annotation-compatible annotations.

A Track names a modality, exact realization, clock, continuity, and optional coordinate frame. Modalities include audio, video, image sequences, depth, volumetric capture, motion capture, sensor streams, events, score, annotations, and trajectories.

A synchronization mapping relates two distinct timebases through one or more non-overlapping, ordered, piecewise-affine segments:

`target = source × scale + offset`

Each segment includes residual uncertainty and may record a dropout, reset, pause, or unknown discontinuity. The mapping names the Activity that produced it and may record jitter. A single global offset is a one-segment special case.

Annotations target a track with temporal, spatial, SVG, event, or score selectors. IIIF Canvas, Web Annotation, and MEI bindings are projections; their identifiers may be used directly.

## 8. Physical Instrument profile

`physicalSystem` separates semantic Entities from system topology. Components have ports. Connections carry signals, energy, material, or mechanical coupling. Sensors observe properties; actuators act on properties. Both name a scientific Protocol, and sensors may name a Calibration. State bindings distinguish commanded, observed, estimated, and simulated state.

An explicitly delayed connection or routing edge may participate in a cycle. The graph formed only by zero-delay copy/transpose edges MUST be acyclic. This permits real delayed feedback without permitting unbounded combinational evaluation.

## 9. Interaction and deterministic runtime

The Playable and complex-interaction registries remain orthogonal: controls are not events; state, routing, process, timing, transfer, and render selection are separate records.

Every `interactionModel` contains `executionSemantics`. In 0.4.0 the normative reference contract is:

- timestamps ascend;
- simultaneous inputs order by descending priority, event-type ID, then sequence;
- transition guards read one pre-event state snapshot;
- transitions order by descending priority then transition ID;
- actions order by execution group, action index, then transition ID;
- one event runs to completion before the next;
- re-entrant events are queued or rejected as declared;
- late events follow the declared reject, clamp, or next-cycle policy;
- evaluation stops at `maximumMicrosteps`;
- voice allocation follows the declared deterministic policy.

State conflicts obey the transition conflict policy. Retrigger, cancellation, release, maximum iteration, and duration policies remain declarative. A renderer is an external capability/version descriptor and never embedded executable code. `declarative-only` is the safe default.

A stochastic Process MUST name a reproducible Random Source and distribution. VAO 0.4.0 standardizes PCG32 and xoshiro256** identities; the reference interpreter implements PCG32. Distribution kind and parameters are part of the release. A non-reproducible scientific analysis may be preserved but cannot satisfy deterministic-render conformance.

Conformance traces bind canonical input events, initial state, expected final state, emitted events, selected render bindings, and a SHA-256 over their canonical JSON. A runtime claim requires trace execution, not only schema validation.

## 10. Protocols and transfer functions

MIDI 1.0 retains explicit channel and data numbering bases. MIDI 2.0 additionally records UMP group, function block, message type, data resolution, JR timestamp handling, and optional per-note controller, MIDI-CI Profile, and Property Exchange resource IRIs.

Transfer functions retain source and review evidence. They may use multiple input kinds and vectors, per-point uncertainty, valid domains, explicit extrapolation, hysteresis, dynamic-model class, and fit residual. A multivariate function names its ordered `inputKinds`. Out-of-domain behavior MUST NOT be host-defined when scientific reproduction is claimed.

## 11. Rights, ethics, and discovery

Rights may reference performers, consents, community authorities, Traditional Knowledge labels, CARE principles, privacy classification, embargo rationale, and redaction lineage. `community-governed` requires at least one authority. An embargo date requires a rationale. Redaction creates a derivative realization; it does not rewrite the source realization.

`discovery` is repository-neutral and DataCite-ready. Creators and contributors reference Agents; ORCID and ROR occur on Agents. Funding references may include funder and award identifiers. Subjects, related identifiers, instrument identifiers, and facility identifiers are explicit. Repository metadata is a projection and cannot redefine the VAO release.

## 12. Linked data and interoperability

The normative context maps domain records as nodes, never `@json`. `Tools/vao04_rdf.py` adds class types and JSON pointers for a lossless JSON-LD projection and verifies its inverse. `Schemas/vao-shapes-0.4.0.ttl` supplies RDF validation shapes.

`Tools/vao04_interop.py` implements RO-Crate, DataCite 4, IIIF Presentation 3, and OCFL 1.1 projections. BagIt may carry a VAO workspace; OCFL may store its version history; RO-Crate may describe it as a research object. AES69-SOFA, ADM, glTF, MEI, and MIDI remain realization or protocol standards whose exact bytes/identifiers are bound by VAO.

## 13. Security and conformance

A processor validates structure, strict JSON, identifiers, cross-references, profiles, scientific semantics, clock mappings, topology, runtime traces, paths, sizes, compression, carrier closure, and exact bytes before use. It MUST NOT automatically fetch or execute package-supplied content. Resource limits, decompression limits, symlink rejection, path normalization, overwrite policy, network allowlists, TLS, and repository authentication remain local policy.

Conformance roles and commands are defined in `VAO_CONFORMANCE_0.4.0.md`. Passing JSON Schema alone is insufficient.

## 14. Publication status

0.4.0 is fully implemented for private development and conformance testing. It MUST NOT be described as an approved public standard until governance, W3ID deployment, media-type registration, licensing, released checksum-pinned MODAVIS dependencies, independent implementation evidence, and external security review are complete.
