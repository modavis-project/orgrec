# VAO standard changelog

This changelog records changes to the Virtual Acoustic Object format contract,
not ordinary OrgRec application changes. VAO follows the compatibility policy
in `Docs/VAO_GOVERNANCE.md`.

This file preserves pre-0.5 development history. The public VAO 0.5.0
changelog is maintained in the separate VAO standard repository; OrgRec pins
that release rather than redefining it here.

## 0.4.0 — multimodal scientific virtual-instrument contract

- Introduced immutable exact-version schema, context, vocabulary, SHACL, descriptor, and digest-bundle identifiers.
- Replaced open paradata/analysis objects with typed Agent, Activity, Protocol, Software Environment, Calibration, Observation, Analysis, Claim, Review, and Consent records.
- Added general timebases, modality tracks, piecewise synchronization, uncertainty, discontinuities, and Web-Annotation-compatible selectors.
- Added physical component/port/connection/sensor/actuator topology and commanded/observed state bindings.
- Added deterministic scheduling, portable golden traces, seeded PCG32 stochastic behavior, MIDI 2 UMP/MIDI-CI, delayed feedback, and richer transfer models.
- Added video/depth/volumetric/motion/event/sensor/score media kinds, chunks/Merkle/digest agility, consent/community rights, and DataCite discovery.
- Added lossless JSON-LD projection, SHACL shapes, and RO-Crate, DataCite, IIIF, and OCFL projections.
- Added Python and Swift validators/runtimes/readers/materialization, an application import route, and a multimodal Kinoorgel fixture while retaining all 0.3.3 regression behavior.

## 0.3.3 — complex-instrument interaction contract

- Added typed state, control/event, routing, bounded process, timing, transfer, render, capture-alignment, take-set, and derivation registries.
- Added shared-rank key transforms, velocity-insensitive sample mappings, explicit MIDI numbering bases, and capability truth validation in Python and Swift.
- Added Unicode NFC carrier-path collision rejection and a Kinoorgel-derived conformance fixture with positive and negative tests.
- Advanced the private editor's-draft dispatch to exact `formatVersion: "0.3.3"`; historical 0.3.0/0.3.2 release artifacts remain unchanged.

## 0.3.2 — implemented editor's draft

Private **pre-public visual-acoustic contract correction**. This snapshot
supersedes unpublished 0.3.0/0.3.1 draft artifacts while retaining the
historical Sandbox 0.3.0 record unchanged.

### Changed

- Replaced the opaque 0.3 `acoustics` property with closed coordinate-frame,
  pose, geometry-binding, measurement, response, metric, audio-scene, and
  renderer registries.
- Separated stable logical source–receiver measurements from exact
  realization storage layout and added typed WAVE/FLAC/SOFA/array mappings.
- Added checked coordinate transformations and capability truth for measured,
  simulated, position-registered, and visual-acoustic scenes.
- Advanced current schemas, implementations, fixtures, descriptors, and
  release artifacts to exact `formatVersion: "0.3.2"`.

### Added

- Added a CC BY 4.0 AcousticRooms preservation fixture with exact OBJ and RIR
  source bytes, source/receiver positions, upstream evidence, and a separate
  Blender-generated GLB visualization realization.
- Added Python and Swift acoustic semantic validators and positive/negative
  coverage for transforms, poses, measurement mappings, channels, status, and
  capability claims.
- Added `Docs/VAO_0.3.2_CHANGELOG.md` and
  `Docs/VAO_ACOUSTIC_SCENES_0.3.md`.

### Publication status

- No new Sandbox or production record was created or modified for 0.3.2.
- Public-standard/production-ready: no; governance and infrastructure gates
  remain open.

## 0.3.1 — implemented editor's draft

Private **pre-public contract correction**. No public VAO 0.3 object or
compatibility promise exists; this snapshot supersedes 0.3.0 while leaving its
published Sandbox evidence immutable.

### Changed

