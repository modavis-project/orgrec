# OrgRec changelog

This file records changes to the OrgRec application and its command-line tools.
The separate [VAO standard changelog](Docs/VAO_CHANGELOG.md) records changes to
the exchange-format contract.

## 0.3.2 — 2026-09-11

### Added

- Standalone audio-file analysis through drag-and-drop, a file picker and Finder
  opening, without a project or POD catalogue.
- Channel, sound-type, reference-pitch and excerpt controls; linked waveform,
  spectrogram, pitch and partial displays; complete measurement inspection.
- PDF reports, full JSON, six CSV tables, editable SVG and PNG figures, and a
  complete export folder with the analyzed excerpt, provenance and checksums.
- First-launch guidance covering catalogue installation, local projects,
  microphone access, capture setup and test recordings.

### Changed

- Support the published POD 1.6.0 OrgRec projection, including gzip verification,
  source-version preservation and disclosed-component roadmap selection.
- Retain the pinned POD 1.5.0 projection as a supported source.
- Keep catalogue inspection off the main UI actor and provide installation
  activity, retry guidance and a direct continuation to organ search.
- Defer project loading while new users remain in Getting Started or Analyze Audio.
- Release the universal macOS app and source as version 0.3.2, build 13.

### Reliability

- Preserve original audio and exact excerpt coordinates; bound decoded excerpt
  size; reject non-finite samples and invalid selections; retain completed
  results after failed reanalysis; stage folder exports before installation.
- Qualify unknown-source pitch interpretations and use the existing detected-
  partial confidence threshold for exported figures. Full candidate evidence
  remains available in the data exports.

## 0.3.1 — 2026-09-10

### Fixed

- Bound stable-sustain analysis by the earliest release marker; never extend
  short intervals into the release tail.
- Prevent overlapping harmonic-bin ownership and integrate Hann main-lobe
  power for more stable relative partial levels.
- Estimate temporal partial noise only from observed quiet regions, preserving
  continuous tones when no quiet baseline exists.
- Keep partial extraction independent of spectrogram display time-bin limits.
- Use the actual transient sample hop for timing and omit spectral partitions
  for silence or unresolved harmonics.

### Added

- Read-only POD 1.5 SQLite validation, verified offline caching, catalogue
  search, roadmap projection, and command-line database workflows.
- Regression fixtures for spectral segmentation and POD database behavior.

### Changed

- Record analysis method versions and segmentation parameters for reproducibility.
- Update source-release metadata to version 0.3.1, build 9.

## 0.3.0 — 2026-09-01

### Added

- Public-release readiness, VAO 0.5.0 migration, and reduced POD integration
  plans.
- Public repository CI and contribution templates.
- A privacy statement covering local project data and optional network calls.
- Hardened Runtime audio-input entitlement for packaged builds.
- Native VAO 0.5.0 reader, writer, validation, preservation-closure export,
  carrier inspection, workspace import, and realization extraction.
- Frozen VAO 0.5.0 schemas, semantic artifacts, release bundle, compact
  conformance fixture, Python reference tools, and native/reference cross-checks.
- A versioned reduced-POD subset manifest contract, exact fixity validation,
  staged cache import, command-line support, application workflow, and a
  source-free synthetic fixture.
- Apache-2.0/CC-BY-4.0 license mapping and corrected MIT attribution for the
  bundled CREPE/torchcrepe conversion.

### Changed

- Separated OrgRec software citation metadata from VAO standard metadata.
- Reworked the repository landing page around current, verified behavior and
  explicit pre-release limits.
- Made VAO 0.5.0 the default export line while retaining version-specific
  historical readers.
- Removed generated research outputs, workstation paths, rights-restricted
  interoperability payloads, and the pending empirical classifier from the
  public software source set.

### Distribution

- Source release tagged as `v0.3.0` in the private staging repository.
- macOS 14 universal application candidate for Apple silicon and Intel Macs.
- Software record published at DOI `10.5281/zenodo.22216026`.
- The application candidate is ad-hoc signed. Developer ID signing,
  notarization, Gatekeeper, hardware, and accessibility evidence remain
  requirements for public binary distribution.

## 0.2.0 — private development build

- Native macOS capture, review, analysis, project persistence, Navigator
  integration, and VAO import/export implementation.
- This version has not been issued as a public software release.
