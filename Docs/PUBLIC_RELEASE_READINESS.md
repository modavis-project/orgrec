# Public-release readiness

Assessment date: 2026-09-01

Decision: OrgRec 0.3.0 is released on Zenodo at DOI
`10.5281/zenodo.22216026`; its source repository remains private at
`modavis-project/orgrec`. Contract, source-boundary, licensing, metadata, and
automated-test work that can be completed locally is in place. Public GitHub
release remains gated by final review. A normal macOS end-user distribution
also requires Apple signing and notarization.

## Completed in the source tree

### VAO 0.5.0

- final normative artifacts are pinned to DOI `10.5281/zenodo.22214248`, commit
  `ad2d4f0`, and the release-bundle digest;
- native 0.5.0 reader, validator, preservation-closure writer, workspace
  importer, and realization extractor are implemented;
- application and CLI exports use 0.5.0 by default;
- Python and Swift validators cross-check generated packages in CI;
- exact historical readers remain isolated by format version.

### Reduced POD subset

- the `orgrec-pod-subset/1` manifest and exact Release 1.5 provenance boundary
  are implemented;
- closed inventory, path, duplicate, byte-length, digest, and wrong-release
  failures are enforced;
- import uses a staging directory, revalidates, and atomically commits to a
  removable local cache;
- UI and CLI workflows are present;
- the repository fixture is explicitly synthetic and contains no POD bytes.

The final dataset DOI, source DOI, license, selection commit, and payload
checksums are intentionally absent until the separate subset deposit exists.

### Public source boundary

- generated `Artifacts` content is excluded from the software source archive;
- the rights-restricted Cuntz payload is excluded and no longer required by
  conformance tests;
- source and documentation use portable example paths;
- the locally trained empirical classifier is not bundled pending the reduced
  POD release and a reviewed model card;
- compact synthetic or explicitly licensed fixtures cover public tests;
- local research data is not part of the software release.

### Licensing and community files

- Apache-2.0 covers OrgRec code, tests, and automation;
- CC-BY-4.0 covers documentation, schemas, semantic artifacts, metadata, and
  synthetic fixtures;
- `REUSE.toml` records the path mapping;
- CREPE/torchcrepe attribution and MIT terms are corrected;
- citation, changelog, contribution, privacy, support, security, issue, and
  pull-request files are present.

## Remaining publication gates

These require decisions, credentials, or identifiers outside the local source
tree.

### 1. GitHub publication

- retain the clean release history in the private
  `modavis-project/orgrec` repository;
- review repository membership before changing visibility;
- enable private vulnerability reporting;
- protect the default branch and require CI for release changes;
- enable or document Issues/Discussions policy;
- review the tagged `v0.3.0` source and release assets before publication.

### 2. Zenodo software record

Record `22216026` was published on 2026-09-01. `CITATION.cff` remains the
maintained repository metadata source; Zenodo-only fields are maintained on the
record.

- version DOI: `10.5281/zenodo.22216026`;
- concept DOI: `10.5281/zenodo.22216025`;
- resource type: software;
- source, macOS candidate, evidence, and checksum material are supplied in one
  release archive;
- creator ORCID, affiliation, languages, licenses, copyright, keywords,
  development status, programming languages, related identifiers, and the VAO
  reference are recorded;
- the uploaded archive and DOI resolution must be rechecked after any permitted
  post-publication correction.

### 3. Reduced POD dataset record

The dataset is a separate Zenodo `dataset` record, not a GitHub software asset.
Before enabling production acquisition or claiming evaluation against it:

- publish the cleared payload and frozen manifest;
- pin the exact POD Release 1.5 version identifier and source-manifest digest;
- review item-level attribution, license, transformation, and exclusion data;
- test anonymous DOI and file resolution;
- verify the same results from a fresh offline cache.

OrgRec can be published without bundling the dataset, but the release notes must
describe the integration as prepared rather than presenting the pending subset
as available.

### 4. macOS binary distribution

The private app candidate is a universal arm64/x86_64 bundle with an ad-hoc
Hardened Runtime signature. A public binary additionally requires:

- Developer ID signing with Hardened Runtime and audio-input entitlement;
- notarization, ticket stapling, `codesign`, `spctl`, and Gatekeeper checks on
  the exact uploaded archive;
- clean-account microphone-permission and first-run tests;
- multichannel interface, clock-change, device-removal, sleep, disk-pressure,
  quit, recovery, VoiceOver, and keyboard-only checks;
- binary SHA-256, architecture list, minimum macOS version, and an SBOM.

Source publication and binary publication may be separate release milestones.

## Release evidence record

Complete `Release/ORGREC_RELEASE_TEMPLATE.md` for the final tag. It records the
source commit and archive hash, test evidence, VAO compatibility, POD status,
license inventory, binary/notarization evidence, GitHub release, and Zenodo
identifiers.

Run the machine-readable source audit before every candidate:

```sh
python3 Tools/audit_public_release.py
```

The audit distinguishes local source blockers from external publication gates;
it does not replace maintainer, legal, security, or binary-distribution review.

## Service documentation

- [GitHub repository limits](https://docs.github.com/en/repositories/creating-and-managing-repositories/repository-limits)
- [GitHub large-file guidance](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)
- [GitHub citation files](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-citation-files)
- [Zenodo software metadata](https://help.zenodo.org/docs/github/describe-software/)
- [Zenodo GitHub archiving](https://help.zenodo.org/docs/github/archive-software/github-upload/)
- [Apple audio-input entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.audio-input)
- [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
