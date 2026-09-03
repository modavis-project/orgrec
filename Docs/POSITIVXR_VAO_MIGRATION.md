# PositivXR to VAO migration specification

Status: source-audited migration plan  
Source: `VAOrgan` Unity 2022.2.10f1 project supplied on 2026-08-14  
Target: VAO 0.2 core, research, playable, spatial, and preservation profiles;
the acoustics profile is claimed only when its measured-response, scene, and
runtime-fallback requirements are actually satisfied

## Purpose and identity boundary

The Unity application is a valuable legacy implementation, but it is not yet a
VAO: relationships are distributed among filenames, Unity scene objects,
scripts, resources, and implicit conventions. Migration makes those
relationships explicit while preserving every source asset and every unknown.

`4010243` is retained as a source-system identifier associated with the supplied
Musixplora record. It is not promoted to a canonical MDVS identifier. The root
instrument receives a local UUID URN and is designated as the primary entity
until an owner-governed MODAVIS identity
resolution supplies a canonical identifier. Rights, acquisition details,
microphone geometry, dates, tuning, and authenticity claims remain unknown
unless separately evidenced; no license is inferred from file availability.

## Audited source behavior

`Assets/Scripts/KeyHandler.cs` defines five selectable register controls in this
order:

| Unity control | Filename token | Documented VAO label |
| --- | --- | --- |
| `bt.reg.1` | `ged` | Gedackt 8′ |
| `bt.reg.2` | `princ4` | Principal 4′ |
| `bt.reg.3` | `princ2` | Principal 2′ |
| `bt.reg.4` | `qui223` | Quint 2 2/3′ |
| `bt.reg.5` | `reg8` | Regal 8′ |

A key control named `bt.<MIDI>` plays one resource for every active register,
using `4010243_<token>_<MIDI>` and falling back to the `_0` filename variant.
Pointer-up starts a fade to zero and fades all active sources. The code does not
establish historical tuning, velocity layers, independent release samples, or
physically measured spatialization; those facts must not be inferred.

The non-AppleDouble source inventory contains 225 WAVE files: 45 per register.
All registers share the same observed irregular MIDI set from 36 through 84,
with 37, 39, 42, and 44 absent. The audio payload is approximately 3.68 GB. The
project also contains seven FBX files, six Unity animation files, five
presentation MP3 files, and instrument/application textures and materials.
Third-party packages and example assets are dependencies, not automatically
instrument evidence.

## Required VAO graph

The complete migration has these nodes and relations:

1. one source-bound musical-instrument root, typed both as generic MODAVIS
   `MusicalInstrument` and the pipe-organ specialization;
2. five stop components, each connected through a reified
   `ComponentMembership`, with source token and UI control stored separately;
3. 225 sounding-position components, one for each observed stop/MIDI pair;
4. 45 key interactions with explicit MIDI note, domain, press and release
   semantics, plus five independent selection interactions;
5. `activates`, `selectsConfiguration`, `usesSample`, `targetsAnimation`,
   `represents`, and `hasRepresentation` relations connecting controls, stops,
   sounding positions, audio, model regions, and animation assets;
6. model/spatial-region nodes for stable FBX objects or, preferably, their
   reviewed glTF derivatives, including units, handedness, up-axis, origin,
   scale, transformation, and original-to-derivative provenance;
7. source snapshot and source-fragment nodes for `KeyHandler.cs`, relevant Unity
   scenes/prefabs, and exact line or object selectors supporting every migrated
   activation assertion;
8. migration, hash, conversion, segmentation, and editorial-review activities,
   with software version, parameters, input/output links, warnings, and actor
   when known;
9. analysis records only for actually computed results. Raw samples, later
   OrgRec measurements, and presentation mixes remain distinct;
10. a package-level unknown-rights statement plus narrower rights records when
    evidence becomes available.

An audio asset is about the root instrument, its stop and sounding position. It
is the object of the corresponding `usesSample` relation and an output of the
migration/capture activity. A model asset is not merely “about the organ”: model
nodes or spatial-region selectors must identify which component it represents.
An animation identifies its target region and time/control mapping. Filenames
are retained as provenance but are never the sole relationship carrier.

## Payload policy

| Source material | VAO treatment |
| --- | --- |
| 225 WAV resources | Preserve byte-identically as audio masters; one asset and SHA-256 per file |
| FBX models and relevant textures/materials | Preserve originals; add reviewed glTF derivatives for interoperability when feasible |
| `.anim`, scenes, prefabs, controller data | Preserve as Unity source evidence; add an open glTF or timestamped-event derivative for the playable profile |
| `KeyHandler.cs` and first-party scripts | Preserve as source evidence; never execute merely by opening a VAO |
| Five MP3 presentation recordings | Keep as contextual/presentation audio, never mislabeled as isolated samples |
| Unity `.meta` files | Keep when required to retain GUID/object binding, with an explicit Unity-metadata role |
| `._*`, caches, build products | Exclude as packaging noise and record the exclusion rule in migration paradata |
| Third-party SDKs/examples | Include only when redistribution rights and reproducibility need justify them; otherwise identify dependency/version without bundling |

Every retained byte appears below `payload/` exactly once in the asset index.
The original Unity tree remains untouched. A released VAO is written to a new
destination and is never used as the only working copy.

## Migration workflow

1. Run the existing OrgRec dataset inspection/import for the WAVE collection.
   This establishes the source identifier boundary, irregular compass, per-file
   fixity, and reviewable analysis without inventing MODAVIS facts.
2. Resolve rights and acquisition unknowns where evidence exists; retain
   explicit unknown statements otherwise.
3. Create a VAOM workspace, add the five stop and 225 sounding-position nodes,
   then add the audited interaction relations. `vaom entity` and `vaom link`
   provide validated graph authoring; UUID URNs are suitable before publication.
4. Add the byte-identical audio masters, relevant models, textures, materials,
   animations, source scripts, scene/prefab evidence, presentation audio, and
   any reviewed open-format derivatives with role and subject links.
5. Record Unity-to-open-format conversions and editorial decisions as paradata.
   Preserve both the original and derivative assets.
6. Run `vaom validate` on the workspace, `vaom pack` to a new `.vao`, and
   `vaom validate` again on the finished archive. Independently verify a sample
   of hashes and all 225 stop/note bindings.
7. Import the OrgRec-profile VAO back into OrgRec to test editable audio-project
   round-trip. Use VAOM for the full instrument-neutral multimedia graph. Export
   the IAD / Navigator projection only if MODAVIS admission review needs it.

Do not label the package preservation-, playable-, or spatial-profile conformant
until the corresponding rights, interaction, coordinate-system, open-animation,
and provenance requirements pass. A core/research VAO may still preserve the
legacy assets and clearly report those capability gaps.

## Acceptance criteria

- exactly 225 non-AppleDouble master WAVs, five stops, and the observed 45-note
  set are represented without chromatic gap filling;
- every master, model, texture, animation, and retained source file has one safe
  payload path, media type, role, byte size, SHA-256, and subject link;
- every playable binding resolves from interaction to component, configuration,
  sample, and animation/model target where applicable;
- raw, derivative, presentation, and analytical resources are distinguishable;
- source record identity is not confused with canonical MODAVIS identity;
- missing facts and excluded assets are recorded, not guessed or silently lost;
- both VAOM and OrgRec validators accept the profiles they implement, and the
  OrgRec working project round-trips byte-for-byte through its VAO profile.
