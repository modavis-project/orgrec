# OrgRec changelog

This file records changes to the OrgRec application and its command-line tools.
The separate [VAO standard changelog](Docs/VAO_CHANGELOG.md) records changes to
the exchange-format contract.

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