- Replaced the one-record-only `repositoryRecord` release descriptor with an
  explicit `single-record` or `record-family` publication topology.
- Made one modular record with independently downloadable files the default;
  record families are optional for size/file-count, rights/access, lifecycle,
  reuse, ownership, or separate-citation boundaries.
- Added typed per-record file inventories and exclusive versus shared member
  semantics. Exact relations use version PIDs; concept PIDs remain discovery
  channels.
- Added an optional Zenodo metadata projection covering creators,
  contributors, access/license, discovery terms, dates/method, references,
  communities/grants, and `related_identifiers`.
- Advanced current 0.3 manifests, carriers, packs, receipts, implementations,
  fixtures, and release artifacts to exact `formatVersion: "0.3.1"`.

### Added

- Added executable single-record and related-family examples, including an
  exclusive model pack (`hasPart`/`isPartOf`) and a reusable audio dependency
  (`requires` without false ownership).
- Added Python and Swift topology/metadata cross-validation and negative tests.
- Added `Docs/VAO_0.3.1_CHANGELOG.md` with the full decision and migration note.

### Publication status

- Zenodo remains optional. Repository-free development, testing, private
  sharing, air-gapped use, and preservation remain conforming.
- No new Sandbox or production record was created for 0.3.1.
- Public-standard/production-ready: no; existing governance and infrastructure
  gates remain open.

## 0.3.0 — implemented editor's draft

Private **breaking minor compatibility line**. This is implementation-ready for
controlled development and interoperability, but not yet an approved public
standard or production publication.

### Compatibility

- Introduces new `/0.3/` schema and context IRIs and new `/profile/*/0.3`
  profile IRIs. It never reuses 0.2 profile identifiers.
- Keeps the complete 0.2.2 validator/writer line and adds format-version
  dispatch. Migration is non-destructive, retains the source manifest hash, and
  never invents remote resources.
- A repository, DOI, network connection, and Zenodo are optional. Fully
  embedded development, test, private-sharing, air-gapped, and preservation
  carriers are conforming.

### Added

- Added carrier-independent semantic releases, carrier descriptors, and exact
  logical-asset / realization / distribution separation.
- Added realization-level representation status, rights, provenance, SHA-256,
  byte size, and typed audio/geometry metadata.
- Added selection sets, dependency/fallback DAGs, exact byte totals, embedded
  versus materializable profile states, preservation closure, pack manifests,
  release descriptors, and separate materialization receipts.
- Added a repository-neutral binding contract and an optional, locally trusted
  Zenodo adapter. Manifests cannot supply API bases, host allowlists,
  credentials, or redirect policy.
- Added Python validation, carrier writing, migration, receipts, and Zenodo
  resolution; Swift models, dispatch, manifest/carrier validation, and tests;
  32-case Python conformance coverage; repository-free and Sandbox fixtures;
  and a deterministic editor-draft release bundle.
- Published and anonymously resolved the corrected Sandbox fixture at version
  DOI `10.5072/zenodo.590947`. The first immutable trial captured a Sandbox
  draft/publication DOI-prefix mismatch and was superseded rather than edited.

### Publication status

- Implementation-ready: yes.
- Public-standard/production-ready: no. Governance, W3ID, media-type,
  dependency-pin, licensing, independent implementation, and security-review
  gates remain explicit in `Docs/VAO_RELEASE_CHECKLIST_0.3.md`.

## Unreleased — target 0.2.2

Private **backward-compatible patch contract revision** within the 0.2 line.
No public VAO release has yet been made.

### Compatibility

- Requires new writers for this snapshot to emit `formatVersion: "0.2.2"` and
  reserves `https://w3id.org/modavis/vao/0.2.2/` as its exact-release IRI.
- Keeps the 0.2 schema, context, and profile IRIs. Readers continue accepting
  conforming `0.2.x` packages; existing 0.2.0 and 0.2.1 packages do not need
  rewriting.
