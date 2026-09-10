# OrgRec 0.3.1

Version 0.3.1 (build 9) updates spectrum segmentation and adds read-only POD 1.5
SQLite catalogue support.

Stable-sustain analysis respects release boundaries. Harmonic regions have
unique FFT-bin ownership, relative partial levels integrate Hann main-lobe
power, and continuous tones remain detectable without a quiet baseline.
Partial evidence is independent of display resolution. Low-rate transient
timing and silent-spectrum handling are corrected.

POD database workflows validate the schema and pinned artifact, create a
verified offline cache, search organs, and project eligible specifications into
recording roadmaps. The database is distributed separately.

The source tag is `v0.3.1`. No new macOS binary or Zenodo deposit is included in
this source update. VAO remains pinned to version 0.5.0.

## Verification

- Full Swift suite: 222 tests passed; the external POD database test was skipped.
- VAO 0.2, 0.3, 0.4, and 0.5 Python conformance suites passed.
- Reduced POD subset contract and native/reference export cross-check passed.
- Source-boundary and licensing checks passed.
