# PositivXR legacy-audio import case study

This is the executable reference case for bringing an existing instrumental
audio dataset into OrgRec without claiming more MODAVIS certainty than its
source metadata supports. It covers the directory
`/path/to/PositivXR`, attributed by the project owner to the
Cuntz Positiv in Leipzig.

Use **Convert to VAO → Audio dataset** in OrgRec to inspect, map, analyze, and
package the collection. The fixed reference profile remains reproducible from
the command line with `OrgRecDatasetTool`.

## Result in one paragraph

PositivXR is structurally importable, but it was not already a MODAVIS- or
IAD-shaped dataset. It contains no discovery manifest and no authoritative
canonical MODAVIS binding. OrgRec therefore treats `4010243` as the existing
musiXplora/BACCAE source-record identifier, creates source-bound component
locators, preserves the exact observed 45-key set for each of five inferred
stops, freezes a checksum inventory, and marks every imported take **Needs
review**. A later owner-governed reconciliation may attach canonical MDVS IDs;
the importer does not mint them.

## Source inventory

Inspection on 2026-08-14 found:

| Property | Observed value |
| --- | --- |
| WAV files | 225 |
| Other entries | `.DS_Store` (ignored and recorded in the inspection) |
| Payload size | 3,683,539,636 bytes |
| Total audio duration | 2,398.131 s (39 min 58.131 s) |
| Per-file duration | 6.154–22.259 s; mean 10.658 s |
| Format | RIFF/WAVE, IEEE 32-bit float |
| Sample rate | 192,000 Hz |
| Channels | 2 |
| Filename grammar | `4010243_<stop>_<midi>[_variant].wav` |
| Stop tokens | `ged`, `princ2`, `princ4`, `qui223`, `reg8` |
| Files per stop | 45 |

Every stop has the identical key set:

```text
36, 38, 40, 41, 43, 45, 46, …, 84
```

The missing 37, 39, 42, and 44 below the chromatic run encode a short/broken
bass octave. This is meaningful organ topology, not an input error. Import must
not fill those four positions or replace the set with a simple `36...84`
compass.

The machine-readable inspection is
[`Artifacts/PositivXR/inspection.json`](../Artifacts/PositivXR/inspection.json).

## Identity and evidence boundary

The raw bridge tables in the local MODAVIS source workspaces associate source
record `4010243` with a musical-instrument record, the Leipzig university
instrument museum, five registers, one manual, and 45 keys. That explains the
filename prefix and observed shape. It does **not** establish that `4010243` is
a canonical MODAVIS identifier.

The import uses these identities:

| Layer | Imported value | Meaning |
| --- | --- | --- |
| OrgRec organ key | `SOURCE:musixplora:4010243` | Explicit non-canonical source identity |
| Source record locator | `sr:musixplora:mxp_id:4010243` | Source-system record binding |
| `canonicalMDVSID` | `null` | Awaiting authoritative reconciliation |
| Frozen endpoint | `legacy-audio://musixplora/4010243` | Import-manifest snapshot, not a live Navigator claim |
| Locator trust | `sourceBound` | Recoverable to filename and source record |

An available shared-aggregator SQLite file is a development fixture and contains
conflicting synthetic attributes for this identifier. It is intentionally not
used as curatorial truth. External descriptions also vary in date, maker
attribution, and which related Cuntz instrument they describe. OrgRec retains
source assertions and uncertainty instead of silently merging them.

## Filename interpretation profile

The following mappings are reviewable import rules, not canonical MODAVIS
assertions:

| Token | Qualified display label | Sounding-pitch prior |
| --- | --- | --- |
| `ged` | Gedackt 8′ | key pitch |
| `princ2` | Principal 2′ | key pitch + 24 semitones |
| `princ4` | Principal 4′ | key pitch + 12 semitones |
| `qui223` | Quint 2 2/3′ | key pitch + 19 semitones |
| `reg8` | Regal 8′ | key pitch |

The 440 Hz, twelve-tone equal-temperament frequencies generated from those
offsets are analysis priors only. They are not evidence that the historic
instrument was tuned to A4=440 or in equal temperament. Measured frequencies
remain observations with algorithm provenance and confidence.

## Project model created by the importer

The import creates one `.orgrec` package with:

- one legacy-import activity/session, clearly distinguished from the unknown
  historical recording session;
- five source-bound stop components and five inferred isolated-stop
  registration states;
- 225 source-bound pipe-position components, roadmap items, and takes;
- original filenames under `Audio/Originals`;
- SHA-256, byte size, sample rate, channel count, frame count, duration source,
  MIDI key, stop token, and optional filename variant for every file;
- a frozen `Manifests/legacy-source-dataset.json` whose exact bytes are the
  snapshot payload;