- Adds validation only when a package explicitly claims the new optional
  `collection-acoustic-diagnostics` capability. Packages that do not claim it
  retain the earlier 0.2.x requirements.

### Added

- Added the optional `collection-acoustic-diagnostics` capability contract and
  its `evidence-qualified-collection-acoustic-diagnostics` analysis type, with
  exact assessed inputs, aggregate-inclusion decisions, frozen parameters and
  SHA-256, evidence counts and coverage, grouping provenance, applicability,
  exclusion reasons, evidence tiers, and quality flags.
- Added robust per-rank tuning curves and stretch estimates, per-session offset,
  repeated-comparable-target drift estimates, robust multivariate
  acoustic-anomaly candidates, and harmonic-number-aligned acoustic-similarity
  candidates.
- Added eight governed collection observations: `evidence-summary`,
  `take-evidence`, `rank-tuning-curves`, `rank-stretch`, `session-offset`,
  `session-drift`, `acoustic-anomaly-candidates`, and
  `acoustic-similarity-candidates`. Their governed aggregations are
  quality-weighted median, Siegel repeated median, median,
  within-target median slope, robust multivariate distance, and
  harmonic-aligned cosine, with cent and rate units where applicable.
- Kept every similarity result a review candidate. Neither similarity nor an
  analytically inferred rank grouping asserts physical identity, shared pipes,
  construction, or a documentary component relation.
- Added matching Swift and Python semantic validation, vocabulary terms,
  OrgRec export, and positive/negative conformance coverage for the collection
  contract.

### Changed

- Advanced the VAO/OrgRec mapping identifier to `vao-modavis-mapping/0.2.2`.
- Collection aggregates now distinguish insufficient evidence from a measured
  zero, preserve the exact assessed-take ledger, and keep replication
  consistency separate from cross-target overlap review.
- Collection reports now carry a deterministic source fingerprint. Unchanged
  evidence retains the report revision, while take review, roadmap, analysis,
  or session changes trigger a fresh aggregate before persistence or VAO export.
- Retained every 0.2.1 empirical-classifier and rank-fingerprint contract
  unchanged; 0.2.2 adds a separate optional capability rather than tightening
  those earlier claims.

## 0.2.1 — prior private implementation snapshot

Private **backward-compatible patch contract revision** within the 0.2 line.
No public VAO release was made.

### Compatibility

- Required writers for that snapshot to emit `formatVersion: "0.2.1"` and
  reserved `https://w3id.org/modavis/vao/0.2.1/` as its exact-release IRI.
- Kept the 0.2 schema, context, and profile IRIs. Conforming 0.2.0 packages did
  not need rewriting.
- Added validation only when a package explicitly claimed one of the two new
  optional research capabilities.

### Added

- Added `empirical-timbre-classification`: an indexed model role, learned
  inference paradata, a normalized four-family calibrated distribution,
  explicit out-of-distribution state, and an abstaining decision.
- Added `pitch-dependent-rank-fingerprint`: ascending key-indexed trajectories,
  pitch trends, and statistically qualified construction-transition candidates.
- Added the `limited` applicability value for scientifically useful results
  whose evidence or domain checks do not support an unrestricted claim.
- Added matching Swift and Python semantic validation, RDF vocabulary terms,
  OrgRec export, and positive/negative conformance coverage.

### Changed

- Advanced the VAO/OrgRec mapping identifier to `vao-modavis-mapping/0.2.1`.
- Kept inferred family and transition evidence separate from documentary stop
  identity and organological construction assertions.

## 0.2.0 — prior private implementation snapshot

Private pre-public breaking minor contract revision. No public VAO release
was made.

### Compatibility

- Classifies this work as a **pre-public breaking minor contract revision**.
  A 0.2.x reader accepts only the 0.2 compatibility line. VAOM provides an
  evidence-preserving copy migration from private 0.1.x workspaces.
- Requires new writers to emit `formatVersion: "0.2.0"` and reserves
  `https://w3id.org/modavis/vao/0.2.0/` as the exact-release IRI and uses new
  `/vao/0.2/` schema/context and `/profile/*/0.2` profile IRIs.
