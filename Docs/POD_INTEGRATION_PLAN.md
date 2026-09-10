# POD integration

Current supported releases and installation behavior are documented in [POD 1.6.0 compatibility](POD_1.6_COMPATIBILITY.md). The original 1.5 integration specification follows for historical reference.

# MODAVIS POD 1.5 local database integration

Status: SQLite compatibility implemented and verified against the private
Zenodo draft artifact; public download URL pending

OrgRec uses the reduced MODAVIS Pipe Organ Dataset (POD) 1.5 OrgRec projection
as an optional, read-only local organ catalogue and roadmap source. The
database is published separately on Zenodo and is not part of the application
bundle or Git repository.

## Pinned artifact

- filename: `modavis-pod-1.5-orgrec.sqlite`
- size: `418177024` bytes
- SHA-256:
  `dd57394627c91d9fa3f4f3bfd1770c773184345448af80bef63d834de0cbc464`
- database metadata release: `1.5.0`
- projection profile: `orgrec`
- artifact profile: `public_structured_dataset`
- database contract: `modavis.release-1.5-public-preparation/v1`

The public Zenodo URL is deliberately absent until the record is published.
Private draft URLs and access tokens must never be stored in source, project
metadata, logs, or release artifacts. Changing only the download URL does not
change the pinned database identity; changed bytes require an explicit size and
digest update plus a new compatibility run.

## Observed release contents

The verified draft contains:

| Table | Rows |
| --- | ---: |
| `organ` | 215,769 |
| `organ_alias` | 3,881 |
| `builder` | 11,778 |
| `organ_builder` | 151,233 |
| `component` | 503,980 |
| `component_provenance` | 503,980 |
| `technical_parameter` | 115,814 |
| `source` | 25 |
| `roadmap_eligibility` | 23,586 |

It also contains contentless FTS5 indexes for organ and component search. The
database declares that structured facts, identifiers, and source citations are
included while raw source media and raw descriptive prose are excluded.

## Compatibility behavior

OrgRec opens the database using SQLite's read-only mode and enables
`query_only`. Validation checks:

- a regular, non-symbolic input file and successful SQLite `quick_check`;
- exact Release 1.5, projection, artifact, and contract metadata;
- required tables and columns, allowing compatible additive columns;
- non-empty core tables and one provenance row per component;
- component and roadmap references to existing organs;
- working FTS5 organ and component indexes;
- SHA-256 stability while the file is inspected;
- exact published byte size and digest before local cache admission.

A selected local file is copied to a temporary sibling, fully revalidated, and
then atomically moved into `Application Support/OrgRec/Datasets/POD`. A failed
copy or validation removes the staging file. The source is never modified.
The app remembers only the verified cache path, not a Zenodo URL or token.

The HTTPS retrieval path downloads to a system temporary file, rejects failed
or non-HTTPS final responses, checks the pinned size and digest, validates the
database contract, and only then admits the file to the cache. Once cached,
search and roadmap creation work without network access.

## Local catalogue and roadmap projection

Organ search uses `organ_search` for labels and MDVS identifiers and the
builder relations for builder-name matches. Alias identifiers resolve through
`organ_alias`. OrgRec exposes only
`component_comparison_ready` organs for specification-derived roadmap import;
`technical_facts_only` records remain searchable but cannot silently produce an
incomplete component roadmap.

For a selected eligible organ, OrgRec freezes a deterministic JSON projection
containing the database metadata, organ, builders, component provenance, and
technical parameters. Its digest becomes the project snapshot digest; the
database digest becomes the protected Release 1.5 fingerprint. Stops,
couplers, accessories, divisions, pitch labels, documented pitch standards,
builders, action facts, wind facts, and source citations are transferred where
the database provides them. Missing compass metadata remains unknown and is
not inferred.

## Command-line workflows

```text
OrgRecDatasetTool pod-db-validate <database.sqlite> [inspection.json]
OrgRecDatasetTool pod-db-import <database.sqlite> <cache.sqlite>
OrgRecDatasetTool pod-db-download <https-url> <cache.sqlite> [--sha256 <digest>] [--bytes <count>]
OrgRecDatasetTool pod-db-search <database.sqlite> <query> [--limit <count>]
```

The download command defaults to the pinned size and digest. Explicit values
add a caller-supplied check and do not bypass the application's pinned
cached-release identity.

## Verification

`PODDatabaseTests` creates source-free SQLite fixtures for positive validation,
search, aliases, roadmap projection, documented pitch transfer, atomic import,
wrong-release rejection, and incomplete-schema rejection. Setting
`ORGREC_POD_DATABASE` runs the release-level test against an external database,
including the full row-count thresholds, FTS search, and roadmap compilation.

Before publishing a new POD database artifact:

1. run the complete Swift test suite;
2. run the release-level test with `ORGREC_POD_DATABASE`;
3. run `pod-db-validate` and `pod-db-search` on the downloaded Zenodo bytes;
4. confirm anonymous resolution of the final public URL;
5. replace the pending URL in public documentation without committing draft
   credentials.
