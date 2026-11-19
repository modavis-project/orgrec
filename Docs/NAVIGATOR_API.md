# Navigator integration contract

OrgRec uses the public HTTPS service at [navigator.modavis.org](https://navigator.modavis.org) for online organ lookup. A verified local POD catalogue takes precedence when installed. Find Organ shows the selected source and lets the user switch between the two.

## Organ lookup

1. Submitting a search calls `GET /api/organs` with the entered text, `limit=30`, `include_facets=0` and `sort=label` on the public instance. Search results come from the returned organ list. Typing and opening the search page do not query the service.
2. Selecting **Create recording project** or **Attach & build roadmap** fetches `GET /api/organs/{id}`. OrgRec checks the returned identity before requesting `GET /api/organs/{id}/specification`. On the public instance, these are the only two reads for an import. Search uses a single page. Media, source histories and individual pipe-position pages are outside the import.
3. On a custom deployment, OrgRec first tries `GET /api/orgrec/v1/roadmaps/{id}`. A missing roadmap route triggers the two-read compatibility path. HTTP throttling and server errors surface to the user.
4. OrgRec freezes both JSON objects and any reported release headers in a sorted-key compatibility envelope, with its own SHA-256 and retrieval time. For a dedicated roadmap it freezes the response bytes. The evidence lives at `Manifests/modavis-navigator-payload.json`. New packages become visible after the project and evidence have both been written.
5. In the public specification, the top-level component hierarchy supplies the default disposition. Alternative source descriptions stay in the frozen evidence. A component can refer to a canonical MDVS identifier, a functional pipe position or a location in the source record. The roadmap compiler uses explicit physical relationships when available. Users should check historical compasses and short octaves at the console. See [Roadmap compiler](ROADMAP_COMPILER.md).

The public organ citation supplies the POD version. Its row-set digest identifies source records for that organ. A protected database fingerprint has a different scope. When Navigator omits that fingerprint, OrgRec shows it as unavailable and retains the checksum of the retrieved payload. Use VAO for preservation in that case. Earlier OrgRec versions require the fingerprint field when opening the embedded editable project. IAD 1.0 and capture-package 2.0 require a protected fingerprint in their published schemas.

## Public instance check, 19 November 2026

A search for `Cuntz` with one result and facets disabled returned the Regensburg Positiv, `MDVS:ENTY:TX63-4D9W-W`. The first three readings cover one organ-selection workflow using the server’s default search ordering. The fourth came from a separate single-result lookup by exact MDVS ID, using the compiled Swift client with alphabetical ordering. Transfer sizes are compressed body bytes, and elapsed times include the client round trip. [Navigator organ record](https://navigator.modavis.org/organs/TX63-4D9W-W)

| Read | HTTP | Bytes transferred | Elapsed | Server-Timing |
| --- | --- | ---: | ---: | ---: |
| Search, one result | 200 | 1,329 | 0.75 s | 530 ms |
| Selected organ | 200 | 6,790 | 0.37 s | 200 ms |
| Selected specification | 200 | 6,561 | 0.28 s | 106 ms |
| Swift client ID lookup | 200 | 1,339 | 2.01 s | 1,824 ms |

The search, detail and specification advertised a five-minute HTTP cache lifetime and totalled 14,680 compressed bytes. The fourth read returned the same identifier and the expected relative organ-page path. All four API reads totalled 16,019 compressed bytes. The citation identified POD 1.6.0. The default specification documented one manual, six stops, A4 at 449 Hz and “Meantone”. Offline replay through the Swift client and compiler recovered the six stops, generated 318 proposed key/stop addresses, and reopened the project with the same frozen bytes. The source also describes a short octave. The compiler flags its mapping for a console check before field use.

This supports occasional, user-initiated lookup. For repeated work across many organs or field work without connectivity, use the local POD projection. Server capacity under concurrent use remains unmeasured. Routine regression tests use local HTTP fixtures.

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
