# VPO dataset acquisition and equivalence

Status: implemented and audited 2026-08-31  
Acquisition-lock contract: `orgrec-vpo-analysis-acquisition-lock/1`

The scientific protocol is documented in
[`COMPARATIVE_STOP_TIMBRE_STUDY.md`](COMPARATIVE_STOP_TIMBRE_STUDY.md).
Run `python3 Tools/vpo_reproduce.py --help` for the acquisition and
verification commands.

## What is known

The catalog and consolidated inventory preserve stable entity IDs, sampled
instrument names, producers, licences/access models, and documentary source
pages. The frozen retrieved corpus additionally preserves the SHA-256 of the
selected GrandOrgue definition and every source audio file that produced a pipe
observation.

Ten VPO entities contributed ranks to the reported analysis:

- VPO-083, Romanswiller Stiehr-Mockers;
- VPO-085, Bureå Choir Organ;
- VPO-086, Bureå Church Organ;
- VPO-087, Bureå Funeral Chapel Organ;
- VPO-088, Bygdsiljum Church Organ;
- VPO-089, Jukkasjärvi Church Organ, specifically the AB 2024-12-02 edition;
- VPO-090, Kalvträsk Church Organ;
- VPO-091, Norrfjärden Baroque Organ;
- VPO-092, Piteå School Organ;
- VPO-187, Veendam De Kandelaar Kaat & Tijhuis.

The versioned source routes are in
`Research/ComparativeStopTimbre/vpo-source-routes.json`. On 2026-08-31 all ten
direct packages were reachable and their server-reported lengths matched the
locked expected lengths: 10,403,634,043 compressed bytes in total. Nine lengths
are independently anchored in a historical acquisition record or a retained
source archive. The old Kalvträsk archive-length record did not survive, so its
compressed length was re-baselined from the live server on that date. This is
evidence of availability and a useful change detector, but byte length alone
does not prove identity.

The immutable
`Artifacts/ComparativeStopTimbre/vpo-analysis-acquisition-lock.json` contains:

- all ten selected definition SHA-256 values;
- 1,112 distinct source-audio SHA-256 values, scoped to their entity;
- the 1,206 pipe-observation and 138 rank counts;
- exact edition/download routes and expected compressed sizes;
- hashes of the frozen catalog, inventory, retrieved corpus, and route table;
- the formal equivalence and variant rules.

## Equivalence boundary

An acquisition is **analysis-input equivalent** only when every one of the ten
entities contains:

1. the selected GrandOrgue definition with the locked SHA-256; and
2. every distinct audio byte stream used by the frozen pipe observations with
   the locked SHA-256.

The package-relative structure must be preserved so the definition continues
to resolve its samples. The downloader retains each original archive and
extracts to a separate directory without reorganizing it.

If any required entity, definition, or analyzed audio digest is absent or
changed, the verifier reports **dataset variant** and exits with status 2. A
variant can still support a new study, but its results must not be represented
as an exact reproduction of the reported corpus.

This definition intentionally concerns the scientific analysis input. The
former 591 GB discovery collection contained many packages and formats that did
not enter the statistical analysis. Its original append-only acquisition logs
were not retained outside the deleted source directories, and no complete
collection-wide package/per-file cryptographic manifest survives. Consequently,
byte-for-byte equivalence of the entire former collection is not currently
assessable from the catalog and inventory alone.

A separate backup of the former collection exists on another machine. That is
the preferred preservation and recovery source. Verification of the ten
analysis-contributing entities against the lock is sufficient for the present
study and avoids an unnecessary reconstruction of all 591 GB. A future project
that requires the whole discovery collection should copy that backup without
transformation and create a complete per-file SHA-256 manifest before further
use or deletion.

## Download and verify

No third-party Python packages are required. On macOS, `/usr/bin/bsdtar` is
used for RAR/7z packages; `unar` is an accepted fallback. ZIP-compatible
`.orgue` files use Python's ZIP implementation. Archives are retained, unsafe
archive paths are rejected, partial HTTP transfers are resumable, existing
nonmatching downloads are never overwritten, and a current terms/licence
acknowledgement is required.

