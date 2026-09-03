# GrandOrgue sample-set import

OrgRec can inspect a GrandOrgue organ definition file (`.organ`), preserve its
complete self-contained source tree, reconstruct the selected disposition, and
export the result as an OrgRec-profile Virtual Acoustic Object (`.vao`).

This document specifies the GrandOrgue adapter. Read it together with:

- [`EXISTING_AUDIO_DATASET_TO_VAO.md`](EXISTING_AUDIO_DATASET_TO_VAO.md), the
  format-independent conversion lifecycle and acceptance contract;
- [`BUREA_GRANDORGUE_VAO_CASE_STUDY.md`](BUREA_GRANDORGUE_VAO_CASE_STUDY.md),
  the fully executed and reproducible Bureå use case; and
- [`../Schemas/grandorgue-import-manifest.schema.json`](../Schemas/grandorgue-import-manifest.schema.json),
  the machine-readable contract for the frozen import evidence.

## Why the ODF is selected explicitly

A sample-set directory may contain original, extended, dry, wet, or surround
definitions. OrgRec therefore asks for the exact ODF instead of silently choosing
the first file in a directory. The selected ODF controls the modeled organ
disposition. Every non-hidden regular file under the ODF directory is still
preserved as source material so the original GrandOrgue set remains usable.

The importer currently supports the GrandOrgue/Hauptwerk-style INI ODF surface
needed by conventional pipe sample sets:

- UTF-8, Windows-1252, ISO-8859-1, and Mac OS Roman source text;
- Windows and POSIX relative sample paths, with traversal and absolute paths
  rejected;
- manual and pedal compasses;
- stop sections referenced from manual stop slots;
- contiguous bass/discant stop sections with the same name;
- direct `PipeNNN` paths and recursive `REF:<manual>:<slot>:<pipe>` references;
- WAVE header inspection without decoding or transcoding the masters;
- ODF organ identity, builder, build date, recording detail, source URL, and
  recognized Creative Commons BY-SA license URIs.

An import is blocked if any logical pipe in the selected ODF has an unsafe,
missing, cyclic, or unreadable audio reference. A source tree containing
symbolic links requires explicit review: VAO payload assets must be independent
regular files, so the converter must resolve each required link to a copied,
checksum-verified regular file or reject the conversion.

## OrgRec and VAO mapping

- The root organ receives a stable source-bound identifier based on the ODF's
  SHA-256: `SOURCE:grandorgue:<digest>`. It is deliberately not asserted as a
  MODAVIS ID.
- A publisher/source page, when supplied, is the resolvable target for that
  source-bound identifier and is attached to the root VAO organ entity.
- Manual and pedal sections become division components.
- Contiguous ODF stop sections become one stop component and one isolated-stop
  registration.
- Every logical pipe mapping becomes a source-bound pipe-position component,
  roadmap item, and imported take. Several logical pipes may link to the same
  physical audio asset when the ODF uses `REF:`.
- Stops, couplers, and tremulants become explicit GrandOrgue control interactions;
  stop/coupler controls activate their components and tremulants modulate theirs,
  allowing the exported object to claim the VAO playable profile.
- The complete ODF directory is copied to
  `Audio/Originals/GrandOrgue/<source-directory>/` to preserve relative paths.
  VAO classifies only lossless audio extensions there as audio masters; ODFs,
  images, HTML, README, and license files are source evidence.
- `Manifests/grandorgue-source.json` records the parsed mapping, source inventory,
  SHA-256 for every file, detected encoding, rights, warnings, and import policy.
- The ODF mapping is explicit evidence. A4=440 Hz and 12-TET expected frequencies
  remain analysis priors until tuning and temperament are documented or inferred.

The import event is not misrepresented as the historical recording event.
Acquisition setup and environmental facts absent from the ODF remain unknown and
produce review warnings rather than invented values.

## UI workflow

Open **Convert to VAO** and choose the distinct **GrandOrgue → VAO** converter.
Its six steps select the exact `.organ` file, inventory the complete tree,
review decoded identity and rights, review the ODF-derived disposition, confirm
preservation behavior, and choose a VAO destination. No filename convention or
audio-dataset mapping is applied to GrandOrgue material.

Conversion creates and validates the VAO directly while retaining an editable
project in the library. The library groups repeated conversions by their stable
ODF source identity.

## CLI workflow

```sh
swift run OrgRecDatasetTool grandorgue-inspect \
  /path/to/set/definition.organ inspection.json \
  --source-url https://publisher.example/organ

swift run OrgRecDatasetTool grandorgue-import \
  /path/to/set/definition.organ Organ.orgrec \
  --source-url https://publisher.example/organ

swift run OrgRecDatasetTool grandorgue-vao \
  /path/to/set/definition.organ Organ.vao \
  --project Organ.orgrec \
  --source-url https://publisher.example/organ

swift run OrgRecDatasetTool audit Organ.orgrec audit.json
swift run OrgRecDatasetTool vao-import Organ.vao Restored.orgrec
```

`grandorgue-vao` can omit `--project`; in that form its temporary editable
project is removed after the validated VAO has been created.

## Bureå Funeral Chapel acceptance case

The end-to-end acceptance set is Lars Palo's GrandOrgue recording of the organ
built in 1990 by Johannes Menzel Orgelbyggeri AB for Bureå Funeral Chapel,
Sweden. The publisher identifies it as a 6/I/P organ and distributes the complete
sample set under Creative Commons Attribution-ShareAlike 2.5 (Swedish
jurisdiction).

Source pages:

- <https://familjenpalo.se/vpo/burea-funeral-chapel/>
- <https://familjenpalo.se/vpo/download/>
- <http://creativecommons.org/licenses/by-sa/2.5/se/>

The downloaded RAR matched the publisher's MD5
`1d1a44aae37911f1f81f781b64eb668e`. Using `burea_gravkapell.organ`, OrgRec
decoded Windows-1252, reconstructed 6 stops and 295 logical pipes, resolved 12
shared-reference pipes to 283 unique referenced WAV files, and preserved 476
source files totaling 216,141,759 bytes. The resulting VAO contains 478 indexed
assets: 357 lossless audio masters, 120 source-evidence assets, and one OrgRec
application-state asset. Six stop controls, one coupler, and one tremulant are
represented by eight playable interactions.

The OrgRec consistency audit performed 4,738 checks with zero blockers and one
warning: temperature and humidity are absent from the source recording metadata.
That warning is correct and intentionally retained. Swift and VAOM both validate
the VAO, and VAO import restores the original OrgRec payload byte-for-byte.

Exact identifiers, asset examples, checksums, graph counts, commands, validation
evidence, epistemic limits, and artifact locations are recorded in the
[Bureå case study](BUREA_GRANDORGUE_VAO_CASE_STUDY.md).

## Known boundaries

Advanced per-control MIDI assignments, enclosure curves, combination systems,
and display geometry remain in the preserved ODF rather than being normalized
into editable OrgRec fields. Packages using encrypted audio, external package
dependencies, executable plugins, non-WAVE pipe media, multi-release syntax, or
GrandOrgue package containers must be unpacked and reviewed before import. OrgRec
never executes source content merely by opening or converting it.
