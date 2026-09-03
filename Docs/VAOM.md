# Virtual Acoustic Object Manager (VAOM)

VAOM is the cross-platform reference tool for the VAO 0.2 compatibility line
and the implemented VAO 0.3 editor's draft. The repository ships an executable
Python 3 implementation at `Tools/vaom.py`; it uses only the Python standard
library and therefore runs on macOS, Windows, and Linux without a package
installation.

## Commands

```sh
# Create an authoring workspace whose primary entity is an instrument.
python3 Tools/vaom.py init MyInstrument \
  --title "Museum violin" \
  --entity-kind instrument \
  --entity-type https://w3id.org/modavis/ontology/instrument#MusicalInstrument \
  --classification https://w3id.org/modavis/vocab/instrument-type/violin

# Add and logically associate an asset.
python3 Tools/vaom.py add MyInstrument recording.wav \
  --role https://w3id.org/modavis/vao/vocab/asset-role/audio-master \
  --representation-status https://w3id.org/modavis/vao/vocab/representation-status/captured \
  --about urn:uuid:REPLACE-WITH-PRIMARY-ENTITY-ID

# Add a component node and an evidence-capable relation.
python3 Tools/vaom.py entity MyInstrument \
  --kind component \
  --type https://w3id.org/modavis/ontology/instrument#InstrumentComponent \
  --label "Bowed string"

python3 Tools/vaom.py link MyInstrument \
  urn:uuid:PRIMARY-INSTRUMENT \
  https://w3id.org/modavis/ontology/instrument#hasComponent \
  --object urn:uuid:COMPONENT \
  --status accepted

# Validate a workspace, then build the single file.
python3 Tools/vaom.py validate MyInstrument
python3 Tools/vaom.py pack MyInstrument Museum-Violin.vao

# Inspect or validate without extracting.
python3 Tools/vaom.py inspect Museum-Violin.vao
python3 Tools/vaom.py validate Museum-Violin.vao --json

# Copy and migrate an unpacked private 0.1 workspace; never overwrite it.
python3 Tools/vaom.py migrate-0.1 Legacy-Instrument Migrated-Instrument

# Safely extract into a new directory.
python3 Tools/vaom.py unpack Museum-Violin.vao Museum-Violin

# Migrate a validated 0.2.2 workspace into a new 0.3 workspace.
python3 Tools/vaom.py migrate-0.2 Museum-Violin-0.2 Museum-Violin-0.3

# Validate, pack, and issue a local materialization receipt for 0.3.
python3 Tools/vaom.py validate Museum-Violin-0.3
python3 Tools/vaom.py pack-0.3 Museum-Violin-0.3 Museum-Violin-0.3.vao
python3 Tools/vaom.py receipt-0.3 Museum-Violin-0.3 receipt.json
```

The optional Zenodo adapter is invoked separately and only for a manifest that
declares a Zenodo binding. Adapter instance, API base, host allowlist, and
credentials are local policy:

```sh
python3 Tools/vao03_zenodo.py vao-manifest.json urn:uuid:DISTRIBUTION --instance sandbox --metadata-only --json
```

No repository is required. `Fixtures/VAO03/valid/embedded-private` is the
positive, fully embedded proof for development, testing, and private exchange.

`entity` adds instrument-neutral typed nodes, including components, states,
configurations, interactions, experiences, asset groups, sources, assertions,
measurements, spatial regions, and agents. `link` adds resource or typed-literal relations with
status, evidence, and processing lineage. Each change is transactionally
validated before the manifest is replaced.

`migrate-0.1` accepts only an unpacked private 0.1 workspace, rejects links,
special files, unsafe nesting, and local resource-limit violations, and writes
to a new destination. The result retains the original manifest as a hashed
source-evidence asset and records a migration activity, mapping version, and
review notes. It does not upgrade by relabeling the source archive.

`pack` recomputes each indexed asset's SHA-256 and byte size, refuses unindexed or missing payload files, writes `mimetype` first and uncompressed, and writes all entries with the portable ZIP stored method. `unpack` rejects traversal paths, links, duplicate names, unsupported compression, oversize entries, and an existing destination unless `--force` is explicitly supplied.

## Validation output

Exit status is zero only when container, manifest, fixity, reference, and all
claimed-profile semantic checks pass. This includes URI-graph, dependency,
coordinate, geometry-selector, room/building, acoustic-response, metric,
spatial-audio scene, listener-tracking, runtime-fallback, physical-dimension,
timeline, AR, listening, offline-group, and declarative replaceable-media
checks for the claimed profiles. VAO 0.2.2 also checks source-bound exact-frame
extraction, qualified observations, reviewed sample mappings, loop clocks,
tuning-map uniqueness, the corrected musical-cent unit, calibrated timbre
inference, pitch-dependent rank fingerprints, and the optional
`collection-acoustic-diagnostics` contract. For the latter it verifies the
research dependency, inferred metric paradata, immutable parameter fingerprint
and domains, exact observation set, evidence/ledger reconciliation, robust
rank/session value constraints, and candidate-only anomaly/similarity results.
See [`COLLECTION_ACOUSTIC_DIAGNOSTICS.md`](COLLECTION_ACOUSTIC_DIAGNOSTICS.md)
for the analytical interpretation. JSON output
is stable enough for CI:

```json
{
  "valid": true,
  "errors": [],
  "warnings": [],
  "formatVersion": "0.2.2",
  "id": "https://example.org/vao/museum-violin",
  "container": "archive",
  "claimedCapabilities": [
    "https://w3id.org/modavis/vao/vocab/capability/core-graph"
  ],
  "supportedCapabilities": [
    "https://w3id.org/modavis/vao/vocab/capability/core-graph"
  ],
  "unsupportedCapabilities": [],
  "assetCount": 3,
  "verifiedBytes": 18422811
}
```

The command deliberately reports unsupported optional capabilities separately from package corruption. It never executes embedded scripts or opens content through an associated application.

## Desktop manager direction

The CLI is the reference codec and validation core. A future desktop VAOM should wrap the same contract, not fork it. Its main workspaces should be:

1. object tree and time-scoped configurations;
2. asset inventory with preview and fixity;
3. relation graph with unresolved-reference and missing-link diagnostics;
4. evidence/assertion/conflict review;
5. paradata and processing lineage;
6. analytical observations, exact signal regions, tuning maps, reviewed sample
   playback decisions, evidence-qualified collection diagnostics, review
   candidates, and large-result assets;
7. semantic building geometry, coordinate frames, poses, materials, measured or
   simulated responses, spatial-audio scenes, and rendering contracts;
8. 3D/animation/interaction binding;
9. rights, access, profiles, validation, diff, and immutable release export.

The desktop application should use an unpacked transactional workspace, content-addressed local cache, autosaved operation log, and explicit release command. Released `.vao` files remain immutable. Plug-ins may preview or analyze content but receive least-privilege access and must return declared outputs and paradata rather than mutating the graph invisibly.

## Security model

VAOM treats every imported package as untrusted. Previewers are optional and
sandboxed; active content is never executed. Archive validation precedes
extraction, and hash verification precedes use. VAO 0.2 external URLs are not
fetched automatically and required exchange content remains embedded. VAO 0.3
repository distributions are resolved only by an explicitly invoked, locally
trusted adapter. Credentials, API bases, host/redirect allowlists, and access
policy stay outside the package.
