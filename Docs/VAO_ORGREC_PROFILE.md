# VAO 0.2 OrgRec Capture Profile

OrgRec uses `.vao` as its primary exchange format. `.orgrec` remains the editable on-disk project package used by the macOS application, and the existing `.orgrec-capture` Instrumental Audio Dataset projection remains available as a secondary Navigator/database handoff.

## Export mapping

An OrgRec VAO claims these profiles:

- `https://w3id.org/modavis/vao/profile/core/0.2`
- `https://w3id.org/modavis/vao/profile/research/0.2`
- `https://w3id.org/modavis/vao/profile/orgrec-capture/0.2`

It additionally claims `https://w3id.org/modavis/vao/profile/playable/0.2`
when the project contains a validated interaction graph, as in a GrandOrgue
conversion with stop, coupler, or tremulant controls, or when a take contains a
reviewed sample-clock sustain loop.

OrgRec 0.2.1 added capability declarations only when their public graph was
complete: `source-segmentation` for fixed long-take extraction regions,
`acoustical-analysis` for public analysis records, `tuning-map` for exact
per-key playback frequencies, `sampled-instrument-playback` for reviewed sample
mappings, `empirical-timbre-classification` when calibrated inference and its
indexed model are exported, and `pitch-dependent-rank-fingerprint` when the
typed trajectory and transition analysis are exported. OrgRec 0.2.2 additionally
declares `collection-acoustic-diagnostics` only when the evidence-qualified
ledger, parameters, robust aggregates, and review-candidate observations form a
complete public contract. A lossless private project payload never substitutes
for a capability's public contract.

The VAO `primaryEntityId` is the documented instrument and
`focusEntityIds` includes it. A project with a canonical MDVS identifier
preserves it as an external identifier and uses the frozen Navigator payload as
source evidence. A local identifier remains local and is never promoted to a
canonical MDVS identity.

| OrgRec record | VAO representation |
| --- | --- |
| project/instrument | primary `modinst:MusicalInstrument`; `modorgan:PipeOrgan` only for the current OrgRec organ workflow |
| `OrganComponent` | component entity with original locator, type, division, pitch and parent data |
| parent/component structure | qualified membership relation; convenience relation for discovery |
| registration | instrument configuration entity |
| recording session | domain recording activity plus processing provenance |
| take | recording/digital-object entity linked to component, session, setup, registration and audio asset |
| original WAV/BWF | `audio-master` asset linked to take, component and instrument |
| BWF sidecar | paradata/source-evidence asset linked to the audio master |
| waveform/spectrogram | analysis-result derivative asset with generating analysis/activity |
| pitch/partial/onset/decay result | analysis record with inputs, method/version, observations and quality flags |
| timed annotation/reviewer correction | annotation entity or evidence-bearing relation with time selector |
| microphone/device/environment | entities/properties frozen through session and take paradata |
| tuning calibration | measurement activity, calibration audio asset and observation |
| calibration/reference decision | `modaudio:TuningCalibration` entity plus measured frequency, accepted A4, device/environment/time evidence and paradata |
| temperament inference | analysis with cached MODAVIS/BDO source binding, observations, ranking and uncertainty |
| collection evidence, tuning, drift, anomalies and similarity | evidence-qualified collection analysis with a reconciled take ledger, explicit grouping, robust rank/session aggregates, null-aware drift, and review-only candidate arrays |
| Navigator JSON | source-snapshot asset with SHA-256 and exact release binding |
| source dataset descriptor/ODF | source-evidence asset retaining the original syntax and selectors |
| frozen adapter import manifest | source-evidence asset binding interpretation, inventory, fixity, rights and warnings |
| source-bound instrument identity | external identifier with source scheme and optional resolvable publisher URL; never promoted to an MDVS ID |
| playable source control | interaction entity linked to the affected component or modulation target |
| detected/reviewed loop set | `modaudio:LoopPointSet` with source fixity, score, status, envelope, and provenance |
| sustain loop region | `modaudio:SustainLoopRegion` with inclusive start, exclusive end, crossfade, mode, and release policy |
| sustained sampled note | interaction linked by `vao:usesSample`, `modaudio:usesLoopPointSet`, and `vao:activates` |
| raw long-take source | fixed source-evidence audio asset retained unchanged |
| detected note candidate | `modaudio:SampleExtractionRegion` with exact half-open source frames, sample rate/hash, channel, confidence and censoring |
| cut note/take | derived object linked to the long-take region by `modaudio:extractedFromRegion` and PROV derivation |
| accepted sampler mapping | `modaudio:SamplePlaybackParameters` linked by `modaudio:usesPlaybackParameters`; root/ranges, measured and target pitch, gain, channel, envelope and note-off are explicit |
| exact playable tuning | versioned `modaudio:TuningMap` with unique per-key frequencies and component references; distinct from measurements and inferred temperament |
| large pitch/partial/feature data | indexed `feature-track` or `analysis-result` asset linked by observation `valueAssetId`; manifest retains a compact summary |

### Collection diagnostics export

OrgRec claims
`https://w3id.org/modavis/vao/vocab/capability/collection-acoustic-diagnostics`
in the research profile only when `CollectionAnalysisReport` has an immutable
parameter set and fingerprint, evidence summary, and per-take evidence ledger.
The same profile also claims `acoustical-analysis`. Incomplete legacy collection
reports remain exportable as
`https://w3id.org/modavis/vao/vocab/analysis/collection-tuning` without the new
capability claim; changing the label alone is not an upgrade.