- **Needs review** state and an explicit review reason on every take;
- no fabricated microphone setup, recording device, BWF metadata, date,
  operator, channel role, environmental reading, rights statement, reference
  pitch, or temperament.

Source audio is read only. Each source file is hashed, copied, hashed again, and
accepted only if the checksums agree. A failed import removes its partial
destination.

The frozen source inventory is described by
[`Schemas/legacy-audio-import-manifest.schema.json`](../Schemas/legacy-audio-import-manifest.schema.json).

## Analysis test

The default case-study analysis selects the low, median, and high observed key
from every stop: 15 recordings total. It runs the same OrgRec pipeline used for
new recordings:

1. reference-channel reading and waveform reduction;
2. adaptive onset and sound-offset detection;
3. bundled CREPE pitch estimation when available, otherwise the documented
   autocorrelation fallback;
4. peak/RMS and clipped-sample checks;
5. parameterized STFT spectrogram generation;
6. up to 16 partial tracks for this batch profile;
7. expected-frequency and cents-deviation comparison using the explicitly
   assumed pitch prior.

The report is stored inside the imported project at
`Analysis/legacy-analysis-report.json`. Results always retain the flag
`Legacy import: recording context requires review`, so a clean signal never
turns incomplete provenance into automatic acceptance. The concrete results of
the checked run are summarized in
[`Artifacts/PositivXR/ANALYSIS_RESULTS.md`](../Artifacts/PositivXR/ANALYSIS_RESULTS.md).

## Import workflow in the app

1. Open **Convert to VAO** in the sidebar and choose **Audio dataset → VAO**.
2. Choose the PositivXR directory.
3. Select **Record ID, stop, then MIDI note** and parse the filenames.
4. Review all five stop tokens, labels, footages, observed key sets, and ignored
   files. Apply the case-study interpretations rather than accepting an
   abbreviation as a canonical stop name.
5. Describe the source identity and rights; leave unknown facts unknown.
6. Leave representative low, middle, and high analysis enabled for the
   reference test, choose a destination, and create the checked VAO.
7. Resolve rights, provenance, stop-name, tuning, and channel-role findings in
   Field QA. Export an IAD / Navigator projection only when a MODAVIS admission
   workflow requires it.

## Reproduce from the command line

Inspect without copying audio:

```sh
swift run OrgRecDatasetTool inspect \
  /path/to/PositivXR \
  Artifacts/PositivXR/inspection.json
```

Create and analyze an OrgRec project:

```sh
swift run OrgRecDatasetTool import \
  /path/to/PositivXR \
  "$HOME/Library/Application Support/OrgRec/Projects/Cuntz-Positiv-PositivXR.orgrec" \
  --analyze
```

Re-run only the representative analysis:

```sh
swift run OrgRecDatasetTool analyze \
  "$HOME/Library/Application Support/OrgRec/Projects/Cuntz-Positiv-PositivXR.orgrec"
```

## VAO exchange and MODAVIS admission

The editable project is an OrgRec working package. Its primary checked export is
one `.vao` file. `vao-manifest.json` indexes the complete payload and relates the
instrument, components, configurations, sessions, takes, files, annotations,
observations, and processing activities. The VAO validator checks container
safety, hashes, byte sizes, bindings, and cross-record references before export.

The current OrgRec legacy import covers the 225 WAV masters. The accompanying
Unity source also contains models, textures, animations, presentation audio,
and activation logic; these are mapped in `POSITIVXR_VAO_MIGRATION.md` and must
be included for a complete PositivXR multimedia VAO rather than silently
discarded.

The IAD / Navigator package remains an optional normalized projection for
MODAVIS admission. `iad-manifest.json` indexes sessions, takes, files, channels,
segments, devices, registrations, observations, and paradata for that boundary.

Those projection records remain `candidate-proposals`. Import into MODAVIS must
be an owner-governed admission transaction that resolves canonical organ and
component identities, controlled vocabularies, rights, and storage policy. A
validated IAD is intentionally not permission to write directly into canonical
MODAVIS tables.

## Acceptance checklist for another legacy dataset

- A filename/parser profile produces exactly one unambiguous record per audio
  file.
- Source-system identifiers are namespaced and are never mislabeled as MDVS
  identifiers.
- Missing notes and irregular compasses are preserved exactly.
- Semantic expansions are qualified and reviewable.
- Unknown acquisition and rights metadata stays unknown.
- Originals are checksum-verified after copying.
- Every take has a stable component locator and frozen manifest binding.
- Representative analysis succeeds and remains human-reviewable.
- The resulting project round-trips through checked VAO export and import.
- Any source 3D, animation, texture, interaction, or contextual asset is indexed
  and related, or its intentional exclusion is recorded as migration paradata.
