# Bureå Funeral Chapel GrandOrgue-to-VAO case study

Status: historical executed private VAO 0.1 acceptance case, 2026-08-14. Its
identifiers and profile IRIs are preserved as an audit record and are not VAO
0.2 conformance evidence. Re-running the conversion for a 0.2 release requires
explicit migration and validation. This document is the worked source example
for [`EXISTING_AUDIO_DATASET_TO_VAO.md`](EXISTING_AUDIO_DATASET_TO_VAO.md).

## 1. Research and conversion question

Can a free GrandOrgue sample set for one identified physical organ be converted
into a VAO that:

- keeps the original GrandOrgue set usable;
- distinguishes its logical disposition from its physical audio storage;
- links the VAO root to the correct source-bound organ entity;
- carries machine-readable rights and provenance;
- exposes the selected disposition as playable interactions;
- passes independent VAO validation;
- and restores an editable OrgRec project without changing any source byte?

The Bureå Funeral Chapel set was selected because it is small enough for a
repeatable acceptance test, represents a specific documented organ, contains
both original and extended definitions, uses legacy ODF syntax and shared
references, includes contextual images and a license, and permits
redistribution under CC BY-SA 2.5.

## 2. Represented organ and source authority

The publisher states that the organ was built in 1990 by Johannes Menzel
Orgelbyggeri AB for the funeral chapel in Bureå, Sweden. The original
disposition is 6/I/P. Lars Palo recorded the samples in 2009 and created the
GrandOrgue set.

Authoritative source pages used by the conversion:

- organ description: <https://familjenpalo.se/vpo/burea-funeral-chapel/>;
- download catalogue: <https://familjenpalo.se/vpo/download/>;
- embedded/publisher license: <http://creativecommons.org/licenses/by-sa/2.5/se/>.

The publisher catalogue advertises MD5
`1d1a44aae37911f1f81f781b64eb668e` for
`Burea_Funeral_Chapel.rar`. The downloaded archive matched that value.

## 3. Scope decision: original versus extended organ

The extracted directory contains two definitions:

- `burea_gravkapell.organ` — original organ;
- `burea_gravkapell_ext.organ` — extended virtual disposition.

The conversion explicitly selected `burea_gravkapell.organ`. That choice makes
the root graph a representation of the documented original disposition rather
than silently asserting that virtual extensions belong to the physical organ.

The entire source directory was nevertheless preserved. Extended-only samples,
the second ODF, console graphics, HTML, photographs, README, and license remain
available as evidence and make the embedded GrandOrgue tree self-contained.

## 4. Acquisition and source inventory

| Measure | Result |
| --- | ---: |
| RAR advertised and observed MD5 | `1d1a44aae37911f1f81f781b64eb668e` |
| Selected ODF SHA-256 | `9b0d4f3e68dbf51f2daf4858f8931072e24fbbbf1a45f1ae6643537eff334455` |
| Detected ODF encoding | Windows-1252 |
| Complete extracted payload | 476 files |
| Complete extracted bytes | 216,141,759 |
| WAV files preserved | 357 |
| Source-evidence files in final VAO | 120 |
| Selected-definition logical mappings | 295 |
| Unique WAVs referenced by selected definition | 283 |

The distinction between 357 preserved WAVs and 283 referenced WAVs is
intentional. The source tree includes samples used by the extended ODF and
longer ranges than the original disposition. Dropping them would make the
preserved source incomplete; modeling them as pipes in the original instrument
would make the selected disposition false.

## 5. Inspection findings

### 5.1 Legacy text encoding

The ODF is Windows-1252, not UTF-8. Correct decoding recovers `Bureå` and
`Rörflöjt`; a UTF-8-only importer would either fail or corrupt identity and stop
labels. OrgRec records the detected encoding on the inspection and ODF asset and
preserves the original bytes unchanged.

### 5.2 Windows-style relative paths

Pipe values use forms such as:

```ini
Pipe001=.\Gedackt8\036-C.wav
```

OrgRec normalizes this syntax only for safe internal lookup. The raw ODF value,
ODF section, pipe field, resolved source-relative path, and ODF file are all
retained. No source path is rewritten.

### 5.3 Split stop sections