- Replaces the instrument-only `rootEntityId` with general
  `primaryEntityId` and non-empty `focusEntityIds`. Lossless copy operations
  retain the source version; editing or migration creates a new immutable
  revision.

### Added

- Added the acoustics profile and a closed technical layer for coordinate
  frames, 2D/3D poses, stable geometry bindings, frequency-dependent material
  models, acoustic response sets, metric sets, spatial audio scenes, and safe
  declarative render configurations.
- Added building/storey/space/zone/boundary/opening/material, emitter/receiver,
  response, scene, renderer, sensor, and equipment entity kinds; room and
  building acoustics now distinguish source room, receiving room, separating
  element, and transmission paths.
- Added AES69 SOFA response contracts, ITU ADM/BW64 and MPEG-I/MPEG-H spatial
  scene types, tracked 3DoF/6DoF listening, source tracking, geometry/hybrid
  rendering features, outside-domain policies, fallbacks, and levels of detail.
- Added learned/differentiable acoustic-field status and mandatory model,
  training/validation input, quality-domain, determinism, and non-learned
  fallback lineage so inferred fields cannot masquerade as measurements.
- Added activity-specific acoustic method descriptors, exact standards and
  editions, equipment/calibration/environment links, and frequency-axis and
  uncertainty validation.
- Added `minimal-acoustic-room`, native Swift/Python acoustic semantic
  validation, evidence-retaining migration tooling, and negative tests for frame cycles,
  quaternions, provenance, SOFA declaration, band alignment, neural lineage,
  building pairs, and runtime fallback behavior.

- Added exact, source-bound `SampleExtractionRegion`, `AttackRegion`,
  `StableSustainRegion`, and `ReleaseRegion` entities for non-destructive
  segmentation of long recordings, with half-open frames, sample rate, source
  hash, channel, boundary confidence, censoring, and derivation relations.
- Added protocol-neutral `SamplePlaybackParameters`: root/range/velocity
  mapping, measured source and target frequency, tuning offset, pitch mode,
  gain, envelope, note-off, channel, round-robin, priority, and latency data.
- Added versioned `TuningMap` and `TuningCalibration` resources so raw pitch
  measurements, inferred temperament, and accepted playback targets are not
  conflated. Exact per-key frequencies compose with, but do not depend on,
  MIDI Tuning Standard transport.
- Expanded observations with review status, applicability, censoring,
  aggregation, coverage, evidence count, channel selection, quality flags,
  source region, value asset, and an optional exact-frame clock tied to an
  indexed asset.
- Added capabilities for sampled-instrument playback, source segmentation,
  acoustical analysis, and tuning maps; added asset roles for tuning tables and
  feature tracks; and added analysis concepts for pipe-sample
  characterization, segmentation, calibration, temperament, and collection
  tuning.
- Added units required by the acoustical domain, including a VAO cent defined
  as exactly 1/1200 octave, cent rates, dBFS, full-scale ratio, fundamental
  periods, and normalized penalties.
- Added Swift and Python semantic validation plus positive and negative cases
  for playback mappings, tuning uniqueness, fixed extraction sources,
  exact-frame observation clocks, and unit correctness.

### Changed

- OrgRec now projects long-take cuts, tuning calibration, collection tuning,
  temperament evidence, sample mappings, loop decisions, and provenance into
  public VAO semantics instead of preserving essential playback data only in
  `payload/orgrec/project.json`.
- Corrected the former `qudt:Centi` use. QUDT has an octave unit but no musical
  cent term at that IRI; 0.2.0 uses the explicitly defined VAO cent and rejects
  the misleading IRI.
- Advanced the VAO mapping identifier and provisional MODAVIS audio module to
  `0.2.0` and updated the release metadata, fixtures, validators, conformance
  matrix, documentation, and release tooling as one contract revision.
