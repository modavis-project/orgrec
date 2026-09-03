# Instrumental Audio Dataset package

OrgRec exports each recording campaign as a self-contained, versioned
Instrumental Audio Dataset (IAD). The package is designed for deterministic
discovery, preservation checking, transfer between OrgRec installations, and
owner-governed admission into MODAVIS.

The IAD is not a direct database dump and does not mint canonical MODAVIS
identifiers. Every projection record declares `candidate-proposals`. Navigator
or another authorized owner service must resolve referenced identities,
vocabularies, storage policy, and permissions before creating canonical rows.

## Package layout

```text
Dataset.orgrec-capture/
  iad-manifest.json
  capture-package.json
  project.json
  modavis-snapshot.json
  modavis-navigator-payload.json
  consistency-report.json
  manifests/
    sessions.jsonl
    takes.jsonl
    files.jsonl
    channels.jsonl
    segments.jsonl
    devices.jsonl
    registrations.jsonl
    observations.jsonl
    paradata.jsonl
    calibrations.jsonl
    temperament-analyses.jsonl
  audio/
    <take-uuid>.wav
    <take-uuid>.bwf.json
    calibration-<calibration-uuid>.wav
  analysis/
  annotations/
```

`iad-manifest.json` is the dataset discovery entry point. It identifies the
organ and project, pins the Navigator response and MODAVIS release, locates all
record indexes, declares their object counts, and inventories every payload
file with media type, role, byte size, and SHA-256.

`capture-package.json` remains the Navigator transport envelope. Contract 2.0
links `iad-manifest.json` by path and SHA-256, so the transport and dataset views
cannot silently diverge.

Each `sessions.jsonl` record also preserves the session-plan UUID/revision,
venue-condition summary, full structured surrounding-noise assessment, OSM
source attribution and query SHA-256, review dispositions, and noise incidents
observed during recording. `project.json` retains all plan revisions and the
venue anchor, while every take's provenance retains the assessment that was
current when recording began. Timed incident annotations remain in the normal
annotation payload as well as the session record.

## MODAVIS projection indexes

| IAD index | Candidate MODAVIS destination |
| --- | --- |
| `sessions.jsonl` | `prov.activity`, `audio.recording_session` |
| `takes.jsonl` | `audio.recording_take` |
| `files.jsonl` | `core.entity`, `media.asset`, `media.bitstream`, `media.storage_object`, `media.file` |
| `channels.jsonl` | `audio.channel` |
| `segments.jsonl` | `audio.segment` |
| `devices.jsonl` | `core.entity`, `core.manifestation`, `devices.*` |
| `registrations.jsonl` | governed registration-state proposal |
| `observations.jsonl` | `measurement.observation` |
| `paradata.jsonl` | `paradata.generic` |
| `calibrations.jsonl` | `prov.activity`, `measurement.observation`, `audio.recording_session` |
| `temperament-analyses.jsonl` | `measurement.observation`, `paradata.generic` candidate evidence |

The indexes use OrgRec UUIDs only as package-local foreign keys. Organ and
component references retain their frozen MODAVIS identifiers or source-bound
locators. The server resolves package-local references to admitted identifiers
inside one reviewed transaction.

For physical-pipe-aware roadmaps, each take record also carries its physical
sound-target identifier, all equivalent logical component locators, and the
source-backed or reviewed activation routes. The singular `componentLocator`
remains the route actually used for the take. This preserves stop/key lineage
without exporting duplicate audio or asserting that an unreviewed similarity is
a physical identity.

## Export validation

Export first runs the normal project consistency audit. It then constructs the
package and verifies it again as an IAD before returning it to the user. The IAD
validator checks:

- the exact contract and candidate-only projection mode;
- safe relative paths and unique manifest paths;
- byte size and SHA-256 for every indexed payload;
- JSONL decoding and declared object counts;
- unique session, file, and take identifiers;
- take-to-session/file/project references;
- channel and segment file references and segment bounds;
- observation and paradata take references;
- tuning-calibration session references and indexed calibration audio;
- temperament-analysis report identity, evidence sufficiency, and project binding;
- project, organ, Navigator snapshot, capture manifest, and IAD hash agreement.

A generated package that fails validation is removed and export fails closed.

## Import

Choose **Import project or IAD…** in the project library. For an IAD directory,
OrgRec validates the complete package before it creates a managed project. It
then restores each UUID-named transfer WAV to the original path in
`Audio/Originals`, restores BWF and analysis sidecars, restores the frozen
Navigator response, and records the import validation report under
`Manifests/iad-import-validation.json`.
Session calibration WAVs are restored to `Audio/Calibration`; accepted
calibrations fail import if their indexed audio is absent.

The source dataset is never modified. A failed or partial reconstruction is
removed from managed storage.

### Importing a directory that is not yet an IAD

Use the separate **Convert to VAO** workspace and choose **Audio dataset →
VAO**. A raw audio directory is not yet an IAD package: it has no IAD manifest
to validate. The guided converter therefore applies an explicit, reviewed
filename mapping, inventories and hashes the source, creates an editable
`.orgrec` project, and writes a checked VAO. An IAD / Navigator package remains
a separate optional projection for database admission.

The PositivXR reference implementation is documented in
[`POSITIVXR_CASE_STUDY.md`](POSITIVXR_CASE_STUDY.md). Its key rule is general:
a source-system record identifier remains source-bound unless an authoritative
MODAVIS reconciliation supplies a canonical MDVS ID.

## Schemas

- `Schemas/iad-manifest.schema.json`
- `Schemas/iad-projection-records.schema.json`
- `Schemas/capture-package.schema.json`

Runtime validation uses the corresponding strongly typed Swift contracts plus
cross-file and fixity rules that JSON Schema alone cannot express.