Several one-stop controls are implemented as contiguous bass and discant ODF
sections. For example `Stop103` and `Stop104` both describe Gedackt 8′ and cover
adjacent key ranges. OrgRec merges them into one stop component because the
division and name match and the ranges are contiguous. Their original section
names remain attached to the component.

This yielded the physical disposition:

| Division | Stop | ODF sections | Key MIDI | Logical pipes |
| --- | --- | --- | ---: | ---: |
| PEDAL | Subbas 16′ | `Stop001` | 36–62 | 27 |
| Manual | Gedackt 8′ | `Stop103`, `Stop104` | 36–91 | 56 |
| Manual | Principal 2′ | `Stop109`, `Stop110` | 36–91 | 56 |
| Manual | Rörflöjt 4′ | `Stop107`, `Stop108` | 36–91 | 56 |
| Manual | Salicional 8′ | `Stop101`, `Stop102` | 36–91 | 56 |
| Manual | Voix Celeste 8′ | `Stop105`, `Stop106` | 48–91 | 44 |

Total: 6 stops and 295 logical pipe positions.

### 5.4 Shared `REF:` samples

The lowest twelve Salicional mappings are not separate WAV files. The ODF uses
values such as:

```ini
Pipe001=REF:001:003:001
```

The reference identifies another stop slot and pipe in the same ODF. OrgRec
resolves references recursively, rejects cycles, and records both the raw
reference and final sample path.

Consequently, 295 logical pipe positions refer to 283 unique physical WAVs.
The final VAO stores a shared WAV once and links it to each applicable take and
component. This is a faithful many-to-one mapping rather than a data anomaly.

### 5.5 Controls

The original ODF contains six stop controls, one manual-to-pedal coupler, and one
tremulant. The final VAO has eight `interaction` entities:

- stop and coupler interactions `vao:activates` their components;
- the tremulant interaction `vao:modulates` its component.

These interactions meet the VAO 0.1 playable-profile machine-verifiable
minimum. Advanced controller bindings and display geometry remain in the
preserved ODF.

## 6. Identity model

The conversion uses four related but non-interchangeable identifiers.

| Layer | Value | Meaning |
| --- | --- | --- |
| source ODF | `9b0d4f…34455` | SHA-256 of the selected definition |
| external organ identity | `SOURCE:grandorgue:9b0d4f…34455` | stable source-bound grouping/reconciliation key |
| root VAO entity | `urn:uuid:aefb0ea0-f5c9-4358-a282-eff3d27982af` | instrument node tied to the editable project |
| VAO exchange revision | `urn:uuid:9dc051a5-0610-490c-a62b-9b1569540baf` | this finished immutable package |

The external identifier uses:

```json
{
  "value": "SOURCE:grandorgue:9b0d4f3e68dbf51f2daf4858f8931072e24fbbbf1a45f1ae6643537eff334455",
  "scheme": "https://w3id.org/modavis/vao/vocab/identifier-scheme/source-bound",
  "resolvesTo": "https://familjenpalo.se/vpo/burea-funeral-chapel/"
}
```

No canonical MDVS identity was asserted. This avoids turning an ODF checksum or
publisher slug into authority data while still ensuring that OrgRec groups and
round-trips the correct organ.

## 7. Rights model

The source ODF, README, publisher page, and embedded license agree on CC BY-SA
2.5. The complete `LICENSE.txt` is preserved. The VAO rights record is:

```json
{
  "license": "http://creativecommons.org/licenses/by-sa/2.5/se/",
  "creditLine": "Source sample set and recordings: Lars Palo",
  "statement": {
    "und": "Creative Commons Attribution-ShareAlike 2.5 · http://creativecommons.org/licenses/by-sa/2.5/se/"
  },
  "accessCondition": "See statement and per-source rights; no absent permission is inferred."
}
```

The `rightsHolderId` resolves to the Lars Palo agent entity. The license makes
this particular end-to-end distributable case possible; the converter does not
generalize that permission to other sample sets.

## 8. OrgRec project model

The importer created:

- one source-bound root organ;
- two division components (PEDAL and Manual);
- six stop components;
- one coupler and one tremulant component;
- 295 pipe-position components;
- six isolated-stop configurations;
- 295 roadmap items and imported takes;
- one import activity/session, distinct from the historical 2009 recording;
- one complete GrandOrgue preservation tree;
- one frozen `Manifests/grandorgue-source.json`.