- Made standard profile declarations one-to-one with `conformsTo`, fixed their
  profile version at `0.2`, and scoped capability validation to the profile
  record that defines each capability.

## 0.1.1 — prior private implementation snapshot

Private patch-compatible revision of the VAO 0.1 development line. No public
VAO release has yet been made.

### Compatibility

- Keeps the `0.1` compatibility-line schema, context, and profile IRIs. A
  conforming `0.1.0` package remains valid under the 0.1.1 reader contract and
  does not require rewriting solely because the validator version changed.
- Reserves `https://w3id.org/modavis/vao/0.1.1/` as the exact-release IRI while
  retaining `https://w3id.org/modavis/vao/0.1/` as the compatibility-line IRI.
- Requires 0.1.1 writers to emit `formatVersion: "0.1.1"`; 0.1 readers continue
  to accept `0.1.x` and reject other minor lines.

### Added

- Added the modular experiential/XR profile, `experience` and `assetGroup`
  entity kinds, and URI-keyed capabilities for model viewing, synchronized
  media and animation, image-target and surface-placement AR, spatial listening
  maps, offline asset groups, and exclusive replaceable performance media.
- Added provider-neutral physical, coordinate, timeline, transport, carrier,
  animation-target, and selection contracts, with allowlisted declarative
  actions and no executable package code.
- Added an all-capabilities positive fixture and capability-specific negative
  cases, including dependency, graph-closure, target, transport, and action
  validation.
- Added native Swift closed-shape manifest and experiential semantic validation,
  general inspection/workspace/asset-import APIs, and a caller-supplied graph
  writer. OrgRec reports XR behavior as metadata-only instead of claiming a
  renderer or tracking runtime.
- Added preservation-aware OrgRec editing: imported 0.1.x source packages are
  retained by checksum, and their experiential graph, URI-keyed extensions,
  rights/provenance records, and non-OrgRec payloads survive re-export as a new
  VAO revision.

### Changed

- Updated VAOM, OrgRec's VAO contract, the RDF vocabulary, conformance matrix,
  fixtures, release metadata, release builder, release checker, and citation
  metadata to identify the current contract as 0.1.1.
- Documented the patch migration explicitly so the new normative material is no
  longer mislabeled as the earlier 0.1.0 private implementation snapshot.

## 0.1.0 — prior private implementation snapshot

Private preparation for the first public-draft release.

### OrgRec application integration

- Added continuous-stop recording and uncompressed WAV/AIFF long-take import
  with adaptive streaming segmentation, click-resistant period-aware onset
  refinement, frequency-local harmonic-tail preservation, explicit censoring,
  joint MODAVIS sequence assignment for retakes/missing pipes/spurious events,
  exact-frame non-destructive export, review warnings, and source provenance.
- Added multichannel, period-aware sample-loop detection with retained seam
  components and pipe-behaviour summaries; linked exact-frame loop editing;
  immutable reviewed revisions; and sustained note-gate playback with
  equal-power seams, a visible envelope, and recorded-release policies.
- Added loop point sets and reviews to project and capture data, reviewed loop
  segments to IAD, and provisional MODAVIS audio loop/region entities plus
  playable interactions to VAO. Swift and VAOM now validate coordinates,
  source fixity, region cardinality, crossfade, and interaction resolution.

- Added analysis v2 with immutable input-hashed runs, framewise pitch evidence,
  CREPE/normalized-autocorrelation agreement, empirical uncertainty, drift and
  modulation summaries, typed transient censoring, SNR/DC/near-clip checks,
  bounded multichannel reading, and cross-channel correlation/delay evidence.
- Added noise-qualified partial trajectories, pipe spectral summaries,
  uncertainty-bearing VAO/IAD observations, collection-level rank/session
  trends, conservative acoustic-similarity candidates, uncertainty-weighted
  temperament matching, sensitivity trials, and cross-rank consensus.
