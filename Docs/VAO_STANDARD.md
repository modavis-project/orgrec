# Virtual Acoustic Object (VAO) Specification 0.2

> Historical document. This is the private 0.2 compatibility-line source, not
> the current public standard. VAO 0.5.0 is maintained at
> <https://github.com/modavis-project/vao-standard> and archived under DOI
> `10.5281/zenodo.22214248`.

Status: private editor's draft  
Target version: 0.2.2  
Publication date: not assigned  
File extension: `.vao`  
Provisional media type: `application/vnd.modavis.vao+zip`  
Exact release IRI (reserved): `https://w3id.org/modavis/vao/0.2.2/`  
Compatibility-line IRI (reserved): `https://w3id.org/modavis/vao/0.2/`

Implementation status: this draft is suitable only as a checksum-pinned private
implementation snapshot for prototypes, research software, internal tools, and
controlled interoperability testing. It is not a published or stable standard,
and a private `0.2.2` package may require migration before the first public
draft. See [`VAO_IMPLEMENTATION_GUIDE.md`](VAO_IMPLEMENTATION_GUIDE.md) for the
reader/importer algorithm, virtual-instrument guidance, and current adoption
limits.

Within the historical 0.2 snapshot, this document,
`Schemas/vao-manifest.schema.json`, and the container and semantic validation
rules named below were normative. Examples, implementation
notes, migration guidance, and benefit explanations are informative unless they
explicitly state a requirement. The key words MUST, MUST NOT, REQUIRED, SHALL,
SHALL NOT, SHOULD, SHOULD NOT, RECOMMENDED, NOT RECOMMENDED, MAY, and OPTIONAL
are to be interpreted as described in BCP 14
([RFC 2119](https://www.rfc-editor.org/rfc/rfc2119) and
[RFC 8174](https://www.rfc-editor.org/rfc/rfc8174)) when, and only when, they
appear in all capitals.

The release IRIs and media type are identifiers reserved by this
specification. They must not be advertised as deployed or registered until the
namespace owner has configured the redirects and the media-type registration
has been completed. Implementations use them now to prevent incompatible local
identifiers from becoming entrenched.

## 1. Purpose and scope

A Virtual Acoustic Object is a portable, self-describing, fixity-protected package for the evidence, structure, sound, appearance, behavior, context, processing history, and analytical results of a musical instrument or other intentionally modeled acoustic object. A VAO can contain audio, 3D geometry, textures, animation, interaction and performance data, spatial-acoustic models, images, documents, measurements, analyses, annotations, rights, and the paradata needed to understand how those resources were created.

VAO 0.2 is object- and environment-neutral. Its primary focus may be an instrument, building, room, acoustic scene, response field, performance, or another typed entity. Pipe organs remain a flagship specialization. Instruments are described through classifications, components, qualified membership, time-scoped configurations, and contextual functional roles; buildings and rooms are described through spaces, boundaries, openings, materials, topology, states, and source/receiver relationships.

The standard has five inseparable layers:

1. a single-file ZIP64 container;
2. a JSON/JSON-LD manifest with a domain-neutral semantic relation graph;
3. an indexed payload with byte size, media type, role, subject, and SHA-256 fixity for every asset;
4. a closed acoustic technical layer for coordinate frames, poses, geometry bindings, materials, responses, metrics, audio scenes, and renderer contracts;
5. normative cross-record and archive validation rules.

The JSON Schema in `Schemas/vao-manifest.schema.json`, the semantic rules in this document, and the container rules together form the normative VAO 0.2 contract. The context and vocabulary files are normative term definitions but do not make unresolved public-namespace deployment claims. Standard manifest keys without a more specific external mapping expand under `https://w3id.org/modavis/vao/ontology#`; localized title, description, label, and rights-statement objects are JSON-LD language maps. Extension keys remain absolute IRIs so an extension cannot silently capture a future standard term. Extension data occurs only in schema-defined `extensions`, `properties`, and parameter objects; arbitrary additional members beside standard fields are invalid.

## 2. Design principles

VAO applies the following requirements throughout the format:

- **FAIR and durable:** stable identifiers, explicit vocabularies, open extraction, fixity, resolvable or embedded evidence, and machine-readable licensing.
- **Lossless before convenient:** preservation masters and raw observations remain distinguishable from derivatives and inferred values.
- **Evidence before flattening:** assertions, disagreements, source fragments, confidence, and editorial decisions are retained instead of silently collapsing them into one value.
- **Function is contextual:** physical identity is separate from the role a component performs in a configuration.
- **State is temporal:** the documented instrument and its condition at capture time are not conflated.
- **Relations are data:** filenames may aid humans but never carry the only copy of an instrument or file relationship.
- **Coordinates are contracts:** every spatial quantity names a frame, unit, axis convention, dimensionality, transform, and uncertainty where known.
- **Evidence, scene, and rendering are separate:** captured evidence is never silently replaced by a semantic model or runtime derivative.
- **Measured, simulated, inferred, and learned differ:** every acoustic representation declares its epistemic status and generating activity.
- **Graceful degradation is declared:** XR/runtime behavior outside a valid domain uses an explicit reject, clamp, nearest, dry-fade, or fallback policy.
- **No unknown permission:** absence of a license never means public-domain or unrestricted use.
- **Representation status is explicit:** direct capture, authored documentation, processing, reconstruction, simulation, inference, and creative transformation are never presented as interchangeable evidence states.
- **A surrogate is not the object:** conformance does not claim completeness, authenticity, or permission to neglect, alter, relocate, or destroy physical heritage.
- **Safe by default:** no active content is executed merely by opening a VAO; paths, sizes, compression, hashes, and references are checked before extraction.
- **Extensible without ambiguity:** extensions use absolute URI keys and must not change the meaning of standard fields.

## 3. Relationship to MODAVIS

VAO 0.2 is derived from the semantic commitments of the MODAVIS Ontology Network:

- `modavis:IdentifiedResource` supplies stable identity;
- `modinst:MusicalInstrument`, `InstrumentState`, `InstrumentConfiguration`, `InstrumentComponent`, `ComponentMembership`, and `FunctionalRoleAssignment` supply the generic instrument model;
- `modevidence:SourceResource`, `SourceSnapshot`, `SourceFragment`, and `EvidenceSupport` supply citable evidence and precise selectors;
- `modassert:Assertion` supplies status, confidence, conflicts, and projection lineage;
- `modevent:Event` remains distinct from `modprov:ProcessingActivity`;
- PROV-O-compatible processing activities and immutable parameter sets supply reproducibility;
- `modorgan:*` is used only by the optional pipe-organ profile.

The MODAVIS ontology available during development is explicitly marked as development status, not a namespace-frozen public release. Every VAO therefore declares a `modavisBinding` with the ontology IRI, exact version/status, optional operational schema release, and VAO mapping version. A released binding additionally requires immutable ontology-version and mapping IRIs. If a vocabulary snapshot is cited, its release IRI and artifact-manifest SHA-256 must occur together. A consumer must not silently reinterpret an old package against a later vocabulary. A package may embed an ontology or Navigator snapshot as an indexed source-evidence asset. VAO version `0.2.2` does not imply that MODAVIS itself has made a numbered public release.

The final public-draft fixture and mapping will additionally pin the exact
MODAVIS ontology version IRI, mapping IRI, and reviewed vocabulary release IRI
and checksum. The last two remain pending while MODAVIS Release 1.3 develops
its structured vocabularies. This does not block container, schema, profile,
validator, or governance preparation.

VAO adds container-level digital assets, interactions, spatial regions, and analytical records needed for exchange while the complete MODAVIS media, measurement, spatial, and SONUS modules remain deferred. Container-specific provisional terms live under the VAO extension namespace. Source-bound signal regions, reviewed sample-loop decisions, protocol-neutral sample playback parameters, tuning maps, and tuning calibration are represented in the provisional `https://w3id.org/modavis/ontology/audio#` module so these semantics are reusable beyond the container; the binding remains explicitly development-status until that module is namespace-frozen.

### 3.1 Existing-dataset migration (informative)

Converting an existing audio collection into VAO is an evidence-preserving
interpretation, not a transcoding shortcut. The converter retains source bytes,
records the descriptor or filename rules used to interpret them, separates
logical observations from shared physical files, assigns source-bound identity
without inventing canonical authority, records rights and unknowns, and
validates both the public graph and any lossless application-state payload.
Validation proves container and contract consistency; it does not prove the
historical truth, completeness, copyright status, or acoustic authenticity of
the source.

OrgRec's complete implementation procedure is in
[`EXISTING_AUDIO_DATASET_TO_VAO.md`](EXISTING_AUDIO_DATASET_TO_VAO.md); the
GrandOrgue adapter and Bureå worked example are in
[`GRANDORGUE_IMPORT.md`](GRANDORGUE_IMPORT.md) and
[`BUREA_GRANDORGUE_VAO_CASE_STUDY.md`](BUREA_GRANDORGUE_VAO_CASE_STUDY.md).

## 4. Container

### 4.1 Physical format

A `.vao` file is a conforming ZIP or ZIP64 archive. General ZIP tools must be able to list and extract it.

Required root entries, in order:

1. `mimetype`, first in the archive, stored without compression, whose complete UTF-8 content is `application/vnd.modavis.vao+zip` with no byte-order mark;
2. `vao-manifest.json`, a UTF-8 JSON document conforming to the VAO manifest schema.

All content assets are stored under `payload/`. `META-INF/` is reserved for future detached signatures and container metadata. Unknown root paths are not conformant.

Writers must support the ZIP stored method. Readers must support stored entries and may support deflate. Encryption is prohibited in the core profile because it prevents independent fixity and preservation checks. Access control belongs at the repository or transport layer. A profile that later defines encryption must state key management, authentication, disclosure, and preservation behavior.

ZIP64 must be used when entry size, archive offset, central-directory size, or entry count exceeds the classic ZIP limit. Writers must use UTF-8 entry names and forward slashes. File modification times in ZIP headers are non-authoritative; manifest timestamps are authoritative.

### 4.2 Path and extraction safety

An entry path must be relative, normalized, UTF-8, and contain neither an empty component nor `.` or `..`. Backslashes, NUL, drive prefixes, absolute paths, symbolic links, hard links, devices, sockets, and overlapping duplicate paths are prohibited. Case-fold collisions are errors for the preservation profile and warnings otherwise.

A reader must validate the central directory, path, declared size, supported compression method, and resource limits before extraction. It must write only beneath the selected destination, must not overwrite existing files unless explicitly requested, and must delete incomplete new destinations after a failed import.

Implementations should expose configurable limits. The reference defaults are 100,000 entries, a 64 MiB manifest, 1 TiB per asset, and 4 TiB total expanded payload. Limit failures are not evidence that a package is semantically invalid; they report that the local implementation cannot safely process it.

### 4.3 Indexed payload

Every non-directory entry below `payload/` appears exactly once in `assets`. Every asset record points to exactly one archive path. No payload file may be hidden from the index, and no asset may point to a missing entry. Structural files (`mimetype`, `vao-manifest.json`, and permitted `META-INF/` records) are not assets, avoiding a manifest self-hash cycle.

Losslessly compressed media such as FLAC, PNG, glTF/GLB, and many video formats should normally be stored without ZIP recompression. Preservation audio may be BWF/WAVE, RF64/BWF, or FLAC when the chosen institutional policy accepts it. The standard does not mandate one content codec; a profile may.

## 5. Manifest information model

### 5.1 Identity and versioning

`id` identifies the conceptual VAO. `revision` increases whenever the manifest or payload changes. `formatVersion` identifies the file contract, not the represented instrument or project. `createdAt` records the first VAO creation time; `modifiedAt` records this revision.

`primaryEntityId` identifies the main subject for discovery and default presentation. `focusEntityIds` is a non-empty ordered set of local entity identifiers and MUST include `primaryEntityId`; it declares every principal subject without pretending that a multi-room, multi-source, or comparative package has only one root. Neither field implies containment or ontology class membership.

Identifiers are absolute HTTP(S) IRIs or URNs. Persistent repository identifiers are preferred. Local resources may use UUID URNs. MDVS identifiers remain external identifiers or resolvable MODAVIS entity IRIs; they must not be invented for locally identified objects.

### 5.2 Entities

`entities` is the node registry. `primaryEntityId` and every `focusEntityIds` value resolve to exactly one entity. The primary entity may be any schema-defined kind with one or more explicit ontology types; an instrument package still types its instrument as `modinst:MusicalInstrument` or a subclass. Each entity has:

- a globally unique identifier within the package;
- a structural `kind` used by lightweight implementations;
- one or more ontology class IRIs in `types`;
- at least one language-tagged or `und` label;
- optional classifications, external identifiers, and URI-keyed properties.

Instrument class coverage is open, not an enum. `classifications` may carry exact Hornbostel-Sachs codes and edition, MIMO concepts, local thesauri, or new MODAVIS instrument types. A VAO must preserve the supplied classification system and code. A consumer must not infer a detailed classification merely from a sample filename or timbral similarity.

Buildings, storeys, spaces, zones, boundaries, openings, acoustic materials,
emitters, receivers, receiver arrays, coordinate frames, acoustic responses,
audio scenes, render configurations, sensors and equipment join physical parts,
abstract component collections, playing interfaces,
configurations, states, events, performances, experiences, logical asset groups,
persons, places, sources, source fragments, measurements, analyses, and spatial
regions can all be nodes. Identity must remain stable across revisions; deleted
nodes are represented through supersession/provenance rather than identifier
reuse.

### 5.3 Relations

`relations` is the authoritative graph. A relation has its own identifier so evidence, status, confidence, provenance, temporal/configuration scope, and later supersession can address the relation itself. It links a subject to either an object identifier or a typed literal, never both.

Core relation patterns include:

- instrument to component through a reified component-membership resource;
- component to contextual functional-role assignment and governed role concept;
- instrument to state and configuration;
- control/initiator to excitation, modulator, generator, resonator, emitter, animation, or sample;
- asset to subject through `aboutEntityIds` plus explicit `hasRepresentation`, `depicts`, `emittedBy`, `usesSample`, or `hasAcousticResponse` relations;
- assertion to subject, governed predicate, object/literal, evidence support, status, and conflict decision;
- processing activity to inputs, outputs, software, actor, and parameter set;
- measurement or analysis to subject, method, unit, uncertainty, and source segment;
- source fragment to page, time range, image region, mesh primitive/node, or 3D bounding region selector.

Relations may use any stable ontology predicate. VAO predicates are provided only where MODAVIS has no released equivalent. Applications must retain unknown predicates and entities on round-trip even if they cannot render them.

### 5.4 Assets

Every asset declares:

- identifier and safe archive path;
- IANA media type;
- exact byte size and lowercase SHA-256;
- one or more governed asset roles;
- one governed representation-status concept;
- one or more subject entity identifiers in `aboutEntityIds`;
- optional original filename, creation time, encoding detail, and technical properties.

`aboutEntityIds` is a discovery link, not a substitute for the relation graph. For example, an audio master can be about a take, the activated component, the instrument state, and the recording place, while explicit relations describe which component emitted the sound and which activity generated the file.

3D runtime assets should prefer glTF 2.x (`model/gltf+json` or `model/gltf-binary`). A geometry binding fixes both the asset hash and a format-specific stable selector: glTF node indices or feature IDs, IFC `GlobalId`, CityGML identifiers, or absolute USD prim paths. A glTF `name` is descriptive and MUST NOT be treated as unique. IFC or CityGML SHOULD remain the authoritative semantic building model when a glTF/USD derivative is supplied for runtime rendering. OBJ, PLY, STL, Gaussian-splat, NeRF, point-cloud, CT, and CAD assets are allowed when their media type and coordinate metadata are declared. Every separate model declares or binds units, handedness, up and forward axes, coordinate reference/anchor, scale, and transformations.

Animation assets should prefer glTF animation channels or an open documented time-series representation. MIDI may be embedded as performance-control evidence but is never the only activation logic: channel, note/control mapping, range, tuning, transposition, velocity/continuous domain, selection state, latency, envelope, loop/release behavior, and target relations must be explicit.

### 5.5 Paradata and provenance

`paradata` records what was done, when, by whom, with which software version and immutable parameters, to which inputs and outputs. Capture, transfer, segmentation, denoising, alignment, photogrammetry, mesh editing, material assignment, simulation, annotation, conversion, validation, migration, and editorial review are all activities.

Raw and processed assets are linked by activities; a derivative never replaces its source. Invasive processing must be declared. Human review and corrections remain distinct from algorithm output. Clock basis, time zone, device identity, calibration, sensor/channel mapping, geometry, environmental conditions, and known interruptions belong in paradata when relevant.

An acoustic activity SHOULD use the closed `method` descriptor and MUST do so when it generates a measured response or metric set. `methodType` distinguishes measurement, deconvolution, spatial registration, material characterization, metric calculation, simulation, auralization, interpolation, machine-learning training/inference, and manual authoring. The descriptor records representation status, exact standard and edition where applicable, protocol asset, equipment, calibration, environmental state, random seed, and quality flags. Detailed instrument settings remain in `parameters` or an indexed protocol asset; a method label alone is insufficient reproducibility evidence.

### 5.6 Analytical data

`analyses` stores a method name and version, generated time, exact inputs and outputs, optional paradata activity, observations, units, uncertainty/confidence, time ranges, and quality flags. Analytical values must never masquerade as documentary facts. A corrected or accepted result is a new assertion or analysis with provenance, not a mutation that erases the original result.

The open observation model covers pitch/tuning, partial tracks, onset/envelope/decay, loudness, spectral features, directivity, impulse-response metrics, geometry, material analysis, condition measurements, and classifier results. Large arrays and matrices belong in indexed payload assets; the manifest links and summarizes them.

An observation's `status` distinguishes `observed` evidence from `inferred`,
`reviewed`, or `accepted` results and from rejected or superseded results.
`applicability` distinguishes a meaningful zero from `notApplicable`, a
`limited` result whose evidence or domain check prevents an unrestricted
claim, and an `indeterminate` measurement. `limited` MUST NOT be interpreted as
an accepted positive classification. `censoring` records left-, right-, or
interval-censored boundaries instead of inventing a point estimate. `coverage`
and `evidenceCount` state how much eligible material supported an aggregate;
`aggregation` identifies the statistic or decision rule. `channelIndices`
select zero-based channels. `qualityFlags` qualify this observation without
invalidating the containing analysis.

`subjectId` identifies what was observed. `sourceRegionId` identifies the
signal region from which the observation was computed. `valueAssetId` points to
an indexed array, feature track, posterior, partial trajectory, spectrogram, or
other result too large for the manifest; the inline `value` remains a compact
summary or a documented selector. These three references MUST resolve within
the package.

Second coordinates are suitable for display and cross-media navigation.
Sample-boundary and loop decisions additionally use a `timeRange` exact-frame
clock: `startFrameInclusive`, `endFrameExclusive`, `sampleRate`, and
`clockAssetId` occur together, identify one indexed audio asset, and denote the
half-open interval `[startFrameInclusive, endFrameExclusive)`. Writers SHOULD
make seconds consistent with frames to within one sample. Exact sample editing
MUST use frames rather than a rounded seconds value.

The following three layers MUST remain distinct:

1. **evidence:** immutable audio, calibration data, framewise measurements,
   uncertainty, coverage, censoring, channel selection, and method paradata;
2. **interpretation:** inferred pitch, onset/offset, pipe identity,
   temperament, outlier status, segmentation, and confidence;
3. **execution decision:** reviewed sample boundaries, accepted loop set,
   target tuning, key/velocity mapping, gain, envelope, and release policy.

A consumer may recompute an interpretation from evidence. It MUST NOT silently
replace an accepted execution decision with the newest algorithm output.

### 5.7 Source-bound signal regions

`modaudio:SignalRegion` is a versioned, source-bound, half-open frame interval.
`SampleExtractionRegion`, `AttackRegion`, `StableSustainRegion`,
`SustainLoopRegion`, and `ReleaseRegion` specialize it without claiming that
every tone has all regions. A region records inclusive start, exclusive end,
sample rate, total source frames, source SHA-256, role, reference channel,
boundary confidence, and censoring when applicable. It links by
`modaudio:appliesToSignal` to exactly one fixed indexed source audio asset. A
derived take or sample links back by `modaudio:extractedFromRegion`.

For classified long takes, a region MAY also carry capture sequence index,
take number, assigned key number, assignment mode, and assignment confidence.
These values preserve retakes, omissions, and spurious events; they do not
authorize a consumer to force the detected count to an assumed compass.

Extraction coordinates describe derivation, not destructive trimming. The
source master remains indexed. A boundary at the file edge is right- or
left-censored unless evidence establishes the physical sound boundary. A
machine MUST NOT infer silence, onset, key release, acoustic offset, or room-tail
termination merely from equality with a file boundary.

### 5.8 Tuning evidence and playback decisions

Pitch measurements use hertz for absolute frequency and
`https://w3id.org/modavis/vao/vocab/unit/cent` for logarithmic intervals. One
VAO cent is exactly 1/1200 octave, so for positive frequencies `f1` and `f2`,
the interval is `1200 × log2(f2/f1)` cents. The misleading
`http://qudt.org/vocab/unit/Centi` IRI MUST NOT be used: it does not identify a
musical cent. QUDT's octave IRI MAY be used for octave-valued observations.

`TuningCalibration` records how a reference was established, including
reference frequency, note/key identity, uncertainty, environment, devices,
time, channel, and source evidence. `TuningMap` is a versioned playback decision
with reference A4 frequency, reference key, optional temperament identifier,
and non-duplicated entries. Each entry has a key number and positive exact
target frequency and may name the sounding component and its cent offset.

A tuning map does not assert that an equal-tempered formula, written pitch,
nominal stop pitch, measured sounding frequency, historical temperament, or
playback target are identical. Implementations SHOULD retain each separately.
MIDI note numbers 0–127 are a portable key index when used, not a requirement
that MIDI transport control the object. A MIDI Tuning Standard export is a
derived protocol binding from the exact frequencies, never the authoritative
source of the VAO tuning decision.

### 5.9 Rights, ethics, and access

At least one rights record applies to the VAO identifier. More specific records may apply to individual assets or entities. A rights record should state license, rights holder, access condition, and credit line when known. When not known, it must say that rights information is unavailable and that no permission is inferred.

Packages containing personal information, precise locations of vulnerable heritage, culturally restricted knowledge, or security-sensitive building data should use a redacted dissemination VAO and retain the full package in controlled preservation storage. Redaction is a documented derivation activity. The core package is not a digital-rights-management system.

Every asset identifies whether it is directly captured, authored, processed, reconstructed, simulated, inferred, or creatively transformed. Reconstruction and simulation must link to their inputs, methods, parameters, and responsible activities; creative transformations must not be advertised as documentary capture. These labels communicate provenance and epistemic status, not a certification of authenticity. A VAO is a digital surrogate and must not be used as evidence that preservation of the physical object, its environment, or its living cultural practices is unnecessary.

## 6. Profiles

Profiles are cumulative contracts identified by URI. A package declares every profile it claims and the capabilities required by each.

Each standard profile identifier MUST occur exactly once in `profiles`, MUST
also occur in `conformsTo`, and MUST declare profile version `0.2`. Conversely,
a standard profile URI in `conformsTo` requires its matching profile record.
A required capability belongs to the profile record that defines it; moving an
acoustic capability to the core or another profile does not satisfy the
acoustics profile.

### 6.1 Core graph profile

URI: `https://w3id.org/modavis/vao/profile/core/0.2`

Requires container conformance, one primary entity, a non-empty focus set that
includes it, complete identifiers, labels, relations, indexed assets, fixity,
rights, MODAVIS binding, and semantic validation. The primary entity MAY be any
schema-defined kind with explicit ontology typing. A metadata-only package is
not a VAO core package; it must contain at least one asset providing evidence
or a representation.

### 6.2 Research profile

URI: `https://w3id.org/modavis/vao/profile/research/0.2`

Requires source snapshots/fragments for important claims, paradata for every generated analytical or derivative asset, explicit method/software/parameters, units and uncertainty where applicable, raw/derivative distinction, and preserved disagreements.

For machine validation in 0.2, the profile additionally requires at least one
paradata activity; every analysis has a `paradataId`; and every
`analysis-result` or `audio-derivative` asset is named in the `outputIds` of a
paradata activity. Qualitative scholarly assessment remains necessary for
whether sources, uncertainty, and disagreement are documented adequately.

VAO 0.2.2 defines six optional research capabilities with additional
machine-verifiable contracts:

- `source-segmentation` requires at least one `SampleExtractionRegion` with
  valid source coordinates/fixity, exactly one matching fixed audio source,
  and at least one active `extractedFromRegion` derivation;
- `acoustical-analysis` requires at least one analysis record; its method,
  immutable inputs, paradata, observation status, units, uncertainty or
  confidence where applicable, and external result assets remain subject to
  research-profile review;
- `tuning-map` requires at least one `TuningMap` with a positive reference A4,
  key 0–127, and one or more unique-key entries with positive target
  frequencies and resolvable component references; each map is actively linked
  from an instrument with `hasTuningMap` or an interaction with `usesTuningMap`;
- `empirical-timbre-classification` requires an
  `empirical-hierarchical-timbre-classification` analysis, an indexed
  `machine-learning-model` asset used as an input to learned
  `machine-learning-inference` paradata, exactly four uniquely identified
  broad-family probabilities in the closed flute, diapason/principal, string,
  and reed target set, finite probabilities in 0…1 summing to one within
  10^-6, and a typed decision. A non-abstained decision requires a selected
  concept. Training labels, corpus fingerprint, instrument-grouped partitions,
  calibration method, out-of-distribution rule, and acceptance threshold
  SHOULD be retained in the model or paradata. Such a result is an acoustical
  inference and MUST NOT replace documentary stop identity or construction
  evidence;
- `pitch-dependent-rank-fingerprint` requires a
  `pitch-dependent-rank-fingerprint` analysis with a non-empty, ascending,
  unique, integer-keyed pitch trajectory and a transition-candidate
  observation.
  Every candidate has ordered lower/upper key numbers, non-negative BIC
  improvement, a family-wise p-value in 0…1, effect size, and interpretation.
  The method activity records immutable parameters and any random seed.
  Candidates MUST be described as acoustical discontinuity evidence, not as a
  definitive construction diagnosis without corroborating organological
  evidence. An empty candidate list is a valid negative result.
- `collection-acoustic-diagnostics` requires `acoustical-analysis` in the same
  research-profile record and at least one
  `evidence-qualified-collection-acoustic-diagnostics` analysis satisfying
  section 6.2.1. Its evidence ledger, robust rank/session aggregates, anomaly
  candidates, and acoustic-similarity candidates remain inferred analytical
  results. They MUST NOT assert physical identity, fault, construction, maker,
  date, or causality without independent evidence.

#### 6.2.1 Collection acoustic diagnostics

The exact capability IRI is
`https://w3id.org/modavis/vao/vocab/capability/collection-acoustic-diagnostics`.
A package declaring it MUST place it in the
`https://w3id.org/modavis/vao/profile/research/0.2` profile record, and that
same record MUST also require
`https://w3id.org/modavis/vao/vocab/capability/acoustical-analysis`. The package
MUST contain at least one analysis whose `analysisType` is
`https://w3id.org/modavis/vao/vocab/analysis/evidence-qualified-collection-acoustic-diagnostics`.
Every analysis of that type in a package claiming the capability MUST satisfy
this section.

This patch-safe contract uses only the existing open `requiredCapabilities`,
`analysisType`, observation `property` and `value`, and paradata `parameters`
seams. It adds no closed manifest member. The schema, context, and research
profile IRIs therefore remain, respectively,
`https://w3id.org/modavis/vao/0.2/schema/manifest.json`,
`https://w3id.org/modavis/vao/0.2/context.jsonld`, and
`https://w3id.org/modavis/vao/profile/research/0.2`.

The analysis `paradataId` MUST resolve to an activity whose closed `method`
descriptor has `methodType: "metric-calculation"` and
`representationStatus: "inferred"`. Its `inputIds` MUST equal the analysis
inputs, and its `outputIds` MUST include the analysis identifier. Its
URI-keyed `parameters` MUST contain
`https://w3id.org/modavis/vao/ontology#parameterSHA256` as 64 lowercase
hexadecimal digits identifying the immutable complete parameter set. The
canonical parameter serialization used for that fingerprint MUST be documented
by the method implementation or an indexed protocol asset.

The following URI-keyed parameters are REQUIRED and have these domains:

- `minimumAggregateQualityScore`, `moderateQualityScore`, and
  `highQualityScore` are finite numbers satisfying
  `0 <= minimum <= moderate <= high <= 1`;
- `minimumAnomalyGroupSize` is an integer of at least 3;
  `anomalyWarningScore` is finite and positive; and
  `anomalyCriticalScore` is finite and not less than the warning score;
- `similarityThreshold` is finite and in `[0,1]`;
  `minimumSimilarityHarmonics` is an integer of at least 3; and
  `maximumSimilarityCandidates` is a positive integer;
- `minimumDriftRepeatedTargets` and `minimumDriftPairComparisons` are positive
  integers, and `minimumDriftSpanHours` is finite and non-negative.

Each name above is expanded against
`https://w3id.org/modavis/vao/ontology#`; for example,
`minimumSimilarityHarmonics` means
`https://w3id.org/modavis/vao/ontology#minimumSimilarityHarmonics`.

The analysis MUST contain each of the following eight governed observations
exactly once and MUST NOT add another observation to that analysis:

| Observation property suffix below `https://w3id.org/modavis/vao/vocab/analysis/collection/` | Value | Required unit | Required aggregation |
| --- | --- | --- | --- |
| `evidence-summary` | object | none | none |
| `take-evidence` | array | none | none |
| `rank-tuning-curves` | array | `https://w3id.org/modavis/vao/vocab/unit/cent` | `https://w3id.org/modavis/vao/vocab/aggregation/quality-weighted-median` |
| `rank-stretch` | array | `https://w3id.org/modavis/vao/vocab/unit/cent-per-octave` | `https://w3id.org/modavis/vao/vocab/aggregation/siegel-repeated-median` |
| `session-offset` | array | `https://w3id.org/modavis/vao/vocab/unit/cent` | `https://w3id.org/modavis/vao/vocab/aggregation/median` |
| `session-drift` | array | `https://w3id.org/modavis/vao/vocab/unit/cent-per-hour` | `https://w3id.org/modavis/vao/vocab/aggregation/within-target-median-slope` |
| `acoustic-anomaly-candidates` | array | none | `https://w3id.org/modavis/vao/vocab/aggregation/robust-multivariate-distance` |
| `acoustic-similarity-candidates` | array | none | `https://w3id.org/modavis/vao/vocab/aggregation/harmonic-aligned-cosine` |

All eight observations MUST have `status: "inferred"`, MUST resolve the same
`subjectId` to the analyzed collection or focus acoustic object, and MUST carry
an applicability consistent with their value and evidence. A non-finite JSON
number is invalid. Insufficient evidence MUST be represented by an empty array,
`null` at a specifically nullable estimate, `limited` or `indeterminate`
applicability, and an explanatory quality flag as appropriate; it MUST NOT be
represented as a numeric zero.

The `evidence-summary` value MUST contain non-negative integer
`eligibleTakeCount`, `analyzedTakeCount`, `aggregateTakeCount`,
`highQualityCount`, `moderateQualityCount`, `limitedQualityCount`, and
`excludedCount`, plus finite `aggregateCoverage` in `[0,1]`. The following
identities MUST hold:

```text
analyzedTakeCount <= eligibleTakeCount
aggregateTakeCount <= analyzedTakeCount
highQualityCount + moderateQualityCount + limitedQualityCount = aggregateTakeCount
highQualityCount + moderateQualityCount + limitedQualityCount + excludedCount = eligibleTakeCount
abs(aggregateCoverage - aggregateTakeCount / eligibleTakeCount) <= 10^-9
```

When `eligibleTakeCount` is zero the coverage is exactly zero. The `take-evidence`
array MUST have exactly `eligibleTakeCount` entries, one per unique resolved
`takeId`, and the set of those identifiers MUST equal the analysis `inputIds`.
Each entry MUST have a resolved `rankGroupId`, integer `keyNumber` in 0…127,
finite `qualityScore` in `[0,1]`, tier `high`, `moderate`, `limited`, or
`excluded`, and Boolean `includedInAggregates`; the Boolean is true exactly for
the first three tiers. Excluded evidence SHOULD retain machine-readable reasons
and every entry SHOULD retain available quality dimensions and quality flags.

Each rank curve MUST have a unique resolved `rankGroupId`, a non-empty
`groupingBasis`, and one or more points in strictly ascending unique key order.
Every point has an integer `keyNumber` in 0…127, finite
`medianDeviationCents`, finite non-negative
`medianAbsoluteDeviationCents`, and positive integer `evidenceCount`. A
rank-stretch entry, when present, MUST use a resolved unique `rankGroupId`, a
finite `stretchCentsPerOctave`, a non-empty method description, and a positive
evidence count; a session-offset entry MUST use a resolved unique `sessionId`,
finite `medianDeviationCents`, and positive evidence count.

Session drift MUST compare repeated measurements of the same acoustic target
within one documented setup/channel stratum; a producer MUST NOT regress
unrelated notes against time. Each session entry has a unique resolved
`sessionId`, non-negative integer `repeatedTargetCount` and
`pairComparisonCount`, and applicability `applicable` or `indeterminate`. A
finite `driftCentsPerHour` is permitted only for `applicable` entries whose
declared repeated-target, pair-comparison, and time-span minima are met. An
insufficient result MUST encode `driftCentsPerHour: null` and
`applicability: "indeterminate"`.

An anomaly entry MUST refer to a unique take in the evidence ledger, carry a
finite non-negative `robustDistance`, finite `qualityScore` in `[0,1]`, and
severity `warning` or `critical` consistent with the declared thresholds. It
is a review candidate, not a fault or construction diagnosis. A similarity
entry MUST refer to two distinct ledger takes in ascending identifier order;
the unordered pair MUST be unique. Its finite `cosineSimilarity` lies in
`[0,1]` and meets the declared threshold, its integer `sharedPartialCount`
meets the declared minimum, and its non-empty `interpretation` MUST explicitly
use the word “candidate.” The list MUST NOT exceed
`maximumSimilarityCandidates`. Similarity is harmonic-aligned acoustic
evidence only and MUST NOT be asserted as evidence of common physical identity.
An empty anomaly or similarity array is a valid negative result.
Informative processing and presentation guidance is in
[`COLLECTION_ACOUSTIC_DIAGNOSTICS.md`](COLLECTION_ACOUSTIC_DIAGNOSTICS.md).

### 6.3 Playable profile

URI: `https://w3id.org/modavis/vao/profile/playable/0.2`

Requires an explicit interaction graph, controller mapping, playable range/domain, configuration/selection logic, sample or synthesis targets, timing behavior, loop/release policy, and rights sufficient for the intended execution environment. MIDI 1.0, MIDI 2.0/UMP, OSC, or another protocol may be a binding, not the logical model.

The 0.2 machine-verifiable minimum is at least one `interaction` entity. Every
interaction has URI-keyed `interactionType`, `controlProtocol`, `controlDomain`,
and `timingPolicy` properties and at least one outgoing `activates` or `modulates`
relation. Sample-based interactions additionally use `usesSample`; animation-
driving interactions use `drivesAnimation`. The property values retain the
complete channel/message/range, selection, latency, envelope, loop, and release
details needed by the relevant binding.

Sample-clock looping uses a `loopPointSet` and exactly one `signalRegion` per
playable set. The set is typed `modaudio:LoopPointSet`, links to fixed audio via
`modaudio:appliesToSignal`, and links its region with
`modaudio:hasLoopRegion`. Coordinates are half-open
`[modaudio:startFrameInclusive, modaudio:endFrameExclusive)` at the declared
sample rate, with crossfade in frames. An accepted set is linked from its
interaction by `modaudio:usesLoopPointSet` alongside `vao:usesSample`.
Reviewed revisions use `prov:wasRevisionOf` and review paradata. Validators
check bounds, source fixity, cardinality, crossfade, and playable resolution.

The optional `sampled-instrument-playback` capability makes a sample collection
directly instantiable without relying on filenames or private application
state. It requires the playable profile and at least one `parameterSet` typed
`modaudio:SamplePlaybackParameters`. Each parameter set MUST contain:

- root, minimum, and maximum key numbers in 0–127 with the root inside the
  range;
- minimum and maximum velocity in 0–127 in ascending order;
- positive target frequency, numeric gain, and one of
  `preserveRecordedPitch`, `resampleToTarget`, or `disabled` as its pitch mode;
- positive measured `sourceFundamentalHz` when resampling to target;
- an envelope with non-negative attack/release seconds, sustain level 0–1,
  and `linear`, `equalPower`, or `natural` curve;
- reviewed or accepted status.

It SHOULD additionally carry normalization gain, tuning offset, channel policy,
note-off policy, round-robin group/index, selection priority, and latency
compensation where those affect rendering. A playable interaction links to the
parameters with `modaudio:usesPlaybackParameters`, to exactly one indexed audio
sample with `vao:usesSample`, to its sounding component with `vao:activates`,
and to a tuning map with `modaudio:usesTuningMap` when target frequencies come
from that map. Recorded-release playback links a reviewed `ReleaseRegion` with
`modaudio:usesReleaseRegion`; a synthetic envelope does not erase or imply a
recorded release.

Multiple takes of one pipe are represented as separate parameter sets and
samples. Round-robin grouping, priority, and velocity domains express their
selection. Missing pipes remain absent or explicitly asserted as missing;
validators MUST NOT synthesize a complete compass from an assumed stop range.

### 6.4 Spatial profile

URI: `https://w3id.org/modavis/vao/profile/spatial/0.2`

Requires the top-level `acoustics` object, at least one coordinate frame, and at least one pose or geometry binding. A coordinate frame declares 2D/3D dimension, coordinate type, absolute unit IRI, handedness, up axis, forward axis, optional CRS, optional parent, and an invertible 4×4 transform to that parent. Parent frames form an acyclic graph. Matrices are column-major; orientations are normalized XYZW quaternions. Implementations MUST NOT infer axis conventions from a file extension.

A pose binds one entity to a frame and a 2D/3D position, with optional orientation, extent, uncertainty, configuration/state, validity interval, and trajectory. A trajectory is an indexed asset with declared interpolation; dynamic positions are never encoded only in a filename or engine script. Registration uncertainty SHOULD record method, unit, RMS or covariance, and confidence. Implementations converting glTF to OpenXR account explicitly for glTF's right-handed +Y-up/+Z-forward convention and OpenXR's right-handed +Y-up/−Z-forward view convention.

A geometry binding binds an entity, one fixed indexed asset, a role, and a format-specific selector. `authoritative-semantic`, `acoustic-simulation`, `runtime-visual`, `collision`, `occlusion`, and `navigation` roles prevent one simplified mesh from silently becoming the source for every task. A transform or selector that cannot be resolved is a conformance error, not a hint.

### 6.5 Acoustics profile

URI: `https://w3id.org/modavis/vao/profile/acoustics/0.2`

Requires the spatial profile, the closed top-level `acoustics` object, and at least one acoustic capability. The object has eight closed registries: `coordinateFrames`, `poses`, `geometryBindings`, `materialModels`, `responseSets`, `metricSets`, `audioScenes`, and `renderConfigurations`. Empty registries are explicit. Their identifiers share the package-wide identifier space.

#### 6.5.1 Semantic building and acoustic scene

Building descriptions use entities of kind `building`, `storey`, `space`, `zone`, `boundary`, `opening`, and `material`. Relations express containment, `vao:boundedBy`, `vao:separates`, `vao:connects`, and `vao:hasAcousticMaterial`. A boundary may separate two spaces; an opening or portal connects spaces and may carry state/configuration scope. Geometry alone does not imply topology. The `semantic-building-model` capability requires building, space, and boundary entities plus an `authoritative-semantic` geometry binding. IFC 4.3 or CityGML 3.0 SHOULD be used for authoritative building semantics when available; glTF or USD SHOULD be retained as a linked runtime derivative.

Room acoustics describes the sound field within a space. Building acoustics describes transmission between a source space and receiving space through a separating element and possibly multiple direct/flanking paths. A building-acoustic measurement or metric MUST therefore name source space, receiving space, and separating element; `transmissionPathIds` SHOULD enumerate known paths. The two disciplines MUST NOT be collapsed into a single unlabeled reverberation metric.

#### 6.5.2 Acoustic materials

A material model binds a material entity to a positive, strictly ascending frequency axis and equal-length absorption coefficients. Optional scattering, transmission loss, surface impedance, incidence convention, sidedness/layering, thickness, environmental state, uncertainty, epistemic status, and generating paradata preserve simulation meaning. Absorption and scattering lie in `[0,1]`; transmission loss is non-negative dB. Visual PBR material values MUST NOT be interpreted as acoustic coefficients. Geometry-acoustic rendering requires acoustic material models and SHOULD report boundary coverage and fallback material policy.

#### 6.5.3 Impulse responses and acoustic fields

A response set declares response kind, indexed data asset, encoding, convention, epistemic status, sample rate where applicable, time-zero/delay policy, normalization/calibration, channel topology, one or more source/receiver measurement mappings, and generating activity. Every mapping names source and receiver entities and their poses, plus space, configuration, state, and validity where applicable.

AES69-2022 SOFA 2.1 is RECOMMENDED for HRTF/HRIR, BRIR/SRIR, source directivity, sound-field, and multi-position response data. The SOFA convention name MUST be recorded. WAVE or FLAC MAY represent one fixed source–receiver pair without interpolation; it MUST NOT be used as an ambiguous substitute for a multidimensional response set. A measured response requires measurement/deconvolution paradata and an `impulse-response` asset role. Time-zero and normalization MUST be explicit; absence is represented as `unspecified`, never guessed.

An interpolation contract declares method, valid spatial domain, outside-domain policy, optional fallback response, and quality metric set. Nearest, linear, barycentric, spherical-harmonic, radial-basis, physics-based, neural-field, and hybrid methods are distinguished. Interpolation MUST NOT imply measured coverage between samples.

Learned/differentiable/neural acoustic fields are emerging representations, not measurements. A neural-field response MUST have `learned` or `hybrid` status and name the fixed model asset, training and validation inputs, quality metric set, valid domain, determinism/seed, and a non-learned fallback response. The model asset has the `acoustic-model` role and is the output of `machine-learning-training` paradata; the response-generating `machine-learning-inference` activity uses that fixed model as an input. Training inputs remain indexed evidence with rights and provenance. A generated response retains the model/activity link. Packages SHOULD report held-out position/orientation performance, early/late response error, spectral error, perceptual evaluation, room/configuration coverage, and known sim-to-real limitations. The `learned-acoustic-field` capability is therefore safe to negotiate without claiming physical truth.

#### 6.5.4 Metrics

A metric set records an exact standard URI and edition, method, subjects, inputs, frequency-band axis, uncertainty, generating paradata, and aligned metric arrays. Room-acoustic parameters SHOULD identify ISO 3382-1/2 or another exact method; building transmission SHOULD identify ISO 16283 and/or ISO 12354 as applicable; material measurements SHOULD identify ISO 354 or ISO 17497; speech transmission SHOULD identify IEC 60268-16; uncertainty SHOULD identify the applicable ISO 12999 method. A bare label such as `RT60` is insufficient when estimator, decay range, bands, averaging, and source/receiver pair are unknown.

#### 6.5.5 Spatial audio scenes and runtime rendering

An audio scene binds a typed scene entity, coordinate frame, indexed media, optional metadata, and entity-to-media bindings. Supported representation classes are ITU ADM in BW64, MPEG-I immersive audio, MPEG-H 3D Audio, channel beds, object audio, higher-order Ambisonics, binaural audio, and hybrids. ITU ADM/BW64 packages SHOULD use ITU-R BS.2076-3 and BS.2088-2. Interactive six-degree-of-freedom packages SHOULD use ISO/IEC 23090-4:2025 (MPEG-I immersive audio) when an interoperable coded representation is required. An audio scene representation does not erase the VAO semantic or evidence layers.

OpenUSD `UsdMediaSpatialAudio` MAY be used in a runtime scene derivative for
transformable spatial/non-spatial audio placement and time-synchronized
playback. Its absolute prim path is the stable geometry selector. Its basic
file, gain, timing, looping, and aural-mode properties do not substitute for a
VAO response set, measurement provenance, semantic audio binding, or renderer
contract.

A render configuration is declarative and safe: it identifies scene, strategy, coordinate frame, input resources, listener binding, runtime features, valid domain, outside-domain policy, fallbacks, transitions, latency budget, optional levels of detail, and renderer requirements. It MUST NOT contain executable scripts. Strategies include static playback, tracked convolution, response interpolation, geometry acoustics, MPEG-I 6DoF, learned field, and hybrid rendering. Features independently declare distance, directivity, occlusion, diffraction, early reflections, late reverberation, Doppler, portals, listening-room adaptation, and source tracking as disabled, metadata-driven, response-driven, geometry-driven, or renderer-defined.

Tracked listening binds a fixed, 3DoF, 6DoF, or trajectory listener to a receiver and coordinate frame. Optional HRTF personalization and headphone compensation are indexed assets with rights; they MAY be locally substituted without changing the preserved scene. A renderer MUST apply the declared outside-domain policy and SHOULD choose the highest supported level of detail whose inputs and resource limits it satisfies. If it cannot satisfy a required strategy or codec, it MUST report the unsupported capability and MAY follow a declared fallback; silent semantic degradation is prohibited.

#### 6.5.6 Acoustic capability identifiers

The standard capabilities are `semantic-building-model`, `measured-impulse-response`, `spatial-response-field`, `source-directivity`, `room-acoustic-metrics`, `building-acoustic-performance`, `spatial-audio-scene`, `tracked-listener-convolution`, `tracked-sources`, `geometry-acoustic-rendering`, `hybrid-acoustic-rendering`, and `learned-acoustic-field`, each under `https://w3id.org/modavis/vao/vocab/capability/`. `tracked-sources` requires a render configuration with a non-disabled `source-tracking` feature and explicit local input identifiers; the inputs identify the tracked emitters, poses, trajectories, or tracking data used by that renderer. A profile claim is an enforceable minimum, not advertising text; validators check the required records and links.

### 6.6 Preservation profile

URI: `https://w3id.org/modavis/vao/profile/preservation/0.2`

Requires preservation-suitable codecs, original filenames, creation/capture times, complete technical metadata, no case-fold path collisions, complete rights/access statements, provenance for every derivative, validated fixity, and repository migration/version history.

The 0.2 machine-verifiable minimum requires `originalFilename` and `createdAt`
on every asset, a non-empty access condition on every rights record, no
case-fold path collisions, and paradata output linkage for every asset with an
`analysis-result` or `audio-derivative` role. Codec suitability, metadata
completeness, repository policy, and long-term preservation remain subject to
the receiving archive's documented policy.

### 6.7 Experiential/XR profile

URI: `https://w3id.org/modavis/vao/profile/experiential/0.2`

The experiential profile describes application-neutral ways to present and
stage VAO content. It does not name routes, UI components, engine classes,
filenames, ZIP paths, or a particular XR SDK. A package claims one or more of
the following standard capabilities in the experiential profile's
`requiredCapabilities` array:

- `https://w3id.org/modavis/vao/vocab/capability/generic-model-viewing`;
- `https://w3id.org/modavis/vao/vocab/capability/synchronized-media-animation`;
- `https://w3id.org/modavis/vao/vocab/capability/image-target-ar`;
- `https://w3id.org/modavis/vao/vocab/capability/surface-placement-ar`;
- `https://w3id.org/modavis/vao/vocab/capability/spatial-listening-map`;
- `https://w3id.org/modavis/vao/vocab/capability/offline-asset-groups`;
- `https://w3id.org/modavis/vao/vocab/capability/replaceable-performance-media`.

Every claimed standard capability has at least one entity of kind `experience`
whose URI-keyed `vao:experienceCapability` property equals that capability IRI.
Each such entity has an active `vao:presents` relation to a local entity. An
active relation has status `asserted`, `accepted`, or `inferred`; rejected and
superseded relations do not satisfy a profile requirement. `vao:presents`
always targets an entity identifier, never an asset identifier. Other profile
relations target entities or indexed assets as specified below. This graph,
not a filename or directory convention, is authoritative.

The machine-verifiable capability contracts are:

1. **Generic model viewing.** The experience presents the primary entity or a
   spatial region and links with `vao:usesModel` to an indexed asset having the
   `three-dimensional-model` or `spatial-model` role. The model asset has
   URI-keyed `vao:coordinateSystem`, `vao:coordinateUnit`, `vao:handedness`,
   `vao:upAxis`, and `vao:physicalDimensions` properties. `coordinateUnit` is
   an absolute unit IRI; handedness is `left` or `right`; up-axis is `X`, `Y`,
   or `Z`; and `physicalDimensions` is an object with positive numeric `width`,
   `height`, and `depth` plus an absolute `unit` IRI. This capability requires
   the spatial profile.
2. **Synchronized media and animation.** The experience presents the primary
   instrument and links with `vao:hasPerformance` to a `performance` entity.
   The performance links with `vao:usesMedia` to at least one indexed audio or
   video asset having the `performance-media` role, and with
   `vao:drivesAnimation` to at least one indexed asset having the `animation`
   role. Its URI-keyed `vao:timelineClock` is an object with an absolute
   `timeUnit` IRI, positive numeric `duration`, and optional non-negative
   numeric `offset`. A pre-rendered performance does not require the playable
   profile. If it has a `vao:triggeredBy` relation, every target is an
   `interaction` entity and the package also claims the playable profile.
3. **Image-target AR.** The experience presents the primary entity or a
   spatial region, uses a conforming model through `vao:usesModel`, and links
   with `vao:usesTarget` to an indexed `image/*` asset having the `image-target`
   role. The target asset's URI-keyed `vao:physicalDimensions` contains
   positive `width` and `height` plus an absolute unit IRI. Optional
   precomputed, engine-specific tracking bytes are separate indexed assets
   having the `tracking-data` role and are linked through
   `vao:usesTrackingData`; they never replace the canonical target image. This
   capability requires the spatial profile.
4. **Surface-placement AR.** The experience presents the primary entity or a
   spatial region and uses a conforming model through `vao:usesModel`. Its
   URI-keyed `vao:placementPolicy` object has `surfaceAlignment` equal to
   `horizontal`, `vertical`, or `any`; `modelAnchor` equal to `origin` or
   `base-center`; and a Boolean `allowUniformScale`. This capability requires
   the spatial profile.
5. **Spatial listening map.** The experience presents a `place` or
   `spatialRegion` and links through `vao:hasListeningPoint` to one or more
   `spatialRegion` entities. Each point has the spatial-profile coordinate
   properties and a URI-keyed `vao:position` object containing numeric `x`,
   `y`, and `z` and an absolute `unit` IRI equal to its `coordinateUnit`. Each
   point links through `vao:usesMedia` to at least one indexed `audio/*` asset
   having the `spatial-listening-audio` role. This capability requires the
   spatial profile. It does not imply that a recording is an impulse response
   or scientifically calibrated spatial-acoustics measurement. Tracked 3DoF
   or 6DoF listening, dynamic sources, response interpolation, and geometry
   rendering instead link an acoustic audio scene and render configuration and
   claim the relevant acoustics capability.
6. **Offline asset groups.** The experience presents the primary entity and
   links through `vao:offersAssetGroup` to one or more `assetGroup` entities.
   Each group links through `vao:includesAsset` to at least one indexed asset.
   Its URI-keyed `vao:assetGroupPolicy` object has `availability` equal to
   `offline-optional` or `offline-required`, `selection` equal to `independent`
   or `exclusive`, and Boolean `defaultSelected`. Asset groups express logical
   acquisition and cache units; they do not weaken asset-level fixity, rights,
   or payload indexing and do not prescribe cache keys or storage APIs.
7. **Replaceable performance media.** The experience presents the primary
   instrument, has URI-keyed `vao:selectionPolicy` equal to `exclusive`, and
   links through `vao:offersConfiguration` to at least two `configuration`
   entities. Each configuration links through `vao:usesCarrier` to exactly one
   distinct `digitalObject`. Each carrier links through `vao:hasLabelImage` to
   at least one indexed `image/*` asset with the `carrier-label-image` role and
   through `vao:hasPerformance` to at least one `performance`. Each performance
   has the synchronized `timelineClock`, links to audio `performance-media`
   through `vao:usesMedia`, links to animation assets through
   `vao:drivesAnimation`, and links through `vao:targets` to one or more local
   target entities. The performance's URI-keyed `vao:transportPolicy` is exactly
   `{masterClock: "audio", start: "explicit", pause: "hold", stop: "reset",
   seek: "allowed"|"forbidden"}`; audio is therefore authoritative for
   animation phase and transport state.

   Every animation asset has URI-keyed `vao:animationBindings` with
   `blendPolicy` equal to `parallel` or `ordered` and a non-empty `layers`
   array. A layer contains only a non-empty `clip` identifier and a non-empty
   `targetEntityIds` array; each target is a local entity also linked from the
   performance with `vao:targets`. Clip identifiers address animation channels
   within the indexed animation asset and are not archive paths.

   The experience links with `vao:hasInteraction` to one or more `interaction`
   entities. Each interaction has URI-keyed `vao:actionSequence`, a non-empty
   array of objects containing only `action` and `targetId`. Actions are limited
   to `select`, `install`, `eject`, `play`, `pause`, `stop`, `seek`, and
   `restart`; targets are local configuration, carrier, or performance entities
   appropriate to the action. Across the experience the sequences include at
   least `select`, `install`, `eject`, `play`, and `stop`. These records are
   declarative state transitions, never scripts, expressions, command lines,
   callback names, or fetch instructions. This capability does not require the
   playable profile because pre-recorded media transport is not acoustic
   instrument excitation; a package that also exposes playable controls claims
   that profile separately.

The profile is modular: claiming it does not imply all seven capabilities. An
implementation reports each required capability as supported or unsupported
and may continue to expose the remaining valid core graph. Unknown future or
third-party required capabilities are retained and reported as unsupported;
they are not inferred from media types or filenames. Playable keyboard,
register, MIDI, OSC, sample, synthesis, loop, and release behavior remains in
the playable profile and composes with, but is not redefined by, this profile.

### 6.8 OrgRec capture profile

URI: `https://w3id.org/modavis/vao/profile/orgrec-capture/0.2`

Requires the core and research profiles, a lossless `payload/orgrec/project.json`, all original OrgRec package content below `payload/orgrec/`, typed entities for recording sessions, takes, roadmap components and analyses, and graph links from every audio asset to take, component, primary instrument, session/activity, and analysis. This profile enables editable round-trip import without making the private OrgRec project model the public VAO semantics.

## 7. Conformance

Conformance has three levels and all must pass:

1. **container:** ZIP structure, first mimetype entry, allowed paths/methods, no duplicates or unsafe types;
2. **schema:** `vao-manifest.json` validates against the JSON Schema;
3. **semantic:** identifiers are globally unique, primary/focus entities resolve, every local reference resolves, every payload path is indexed once, sizes/hashes match, rights apply, profile requirements hold, coordinate graphs are acyclic and invertible, quaternions and band arrays are valid, response links and domain policies are complete, time intervals are ordered, and relation subjects exist.

A validator must distinguish errors from warnings. Unknown extension properties and predicates are retained and are not errors. An unsupported declared required capability means the consumer cannot fully process the VAO; it does not by itself make the package invalid.

For deterministic comparison and signatures, implementations should serialize the manifest with RFC 8785 JSON Canonicalization Scheme. Signatures are optional in 0.2; fixity is mandatory. A future signature profile will define the exact signature envelope, trust policy, revocation, and relationship to repository preservation events.

## 8. Versioning and compatibility

VAO uses Semantic Versioning for the format contract. During the `0.x`
development series, the minor component is the compatibility boundary:

- `0.2.z` patch releases may clarify text, repair validators, or add optional
  capability contracts without invalidating conforming earlier `0.2.x`
  packages;
- `0.4.0` is the current pre-public target for breaking schema or semantic changes and therefore uses immutable
  schema, context, and profile IRIs;
- `1.0.0` will be the first namespace-frozen stable contract and will require
  demonstrated interoperability, governance, published identifiers, and a
  documented migration from the final `0.x` release.

A `0.2.x` reader must ignore and preserve unknown optional extension values
whose keys are absolute URIs, but must report an unknown required profile
capability as unsupported. It must reject another minor compatibility line
rather than guessing. The `revision` field versions an individual VAO object;
it is independent of `formatVersion`.

VAO 0.2.0 established the breaking pre-public 0.2 compatibility line after
the private 0.1.x snapshots. It replaced `rootEntityId` with `primaryEntityId`
plus `focusEntityIds`, moved spatial requirements into closed
machine-actionable records, and introduced
the acoustics profile. A 0.1.x package is not a 0.2.x package merely because
its version string changes. VAO 0.2.1 is a backward-compatible patch that added
the optional empirical-timbre and rank-fingerprint capability contracts and
the `limited` observation applicability value. VAO 0.2.2 is a
backward-compatible patch that adds the optional evidence-qualified collection
acoustic diagnostics contract without changing the 0.2 schema, context, or
profile IRIs. Neither patch invalidates a conforming earlier 0.2.x package.
Producers implementing this snapshot emit `formatVersion: "0.2.2"`; readers
accept other 0.2.x patches according to their declared capabilities and reject
another minor compatibility line rather than guessing. The reference
`migrate-0.1` command copies an unpacked source, rewrites unambiguous fields,
and reports facts requiring review. A reader must not relabel or overwrite an
unchanged source package. Any migrated or otherwise modified archive is a new
immutable package revision.

Revision history is append-oriented: each released `.vao` is immutable, receives its own checksum and preferably a persistent repository version identifier, and points to predecessor/successor entities through provenance. Mutable desktop workspaces are authoring state, not released archive revisions.

Migration must produce a new package, retain the source manifest as an indexed
evidence asset, record the migration activity, software, source-manifest hash,
mapping version, and warnings or losses, and must never overwrite the source
VAO. The new archive checksum is emitted in an external migration or release
receipt after packing; it cannot be embedded in the archive it hashes without
creating a self-reference cycle.

## 9. Recommended asset practices

- Audio masters: BWF/RF64 or institutionally approved lossless encoding; declare sample rate, channels, bit depth, channel roles, time reference, microphone/source/receiver geometry, calibration, and processing state.
- Sample instruments: preserve long-take masters and exact extraction regions; retain attack, stable sustain, key-up, acoustic offset, room tail, censoring, source/target pitch, tuning calibration, per-key target frequencies, gain, channel policy, loop candidates and accepted loop, release region, envelope, round-robin/retake group, selection priority, and reviewer provenance. Missing notes and duplicate takes are data, not filename errors.
- 3D: glTF 2.x where practical; preserve acquisition outputs separately; declare units, axes, transformations, topology changes, decimation, texture/color calibration, and segment identifiers.
- Animation/control: open timestamped events or glTF animation; declare clock/timebase, target, initial/final state, latency, interpolation, and physical constraints.
- Impulse responses: AES69 SOFA for spatial or multidimensional response sets; WAV/FLAC only for a single fixed pair. Always declare source/receiver poses, excitation/deconvolution, sample rate, time zero, normalization, calibration, environment/state, and measured/simulated/inferred/learned status.
- Images/video: retain capture metadata and color profile; relate regions and time ranges to entities.
- Tabular/array data: CSV for simple tables; JSON, HDF5, Zarr, or another documented format for complex arrays. Keep a human-readable data dictionary.
- Documents: prefer archival PDF/A or open text alongside source formats when rights permit; selectors identify exact pages/regions.

## 10. Benefits and how the standard realizes them

| Benefit | Concrete mechanism |
| --- | --- |
| One portable object | ZIP64 `.vao` with all indexed payloads and an open extraction path |
| No filename-only semantics | First-class entities, relations, roles, states, configurations, and source selectors |
| All instrument classes | Generic MODAVIS instrument/component model plus open classifications and contextual functions |
| Reproducible research | Immutable inputs, activities, software versions, parameters, observations, uncertainty, review history, and hashes |
| Preservation and integrity | SHA-256 for every asset, no hidden payload, lossless source/derivative distinction, versioned immutable releases |
| Interoperability | JSON Schema, JSON-LD context, URI predicates, media types, MODAVIS binding, standard ZIP/ZIP64 |
| Playable/interactive reuse | Protocol-independent interaction graph linked to samples, synthesis, animation, and components |
| Spatial and AR reuse | Explicit coordinate frames, stable model selectors, poses, response fields, spatial audio scenes, and renderer fallbacks |
| Room/building acoustics | Topology, frequency-dependent materials, response/metric sets, source and receiving spaces, elements and paths |
| Emerging virtual acoustics | Learned-field status, fixed models and data lineage, validity/quality domains, deterministic fallback, hybrid rendering |
| Evidence-aware scholarship | Assertions, source snapshots/fragments, support/opposition, conflicts, confidence, and accountable decisions |
| Responsible dissemination | Per-object rights/access statements, no implied license, provenance-preserving redaction |
| Honest reconstruction and creative reuse | Required representation status plus activity/input lineage distinguishes capture, processing, reconstruction, simulation, inference, and creative transformation |
| Broad and equitable access | Open ZIP/JSON/JSON-LD extraction, a dependency-free cross-platform CLI, open format preferences, and no requirement for proprietary authoring software |
| Efficient exchange | Already-compressed media may be stored without recompression; large data use ZIP64; profiles allow capability negotiation |
| Sustainable evolution | Semantic versioning, absolute-URI extensions, explicit ontology/mapping binding, loss-recording migrations |

## 11. Non-goals

VAO 0.2 does not define one universal sampler, physical-synthesis engine, acoustic simulator, 3D renderer, HRTF-personalization method, controller protocol, repository API, or commercial plugin format. It transports the logical and evidential information those systems need. It does not certify the historical truth, scientific quality, copyright status, or perceptual authenticity of content merely because a package validates.

## 12. Normative artifacts and reference implementation

- `Schemas/vao-manifest.schema.json` - JSON Schema 2020-12 contract.
- `Schemas/vao-context.jsonld` - JSON-LD term mapping.
- `Schemas/vao-vocabulary.ttl` - VAO extension vocabulary and seed concepts.
- `Schemas/modavis-audio-loop.ttl` - provisional, reusable MODAVIS audio module
  defining exact-frame regions, loop point sets, sample playback parameters,
  tuning maps, and calibration.
- `Tools/vaom.py` - cross-platform standard-library reference manager/validator.
- `Sources/OrgRecCore/VAO*.swift` - native OrgRec exporter, profile-scoped
  archive/fixity checker, archive codec, and importer.
- `Docs/VAO_ORGREC_PROFILE.md` - OrgRec mapping and migration behavior.
- `Docs/VAO_IMPLEMENTATION_GUIDE.md` - adoption status, importer sequence,
  playable-instrument consumption, and support-claim guidance.
- `Docs/EXISTING_AUDIO_DATASET_TO_VAO.md` - OrgRec's evidence-preserving conversion handbook.
- `Docs/GRANDORGUE_IMPORT.md` - GrandOrgue adapter mapping and safety behavior.
- `Docs/BUREA_GRANDORGUE_VAO_CASE_STUDY.md` - executed Bureå conversion and validation record.
- `Schemas/grandorgue-import-manifest.schema.json` - OrgRec-specific GrandOrgue import-evidence contract; informative for VAO conformance.
- `Docs/VAOM.md` - Virtual Acoustic Object Manager usage and architecture.
- `Docs/VAO_CONFORMANCE.md` - testable conformance classes and release suite.
- `Docs/VAO_GOVERNANCE.md` - change control, compatibility, and publication policy.
- `Docs/VAO_RELEASE_CHECKLIST.md` - repeatable release procedure and external approvals.
- `Docs/VAO_CHANGELOG.md` - released contract history.

The normative files are versioned together. A release is incomplete if the
specification, schema/context/vocabulary, VAOM constants, OrgRec constants,
fixtures, changelog, or release manifest disagree about the compatibility line.

## 13. Scientific and technical references

These references motivate interoperable evidence and parameters; they do not
make one detection algorithm normative. A conforming package records the actual
method, version, parameters, source clock, uncertainty, and review decision.

- Audio Engineering Society. [AES69-2022, *AES standard for file exchange —
  Spatial acoustic data file format*](https://connect.aes.org/?attachment=4954&document_file=3791&document_type=document&download_document_file=1)
  (SOFA 2.1). A revision was at call-for-comment stage in 2026; VAO 0.2
  normatively names the published 2022 edition and records the exact convention.
- ITU-R. [BS.2076-3 (2025), *Audio definition model*](https://www.itu.int/rec/R-REC-BS.2076/)
  and [BS.2088-2 (2025), *Long-form file format for audio programme materials
  with metadata*](https://www.itu.int/rec/R-REC-BS.2088/).
- ISO/IEC. [23090-4:2025, *MPEG-I immersive audio*](https://www.iso.org/standard/84711.html),
  [23090-14:2025, *Scene description*](https://www.mpeg.org/standards/MPEG-I/14/),
  and [23008-3:2026, *MPEG-H 3D Audio*](https://www.iso.org/standard/90199.html).
  Work-in-progress amendments are informative only until published.
- ISO. [3382-1:2009, performance-space room-acoustic parameters](https://www.iso.org/standard/40979.html),
  [3382-2:2008, reverberation time in ordinary rooms](https://www.iso.org/standard/36201.html),
  [16283-1:2014, field sound insulation](https://www.iso.org/standard/55997.html),
  [12354-1:2017, building-acoustic estimation](https://www.iso.org/standard/70242.html),
  and [354:2003, sound absorption](https://www.iso.org/standard/34545.html).
- buildingSMART International. [IFC 4.3.2 documentation](https://standards.buildingsmart.org/IFC/RELEASE/IFC4_3/HTML/)
  and OGC. [CityGML 3.0](https://www.ogc.org/standard/citygml/).
- Khronos Group. [glTF 2.0 specification](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html)
  and [OpenXR 1.1 specification](https://registry.khronos.org/OpenXR/specs/1.1/html/xrspec.html).
- Alliance for OpenUSD. [OpenUSD `UsdMediaSpatialAudio`](https://openusd.org/release/user_guides/schemas/usdMedia/SpatialAudio.html).
  Its transformable prim and stage timecodes motivate explicit USD prim-path,
  pose, timebase, and media-binding preservation while VAO carries the deeper
  acoustic and evidence contracts.
- Wang et al. (2024). [“Hearing Anything Anywhere”](https://openaccess.thecvf.com/content/CVPR2024/html/Wang_Hearing_Anything_Anywhere_CVPR_2024_paper.html).
  Differentiable response rendering from sparse RIRs and geometry motivates
  explicit learned/simulated status and model/input lineage.
- Chen et al. (2024). [“Real Acoustic Fields”](https://openaccess.thecvf.com/content/CVPR2024/html/Chen_Real_Acoustic_Fields_An_Audio-Visual_Room_Acoustics_Dataset_and_Benchmark_CVPR_2024_paper.html).
  Dense RIRs, multimodal room capture, and precise 6DoF emitter/listener poses
  motivate response-field, pose, state, and validation-domain records.
- Liu et al. (2025). [“Hearing Anywhere in Any Environment”](https://openaccess.thecvf.com/content/CVPR2025/html/Liu_Hearing_Anywhere_in_Any_Environment_CVPR_2025_paper.html).
  Cross-room RIR prediction motivates the distinction between within-room
  validation and generalization claims.
- Jin and Gao (2025). [“Differentiable Room Acoustic Rendering with Multi-View
  Vision Priors”](https://openaccess.thecvf.com/content/ICCV2025/html/Jin_Differentiable_Room_Acoustic_Rendering_with_Multi-View_Vision_Priors_ICCV_2025_paper.html).
  Audio-visual differentiable beam tracing motivates hybrid rendering and
  material-inference lineage: visually inferred reflection properties remain
  inferred model parameters, not measured material coefficients.

- Bello, J. P., Daudet, L., Abdallah, S., Duxbury, C., Davies, M., & Sandler,
  M. B. (2005). “A tutorial on onset detection in music signals.” *IEEE
  Transactions on Speech and Audio Processing, 13*(5), 1035–1047.
  [doi:10.1109/TSA.2005.851998](https://doi.org/10.1109/TSA.2005.851998).
- Verge, M.-P., Hirschberg, A., & Caussé, R. (1994). “Jet formation and jet
  velocity fluctuations in a flue organ pipe.” *Journal of the Acoustical
  Society of America, 95*(2), 1119–1132.
  [doi:10.1121/1.408460](https://doi.org/10.1121/1.408460).
- Hruška, V., & Dlask, P. (2020). “On a robust descriptor of the flue organ
  pipe transient.” *Archives of Acoustics, 45*(3), 377–384.
  [doi:10.24425/aoa.2020.134054](https://doi.org/10.24425/aoa.2020.134054).
- de Cheveigné, A., & Kawahara, H. (2002). “YIN, a fundamental frequency
  estimator for speech and music.” *Journal of the Acoustical Society of
  America, 111*(4), 1917–1930.
  [doi:10.1121/1.1458024](https://doi.org/10.1121/1.1458024).
- Mauch, M., & Dixon, S. (2014). “pYIN: A fundamental frequency estimator
  using probabilistic threshold distributions.” *ICASSP 2014*, 659–663.
  [doi:10.1109/ICASSP.2014.6853678](https://doi.org/10.1109/ICASSP.2014.6853678).
- W3C. (2013). [PROV-O: The PROV Ontology](https://www.w3.org/TR/prov-o/).
- The MIDI Association. [MIDI Tuning Updated
  Specification](https://midi.org/midi-tuning-updated-specification).
- QUDT. [`unit:OCT`, octave](https://qudt.org/vocab/unit/OCT.html). VAO defines
  its own musical-cent IRI because QUDT does not provide the former `Centi`
  identifier as a cent unit.
