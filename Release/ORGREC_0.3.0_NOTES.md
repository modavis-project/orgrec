# OrgRec 0.3.0

OrgRec 0.3.0 is the first tagged source release of the native macOS field-
recording application. It records multichannel Broadcast Wave audio, retains
capture and review evidence, and exports checked research packages.

## Exchange formats

- VAO 0.5.0 is the default export format.
- The implementation is pinned to the final VAO 0.5.0 release, DOI
  `10.5281/zenodo.22214248`.
- Exact readers remain available for VAO 0.4.0, 0.3.3, and the historical 0.2
  line.
- The reduced MODAVIS Pipe Organ Dataset Release 1.5 import contract is ready,
  but the reduced dataset itself is not included or claimed as published.

## macOS application candidate

`OrgRec-0.3.0-macos-universal.zip` contains an arm64/x86_64 application for
macOS 14 or later. The private candidate is ad-hoc signed and has not been
notarized. It is provided for release-owner testing, not public Gatekeeper
distribution.

## Verification

- 209 Swift tests passed.
- VAO 0.2, 0.3, 0.4, and 0.5 conformance suites passed.
- The reduced POD contract suite passed.
- The clean source set passed the public-boundary and REUSE 3.3 audits.
- The application bundle passed plist, entitlement, architecture, and local
  signature verification.

## Publication status

The GitHub repository remains private. The software record is published at
`10.5281/zenodo.22216026`. The included macOS application is an evaluation
candidate; a normal end-user release still requires Developer ID signing,
notarization, Gatekeeper testing, hardware validation, and accessibility review.