- Added a linked interactive analysis workspace with synchronized seek/cursor,
  bounded zoom and pan, exact spectrogram-bin inspection, selectable partial
  trajectories, evidence-layer controls, calibrated relative-dB legend,
  confidence/validity/censoring semantics, and accessible interpretation and
  provenance guidance.
- Added staged draggable onset/sustain/key-up/offset/tail adjudication with
  explicit acoustic-phase shading, confidence and censoring states,
  millisecond nudging, chronology validation, reason-required commits, and
  immutable correction history.
- Added probabilistic YIN threshold candidates and Viterbi pitch tracking beside
  CREPE, conservative consensus rules, retained per-estimator observations,
  autocorrelation adjudication, and a critical mismatch review gate that never
  averages conflicting high-confidence values.
- Added physical-pipe-aware roadmap compilation. Source-confirmed pipe mappings,
  shared ranks, borrowed/extended stop relations, and snapshot-bound reviewed
  assertions now collapse duplicate stop/key addresses into one capture target;
  aliases remain searchable provenance and are exported with each take.
- Added conservative overlap review for similar octave stops, complete-pipe-set
  matching for compound stops, locked migration once takes exist, physical vs.
  logical coverage metrics, and consistency validation of every activation route.
- Added safe GrandOrgue ODF inspection, full-tree import, direct VAO conversion,
  and VAO-to-project CLI import.
- Added legacy encoding detection, Windows path normalization, contiguous
  bass/discant stop merging, recursive `REF:` resolution, complete payload
  fixity, and source-rights detection.
- Added a GrandOrgue-first import UI with exact ODF selection, source-link entry,
  preflight identity/rights/disposition inventory, and unresolved-reference gate.
- Added playable-profile interactions for GrandOrgue stops, couplers, and
  tremulants while retaining the source ODF as the complete execution contract.
- Corrected VAO source-bound identifiers so they are not labeled as MODAVIS IDs;
  root entities now carry resolvable source links, builder/date evidence, CC
  license URI, rights holder, and credit line.
- Corrected VAO asset classification so non-audio documentation co-located in an
  original source tree is source evidence rather than an audio master.
- Verified the CC BY-SA 2.5 Bureå Funeral Chapel set through import, 4,738-check
  consistency audit, Swift and VAOM validation, and lossless VAO round-trip.
- Added an end-to-end existing-audio conversion handbook, a machine-readable
  GrandOrgue import-manifest schema, and a reproducible Bureå case study with
  exact identifiers, hashes, graph measures, validation gates, UX decisions,
  privacy limits, and failure semantics.

### Added

- implementation-readiness guidance with a normative-artifact map, safe reader
  pipeline, virtual-instrument import requirements, extension round-tripping,
  support-claim template, and an explicit private-versus-production adoption
  boundary;
- instrument-neutral MODAVIS-derived entity and qualified-relation graph;
- ZIP/ZIP64 `.vao` container and provisional vendor media type;
- JSON Schema 2020-12 manifest, JSON-LD context, and RDF vocabulary;
- complete asset index with media type, semantic role, subject, byte size, and
  SHA-256 fixity;
- paradata, analytical observations, rights, evidence, conflict, configuration,
  interaction, and spatial modeling provisions;
- core, research, playable, spatial, preservation, and OrgRec capture profiles;
- cross-platform VAOM reference writer, reader, validator, inspector, and graph
  authoring commands;
- native OrgRec writer, reader, archive/fixity checker, and lossless
  capture-profile import;
- minimal valid fixture and automated negative conformance tests;
- governance, conformance, release, migration, and implementation guidance;
- immutable ontology/vocabulary binding fields and required asset
  representation status for captured, authored, processed, reconstructed,
  simulated, inferred, or creative content;
- legacy-concept traceability and a fail-closed private release-candidate
  builder with deterministic checksums.

### Release note

Earlier repository text labeled the unpublished working contract `1.0.0`. No
VAO 1.0 release was made. That label is superseded by `0.1.0` and establishes no
compatibility or migration obligation.

No VAO public release has yet been made.