Every take is `needsReview`. It has source-bound provenance, audio metadata,
SHA-256, ODF selector, raw ODF value, resolved path, component, configuration,
and import activity. Unknown microphone placement, device, channel semantics,
temperature, humidity, clock, tuning reference, and temperament were not
invented.

The reference pitch of 440 Hz and 12-TET frequency calculations are explicitly
analysis priors. Stop footage adjusts expected sounding frequency but is not a
historical tuning assertion.

## 9. Frozen import evidence

The project contains:

`Manifests/grandorgue-source.json`

Its SHA-256 is:

`421e1421d309d920e04f0f6468cdee7d6ffd330bae01454e2cd6fad0e7e8be5f`

The VAO indexes this as UTF-8 `application/json`, role `source-evidence`, and
representation status `authored`. The root organ's snapshot-hash property points
to the same digest, binding every component locator and take provenance record
to one frozen interpretation.

The manifest contains the original absolute import path. That is useful for a
local audit but can disclose workstation information. This artifact is a local
acceptance object; a public repository release should use a documented redacted
derivative if path privacy is required.

## 10. VAO projection

The finished VAO claims four cumulative profiles:

- `https://w3id.org/modavis/vao/profile/core/0.1`;
- `https://w3id.org/modavis/vao/profile/research/0.1`;
- `https://w3id.org/modavis/vao/profile/orgrec-capture/0.1`;
- `https://w3id.org/modavis/vao/profile/playable/0.1`.

Final graph and payload measures:

| Measure | Value |
| --- | ---: |
| Entities | 922 |
| Relations | 4,347 |
| Interaction entities | 8 |
| Assets | 478 |
| Audio-master assets | 357 |
| Source-evidence assets | 120 |
| Application-state assets | 1 |
| Verified payload bytes | 219,748,534 |

Example ODF asset:

| Field | Value |
| --- | --- |
| path | `payload/orgrec/Audio/Originals/GrandOrgue/Burea_Funeral_Chapel/burea_gravkapell.organ` |
| media type | `text/plain` |
| encoding | `Windows-1252` |
| role | `source-evidence` |
| representation status | `authored` |
| SHA-256 | `9b0d4f3e68dbf51f2daf4858f8931072e24fbbbf1a45f1ae6643537eff334455` |

Example referenced WAV asset:

| Field | Value |
| --- | --- |
| path | `payload/orgrec/Audio/Originals/GrandOrgue/Burea_Funeral_Chapel/Gedackt8/036-C.wav` |
| media type | `audio/wav` |
| role | `audio-master` |
| representation status | `captured` |
| SHA-256 | `b284cbee233dd365ea81db0ab758795c7e5faa9b5403bfd84a4f304ac1e0cbeb` |

The WAV asset's `aboutEntityIds` includes the organ, import session, relevant
takes, and both applicable logical components when audio is shared.

## 11. UX/UI findings exercised by the case

The Bureå set directly motivated and verified the current GrandOrgue import
screen:

| Source risk or ambiguity | Implemented UI response |
| --- | --- |
| original and extended ODF coexist | file picker requires the exact `.organ`; helper text explains why |
| legacy identity can be confused with MODAVIS identity | publisher URL field explicitly creates only a resolvable source-bound identity |
| 295 logical pipes share 283 referenced WAVs | inventory shows both figures side by side |
| unselected ODF assets still matter | complete payload file count and size are shown separately from referenced audio |
| rights are easy to miss | organ identity, holder, license label, and license URI have a dedicated review panel |
| split stops hide the modeled compass | disposition table shows division, merged stop, contributing ODF sections, compass, and pipe count |
| missing/cyclic audio would produce a broken organ | import button reports resolution state and is disabled for unresolved mappings |
| preservation behavior is otherwise invisible | preflight states full-tree copying, per-file SHA-256, role classification, and no text transcoding |

This is an important UX property: the screen does not ask the operator to trust
an opaque “Convert” action. It makes the semantic scope and preservation cost
reviewable before the destination exists.

