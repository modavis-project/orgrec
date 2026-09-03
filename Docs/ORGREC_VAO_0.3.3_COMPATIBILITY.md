# OrgRec compatibility with VAO 0.3.3

## Scope

OrgRec supports exact VAO 0.3.3 as an instrument-neutral, read-only inspection and workspace-import format. This remains separate from OrgRec's editable VAO 0.2.2 capture-project round trip. A room, complex organ, or other VAO is not silently rewritten into an OrgRec capture project.

## Supported operations

`VAO03PackageReader` provides exact format dispatch, stored ZIP/ZIP64 safety checks, NFC-normalized path-collision rejection, manifest/carrier binding, streaming CRC-32/size/SHA-256 verification, complete embedded-workspace extraction, and realization extraction by stable ID.

The typed model and semantic validator cover:

- logical assets, realizations, distributions, rights, provenance, and groups;
- coordinate frames, poses, measurements, geometry, and response layouts;
- sample mappings, variants, frame/loop regions, tuning, perspectives, and releases;
- velocity-insensitive mappings and explicit control/sounding/root-key semantics;
- complex-instrument controls, event types, MIDI bindings, state, transitions, routing, bounded processes, timing, transfer functions, and render bindings;
- capture states, event/audio alignment, take sets, and derivation maps.

The access layer exposes records only after the manifest and carrier pass validation. It does not execute process actions, synthesize an instrument, infer ranks from filenames, select segmentation hypotheses, or create sampler loops.

## Processing boundary

OrgRec does not claim native acoustic simulation, convolution, response interpolation, 3D rendering, complex-instrument synthesis, or automatic sample-set authoring. Those remain renderer or producer responsibilities. Unsupported remote realizations remain governed by the side-effect-free materialization planner and locally trusted repository adapters; workspace import does not initiate network access.

## Reference tests

The AcousticRooms fixture proves position-registered scene and embedded-carrier behavior. `Fixtures/VAO03/descriptors/kinoorgel-interaction.example.json` proves typed complex-instrument behavior without distributing the source corpus. The Python and Swift suites reject false capability claims, unresolved controls/actions, ambiguous MIDI numbering, unbounded repeaters, routing/process/derivation cycles, malformed compound actuation, timing inversions, out-of-range alignment, and Unicode-equivalent paths.

## Compatibility table

| Input | OrgRec behavior |
| --- | --- |
| VAO 0.2.2 with OrgRec Capture profile | Editable OrgRec project import and preservation-aware round trip |
| Other valid VAO 0.2.2 | General validation/workspace and asset access APIs |
| Exact VAO 0.3.3 | Read-only validated workspace import and typed acoustic/playable/interaction inspection |
| Unpublished VAO 0.3.0–0.3.2 | Rejected by exact dispatch; regenerate under the 0.3.3 schema |
| Unknown future version | Not decoded under another schema |

This support statement describes the implemented private 0.3.3 editor's draft and is not a promise of forward compatibility.