First check current availability without downloading payloads:

```sh
python3 Research/ComparativeStopTimbre/vpo_reproduce.py audit \
  --lock Artifacts/ComparativeStopTimbre/vpo-analysis-acquisition-lock.json \
  --report /path/to/vpo-source-route-audit.json
```

Download and preserve the ten locked packages (currently about 10.4 GB
compressed):

```sh
python3 Research/ComparativeStopTimbre/vpo_reproduce.py download \
  --lock Artifacts/ComparativeStopTimbre/vpo-analysis-acquisition-lock.json \
  --destination /path/to/vpo-analysis-inputs \
  --accept-source-terms
```

The operator must review the current licence and access terms before using the
acknowledgement flag. Free access is not equivalent to unrestricted
redistribution.

Then perform the cryptographic completeness check:

```sh
python3 Research/ComparativeStopTimbre/vpo_reproduce.py verify \
  --lock Artifacts/ComparativeStopTimbre/vpo-analysis-acquisition-lock.json \
  --destination /path/to/vpo-analysis-inputs \
  --report /path/to/vpo-analysis-input-verification.json
```

The verifier reads both extracted files and unextracted ZIP-compatible `.orgue`
packages. A successful report says `analysis-input equivalent`; any missing or
changed locked byte stream produces `dataset variant`.

Individual entities can be downloaded with repeated `--entity VPO-NNN` flags.
This supports incremental acquisition without weakening the final all-entity
verification.

## Verify the other-machine backup in place

The historical backup layout may not put every entity in a directory named by
its catalog ID. Repeat `--entity-root ENTITY_ID=PATH` to map an entity to its
actual backup directory. Multiple entities may point to the same directory;
the verifier indexes that shared directory only once. This is useful for the
historical `VPO-1216` directory containing the Lars Palo packages.

An illustrative command is:

```sh
python3 Research/ComparativeStopTimbre/vpo_reproduce.py verify \
  --lock Artifacts/ComparativeStopTimbre/vpo-analysis-acquisition-lock.json \
  --destination /path/to/unused-default-root \
  --report /path/to/backup-analysis-input-verification.json \
  --entity-root 'VPO-083=/path/to/PipeOrgan-IADs-2/VPO-083 Romanswiller Stiehr-Mockers/extracted' \
  --entity-root 'VPO-085=/path/to/PipeOrgan-IADs/VPO-1216' \
  --entity-root 'VPO-086=/path/to/PipeOrgan-IADs/VPO-1216' \
  --entity-root 'VPO-087=/path/to/PipeOrgan-IADs/VPO-1216' \
  --entity-root 'VPO-088=/path/to/PipeOrgan-IADs/VPO-1216' \
  --entity-root 'VPO-089=/path/to/PipeOrgan-IADs/VPO-1216' \
  --entity-root 'VPO-090=/path/to/PipeOrgan-IADs/VPO-1216' \
  --entity-root 'VPO-091=/path/to/PipeOrgan-IADs/VPO-1216' \
  --entity-root 'VPO-092=/path/to/PipeOrgan-IADs/VPO-1216' \
  --entity-root 'VPO-187=/path/to/PipeOrgan-IADs-2/VPO-187 Veendam Kaat Tijhuis/extracted'
```

Adjust only the path prefixes to the mounted backup. The entity IDs and which
Jukkasjärvi edition is selected must not be changed.

## One-command raw-data reproduction

`reproduce-backup` performs the complete guarded workflow. It remaps the exact
historical 119-row inventory, checks that every path formerly recorded as
present still exists, verifies the ten contributing sources against the
acquisition lock, rebuilds the spectral-feature corpus with OrgRec, compares
its scientific payload with the frozen corpus, exports the comparative study,
runs the prespecified statistics, and compares the resulting summary and CSV
tables. It never invokes the downloader. Existing matching corpus checkpoints
are resumed.

```sh
python3 Research/ComparativeStopTimbre/vpo_reproduce.py reproduce-backup \
  --mac-root '/path/to/backup/source-a' \
  --xfer-root '/path/to/backup/source-b' \
  --historical-mac-prefix '/exact/first/prefix/from/inventory' \
  --historical-xfer-prefix '/exact/second/prefix/from/inventory' \
  --output /path/to/reproduction-output
```