A complete report is projected as
`https://w3id.org/modavis/vao/vocab/analysis/evidence-qualified-collection-acoustic-diagnostics`.
Its inputs are exactly the assessed take entities and its subject is the primary
instrument. Declared parent components remain the rank subjects. When a source
has no parent component, OrgRec creates a stable analytical component-grouping
entity, records the source grouping identifier and `groupingBasis`, and links
that inferred grouping to the instrument. It does not promote a label-derived
group to documented physical identity.

The eight governed observations carry:

- evidence counts, coverage, exclusion reason counts, and one evidence entry
  per assessed take;
- key-ordered rank tuning curves in musical cents and robust rank stretch in
  cents per octave;
- session median offsets in cents and within-target drift in cents per hour,
  with insufficient repeated evidence encoded as null/indeterminate;
- multivariate anomaly review candidates with contributing feature scores; and
- harmonic-number-aligned similarity review candidates with canonical take
  pairs, shared-partial evidence, and explicit non-identity interpretation.

The generating activity records the exact gating thresholds, candidate cap,
software/method version, and lowercase SHA-256 parameter fingerprint. Empty
candidate arrays are retained as valid negative results. Full semantics and
presentation safeguards are documented in
[`COLLECTION_ACOUSTIC_DIAGNOSTICS.md`](COLLECTION_ACOUSTIC_DIAGNOSTICS.md).

For every exported long-take cut, OrgRec retains both coordinate systems:
seconds for navigation and source frames for sample-accurate derivation. The
source SHA-256 and sample rate bind the region to one immutable long-take
asset. Onset, stable sustain, key-up, acoustic offset, and tail remain separate
observations or regions; a file boundary is recorded as censored rather than
misreported as the physical tone boundary.

OrgRec exports algorithm output as `observed` or `inferred`. A user-approved
cut, loop, tuning, or playback mapping becomes a distinct `reviewed` or
`accepted` decision with provenance. Re-analysis may add evidence but does not
silently rewrite an accepted playable instrument.

Every file from the editable project, except transient exports and hidden operating-system files, is stored below `payload/orgrec/` and indexed. The original `project.json` is `payload/orgrec/project.json`. This private record guarantees lossless re-import; the public VAO entity/relation/asset/analysis/paradata graph guarantees that another implementation does not need to understand `OrgRecProject` merely to use the data.

## Import behavior

OrgRec performs these operations before it creates an editable project:

1. validate archive structure, mimetype, supported compression, paths, counts and limits;
2. decode and validate the VAO 0.2.x manifest;
3. verify primary and focus entities, uniqueness, local references, profiles, asset index, size and SHA-256;
4. require the OrgRec capture profile and the lossless project asset;
5. extract only indexed `payload/orgrec/` entries into a newly created `.orgrec` destination;
6. load and validate `project.json` through the normal project store;
7. delete an incomplete new destination on any failure;
8. retain the exact validated source VAO under a checksum-addressed
   `Manifests/ImportedVAO/` path and record its package identifier, revision,
   version, and SHA-256 in `project.json`.

On re-export, OrgRec validates that retained source again, creates a new
revision with the same VAO identifier, replaces the OrgRec-owned graph and
payload, and merges back profiles, entities, relations, rights, analyses,
paradata, URI-keyed properties/extensions, and non-OrgRec payload assets. It
refuses the export if the retained archive is missing or its recorded checksum
or identity changed, preventing a silently lossy XR round trip.

The general `VAOPackageReader` can validate, inspect, copy, extract an indexed
asset from, or import a complete verified authoring workspace from any valid
VAO 0.2.x package. Arbitrary non-organ VAOs are not converted into editable
OrgRec recording roadmaps. This is a product boundary, not a format limitation:
OrgRec is a pipe-organ capture application. Experiential capabilities remain
visible with a `metadataOnly` processing status because OrgRec does not provide
an XR runtime.

## Relationship to IAD and Navigator export

VAO is the user-facing exchange and preservation envelope. The IAD/Navigator package is a database projection with candidate-only MODAVIS admission semantics. Exporting one does not imply that the other has been accepted by Navigator. A VAO may embed the IAD projection as assets in a future profile, but OrgRec 1.0 keeps the workflows separate so a private database contract does not become the public object model.

## Backward compatibility

- Existing `.orgrec` projects continue to open unchanged.
- Existing `.orgrec-capture` directories continue to import and export.
- PositivXR filename-driven datasets continue through the legacy importer, then export as VAO with the importer assumptions, original identifiers, checksums, and analysis paradata made explicit.
- GrandOrgue datasets continue through the ODF adapter, which retains the
  complete source tree, ODF selectors, reference resolution, controls, rights,
  and a schema-valid frozen import manifest.
- A VAO revision never overwrites its source package or the only copy of an editable project.

## Existing-dataset conversion

The format-independent conversion procedure is documented in
[`EXISTING_AUDIO_DATASET_TO_VAO.md`](EXISTING_AUDIO_DATASET_TO_VAO.md). The
GrandOrgue-specific mapping is defined in
[`GRANDORGUE_IMPORT.md`](GRANDORGUE_IMPORT.md), and the Bureå acceptance run is
recorded in
[`BUREA_GRANDORGUE_VAO_CASE_STUDY.md`](BUREA_GRANDORGUE_VAO_CASE_STUDY.md).
Those documents are informative about VAO itself but authoritative for the
OrgRec import implementation and its preservation claims.