Two boundaries remain deliberately visible rather than hidden. Advanced
GrandOrgue execution details remain in the preserved ODF, and historical
recording/environment data absent from the source remains a post-import review
warning. For public dissemination, absolute import-path privacy also requires a
future explicit redacted-derivative workflow; silently editing the evidence
manifest would invalidate its checksum.

## 12. Reproduction commands

```sh
swift run OrgRecDatasetTool grandorgue-inspect \
  Artifacts/GrandOrgue/Source/Extracted/Burea_Funeral_Chapel/burea_gravkapell.organ \
  Artifacts/GrandOrgue/burea-inspection.json \
  --source-url https://familjenpalo.se/vpo/burea-funeral-chapel/

swift run OrgRecDatasetTool grandorgue-vao \
  Artifacts/GrandOrgue/Source/Extracted/Burea_Funeral_Chapel/burea_gravkapell.organ \
  Artifacts/GrandOrgue/Burea-Funeral-Chapel.vao \
  --project Artifacts/GrandOrgue/Burea-Funeral-Chapel.orgrec \
  --source-url https://familjenpalo.se/vpo/burea-funeral-chapel/

swift run OrgRecDatasetTool audit \
  Artifacts/GrandOrgue/Burea-Funeral-Chapel.orgrec \
  Artifacts/GrandOrgue/burea-orgrec-audit.json

python3 Tools/vaom.py validate \
  Artifacts/GrandOrgue/Burea-Funeral-Chapel.vao \
  --json
```

The checked final VAO is:

- file: `Artifacts/GrandOrgue/Burea-Funeral-Chapel.vao`;
- VAO ID: `urn:uuid:9dc051a5-0610-490c-a62b-9b1569540baf`;
- SHA-256:
  `676a563bfcaa39e1c25b64f578627ceaa86e33f7d59e8129544237bde090f61b`.

## 13. Validation evidence

### OrgRec project consistency

- checks performed: 4,738;
- score: 96/100;
- blockers: 0;
- warnings: 1;
- information notices: 0.

The one warning is incomplete temperature/humidity paradata for the source
recording. This is an accurate documentary limitation and was deliberately not
suppressed or replaced with guessed values.

### VAO validators

- native OrgRec VAO validation: valid, no warnings;
- independent VAOM validation: valid, no warnings;
- verified assets: 478;
- verified bytes: 219,748,534.

### Round-trip

The finalized VAO was imported to a new `.orgrec` destination. A sorted
file-by-file SHA-256 comparison between the source and restored projects showed
no differences after excluding the newly generated `Manifests/ImportedVAO/`
audit receipt. The restored project retained 295 takes and the same project/root
instrument identity.

## 14. What the case demonstrates

This use case establishes that the conversion design can handle:

- a real, identified physical organ;
- a redistributable source license;
- legacy non-UTF-8 source metadata;
- source-native Windows paths;
- multiple co-located virtual dispositions;
- contiguous split stop definitions;
- many-to-one logical-to-physical sample relationships;
- preservation of selected and unselected source assets;
- source-bound identity without false MODAVIS claims;
- machine-readable rights and attribution;
- playable control interactions;
- explicit unknown acquisition and tuning context;
- independent VAO validation;
- lossless editable-project re-import.

It also shows the boundary of conformance: the VAO is technically valid and
preservationally complete for the selected conversion, but validation does not
turn missing environmental measurements into known facts or make the virtual
extension part of the historical organ.

## 15. Artifacts

- [`Artifacts/GrandOrgue/README.md`](../Artifacts/GrandOrgue/README.md)
- [`Artifacts/GrandOrgue/CONVERSION_REPORT.md`](../Artifacts/GrandOrgue/CONVERSION_REPORT.md)
- [`Artifacts/GrandOrgue/burea-inspection.json`](../Artifacts/GrandOrgue/burea-inspection.json)
- [`Artifacts/GrandOrgue/burea-orgrec-audit.json`](../Artifacts/GrandOrgue/burea-orgrec-audit.json)
- [`Artifacts/GrandOrgue/burea-vaom-validation.json`](../Artifacts/GrandOrgue/burea-vaom-validation.json)
- [`Artifacts/GrandOrgue/Burea-Funeral-Chapel.vao`](../Artifacts/GrandOrgue/Burea-Funeral-Chapel.vao)