The exact historical inventory and catalog are retained under
`Artifacts/ComparativeStopTimbre/Inputs` and are the defaults, as are the lock,
reference corpus and reference results. Their SHA-256 values are respectively
`4e48584649e9229c1c637b60b5c9e3ffba2a8852fb572637b7e7835bc3781094`
and `697874930ba14550dc5779ad25768c905ee8930b44d12b2fcec0a7205de00dce`,
exactly matching the values frozen in the source corpus and acquisition lock.
The corresponding command-line options remain available for an independently
relocated reference package.

The command stops before feature extraction if an historically present path is
missing or if the lock verifier reports a dataset variant. It stops before
statistics if the rebuilt scientific corpus is a variant. Its final
`reproduction-run.json` says `exact scientific reproduction` only when all
three gates pass.

Corpus comparison excludes only machine/run provenance and semantically inert
identifiers: generation time, software build metadata, relocated catalog,
inventory and definition paths, the changed remapped-inventory hash, and the
random UUID assigned to each newly created observation record. It retains and
compares every definition/audio SHA-256, documentary label, exclusion, warning,
pitch estimate, spectral feature, partial vector, and analysis option. Result
comparison is an exact canonical comparison of `summary.json` and all eight
analysis CSV tables. Renderer-dependent PNG/SVG bytes and the intentionally
changed run-provenance file are not used to define numerical equivalence.

## Executed backup reproduction, 2026-08-31

An offline read-only backup was used to execute the complete workflow without
downloading data. The retained evidence is under
`Artifacts/ComparativeStopTimbre/Reproduction` and establishes:

- all 119 inventory paths were remapped; all 76 paths historically marked
  present still existed;
- 10/10 selected definitions and 1,112/1,112 entity-scoped audio files matched
  the frozen SHA-256 lock (completeness 1.0);
- the rebuild produced 12 completed instrument records, including the two
  zero-rank records, 138 ranks and 1,206 pipe observations;
- after excluding newly generated observation UUIDs and relocation provenance,
  the rebuilt and frozen feature payloads had the identical canonical SHA-256
  `6c782de3cf53a063a99ef24169006944bfce7833da3b0663fcd4bceb9a767571`;
- `summary.json` and every inferential, classification and PCA CSV table were
  canonically identical; and
- the run manifest records `downloadedBytes: 0` and status
  `exact scientific reproduction`.

This is stronger than merely rerunning the statistics on a frozen table: the
spectral descriptors were recomputed from independently mounted backup bytes.
It remains an analysis-subset reproduction, not a cryptographic assertion that
every unused byte in the former 591 GB discovery collection is identical.

## Recreate or audit the lock

The lock is mechanically generated from the frozen corpus and its exact catalog
and inventory inputs:

```sh
python3 Research/ComparativeStopTimbre/vpo_reproduce.py lock \
  --corpus Artifacts/ComparativeStopTimbre/retrieved-local-research-corpus.json \
  --inventory Artifacts/ComparativeStopTimbre/Inputs/downloaded_instrument_inventory.csv \
  --catalog Artifacts/ComparativeStopTimbre/Inputs/virtual_pipe_organ_datasets_and_instruments_2026-08-17_expanded_3600.csv \
  --routes Research/ComparativeStopTimbre/vpo-source-routes.json \
  --output /path/to/recreated-lock.json
```

Lock creation refuses catalog or inventory files whose SHA-256 differs from the
frozen corpus. With the frozen inputs and route table it is deterministic.

## Remaining reproducibility distinction

Three levels should be kept separate in publications:

1. **Statistical reproducibility:** already possible from the frozen comparative
   JSON; no source audio is required.
2. **Analysis-input reproducibility:** possible by downloading or restoring the
   ten contributing packages and obtaining a successful lock verification.
3. **Full discovery-collection reconstruction:** not cryptographically defined
   by the surviving records; use the other-machine backup and create a new full
   fixity manifest if that broader collection becomes scientifically relevant.
