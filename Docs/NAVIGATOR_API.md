# Navigator integration contract

OrgRec treats Navigator as the only MODAVIS network boundary. It never connects
to the database directly and never edits the checked-in release workspaces.

## Implemented retrieval flow

1. Search GET /api/organs?q={query}&limit=30&include_facets=0.
2. Prefer GET /api/orgrec/v1/roadmaps/{mdvs-id}.
3. On a 404, compose a compatibility profile from GET /api/organs/{mdvs-id}
   and GET /api/organs/{mdvs-id}/specification.
4. Freeze the response, ETag, retrieval timestamp, SHA-256, release state, and
   protected database fingerprint in the local project. The exact response bytes
   are stored under `Manifests/modavis-navigator-payload.json` and hash-checked
   again during capture-package export.
5. Bind every roadmap component with one of three locator strengths:
   canonical MDVS identifier, functional pipe-position reference, or
   source-record plus source-path locator.

The profile decoder tolerates the current Navigator envelope variants while
preserving the raw payload checksum. The dedicated future endpoint should return
contractVersion modavis.navigator.orgrec-roadmap/v1 and explicit component
locators.

The compatibility compiler consumes Navigator's `componentHierarchy`, including
divisions, keyboards, stops, ranks, ordinary pipes, couplers, and accessories.
It reads nested component detail, `pipeQuantity.actuationRange`, documented
stop-to-rank and shared/borrowed/extension relationships, and per-key physical
pipe mappings. OrgRec treats only those explicit structures as automatic
physical identity; compatible stop names and footages produce review candidates
rather than deduplication.
compasses, source paths, and functional position references. See
`ROADMAP_COMPILER.md` for coverage semantics. Choosing an organ creates a new
project package; it never erases an existing organ's takes.

OrgRec also derives a specification profile from fields already exposed by
Navigator: documented versus parsed stop counts, manuals/keyboards, divisions,
ranks, pipe positions, couplers, accessories, builder/date, action type, wind
pressure, tuning pitch, temperament, source records, and source URLs. Sparse
fields remain optional and are never invented. Count disagreements and missing
compasses become visible audit findings instead of being silently normalized.

## Planned submission flow

POST /api/orgrec/v1/submissions accepts the exported capture package as an
idempotent upload. The capture-package SHA-256 is the Idempotency-Key. Navigator
must validate checksums, release binding, locator resolution, authorization, and
schema version before staging any ingestion. A successful response returns a
submission identifier and status; it does not imply automatic database
publication.

The client method is implemented. The MVP UI intentionally exposes export first
because the Navigator submission endpoint is not yet present.

Capture packages include the frozen MODAVIS roadmap snapshot and project plus
checksum-addressed audio, BWF sidecars, annotations, derivatives, and a per-take
analysis envelope. That envelope carries automated analysis, configurable
spectrogram/partial results, capture diagnostics, audio-device provenance,
reference-channel selection, BWF metadata, and immutable marker corrections.
Navigator should treat corrections as provenance-bearing assertions rather
than destructive replacements for automated measurements.

Capture package contract 2.0 includes `consistency-report.json` and binds the
`org.modavis.instrumental-audio-dataset/1.0` manifest by SHA-256. Navigator export is
blocked while the local report contains a blocker, including snapshot drift,
missing originals, broken roadmap/take links, invalid setup references, capture
continuity failures, accepted coverage without an accepted take, or an accepted
take without analysis. Each per-take analysis envelope also carries the frozen
take-provenance snapshot and review-decision history.
