# Release status

OrgRec 0.4.0, build 14, is distributed as source on
[GitHub](https://github.com/modavis-project/orgrec/releases/tag/v0.4.0).
Build it on macOS 14 or later with Xcode 16 or newer. The prior universal
macOS app is available from the [0.3.2 release](https://github.com/modavis-project/orgrec/releases/tag/v0.3.2).

## Compatibility

- [Command-line VAO 0.6.0 export and migration](VAO_0.6_EXPORT.md) for OrgRec projects and complete VAO 0.5.0 carriers.
- VAO 0.5.0 preservation-closure export in the macOS app and exact readers for the supported earlier formats.
- The published POD 1.6.0 OrgRec projection and the pinned 1.5.0 projection. The databases are distributed separately.
- Local audio-file analysis without a project, catalogue, or microphone access.

## Verification and distribution

Tests cover the Swift processing and application state, local database identity,
source preservation, standalone reports, and VAO conformance. The export test
creates a synthetic recording project, preserves its payload bytes and realization
identifiers, and exercises the refusal paths for altered input.

A new public app bundle requires Developer ID signing, notarization, and a
Gatekeeper check. Physical interfaces and field recording setups require
separate testing with the relevant hardware.
