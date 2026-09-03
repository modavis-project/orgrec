# ComparativeStopTimbre research runner

The repository-level launcher is
`python3 Tools/vpo_reproduce.py --help`; it delegates to this directory's
versioned implementation.

This directory contains the study-specific statistics for the versioned OrgRec
comparative export. It does not decode audio or recompute spectral descriptors.
See [`../../Docs/COMPARATIVE_STOP_TIMBRE_STUDY.md`](../../Docs/COMPARATIVE_STOP_TIMBRE_STUDY.md)
for the protocol, claims, limitations, and complete commands.

Requirements:

- Python 3.11 or later
- NumPy 2.x
- Matplotlib 3.8 or later

Run:

```sh
python3 Research/ComparativeStopTimbre/analyze.py \
  /path/to/Study/comparative-corpus.json \
  /path/to/Results
```

The source audit is separate because the filesystem-scale collection is larger
than the currently analyzable GrandOrgue subset:

```sh
python3 Research/ComparativeStopTimbre/audit_sources.py \
  /path/to/downloaded_instrument_inventory.csv \
  /path/to/native-corpus-inspection.json \
  /path/to/Audit \
  --root /path/to/pipe-organ-datasets-a \
  --root /path/to/pipe-organ-datasets-b
```

## Reacquire and verify the analyzed VPO subset

`vpo_reproduce.py` and `vpo-source-routes.json` implement reproducible source
acquisition. The immutable lock is
`Artifacts/ComparativeStopTimbre/vpo-analysis-acquisition-lock.json`.

```sh
python3 Research/ComparativeStopTimbre/vpo_reproduce.py audit \
  --lock Artifacts/ComparativeStopTimbre/vpo-analysis-acquisition-lock.json

python3 Research/ComparativeStopTimbre/vpo_reproduce.py download \
  --lock Artifacts/ComparativeStopTimbre/vpo-analysis-acquisition-lock.json \
  --destination /path/to/vpo-analysis-inputs \
  --accept-source-terms

python3 Research/ComparativeStopTimbre/vpo_reproduce.py verify \
  --lock Artifacts/ComparativeStopTimbre/vpo-analysis-acquisition-lock.json \
  --destination /path/to/vpo-analysis-inputs
```

The final command returns `analysis-input equivalent` only if all ten selected
GrandOrgue definitions and all 1,112 distinct analyzed audio byte streams match
their frozen SHA-256 values. Otherwise it returns `dataset variant`. See
[`../../Docs/VPO_DATASET_REPRODUCIBILITY.md`](../../Docs/VPO_DATASET_REPRODUCIBILITY.md)
for current availability, backup verification, licence handling, and the
boundary between the analyzed subset and the former 591 GB discovery corpus.

For a mounted historical backup, the full no-download workflow is one command:

```sh
python3 Research/ComparativeStopTimbre/vpo_reproduce.py reproduce-backup \
  --mac-root /path/to/backup/source-a \
  --xfer-root /path/to/backup/source-b \
  --historical-mac-prefix /exact/first/prefix/from/inventory \
  --historical-xfer-prefix /exact/second/prefix/from/inventory \
  --output /path/to/reproduction-output
```

It fails closed at the raw-byte, feature-corpus, and statistical-result
equivalence gates. The exact inventory, catalog, lock, corpus and result
references are repository defaults. See the reproducibility document for the
formal boundaries and the executed 2026-08-31 backup result.
