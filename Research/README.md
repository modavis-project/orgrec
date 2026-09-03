# Research workflows

## Comparative VPO stop-timbre study

The implemented comparative spectral study and raw-data reproducer are in
`Research/ComparativeStopTimbre`.

- Scientific protocol: `Docs/COMPARATIVE_STOP_TIMBRE_STUDY.md`
- Dataset/acquisition protocol: `Docs/VPO_DATASET_REPRODUCIBILITY.md`
- Discoverable launcher: `python3 Tools/vpo_reproduce.py --help`
- Frozen and executed evidence: `Artifacts/ComparativeStopTimbre/`

The raw-data workflow verifies a cryptographically defined ten-VPO analyzed
subset, rebuilds OrgRec features, reruns the grouped statistics, and compares
the results. It does not claim equivalence of the complete former 591 GB
discovery collection.
