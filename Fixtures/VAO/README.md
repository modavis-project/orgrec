# VAO conformance fixtures

`valid/minimal-string-instrument` is the normative minimal positive fixture for
the VAO 0.2 core profile. It is an unpacked authoring workspace so changes are
reviewable in source control. `Tools/test_vao_conformance.py` validates it and
creates the actual `.vao` container in a temporary directory.

`valid/minimal-playable-string-instrument` is the positive playable-profile
fixture. It demonstrates protocol-independent interaction and component
activation without pretending that core conformance alone makes an object
playable. It intentionally has no sample or synthesis implementation; apps must
still negotiate the concrete behavior and media capabilities they support.

`valid/minimal-experiential-instrument` is the positive 0.2.2 experiential/XR
graph fixture. It exercises model viewing, synchronized media/animation, both
AR modes, spatial listening, offline groups, and declarative replaceable
performance media. It retains the reviewed sampled-playback mapping, exact
source extraction region, qualified acoustical observation, and unique-key
tuning map introduced in 0.2.1. The suite validates its manifest and payload
bytes directly.

VAO 0.2.2 does not retrofit a fabricated collection analysis into that small
experiential fixture. Complete positive
`collection-acoustic-diagnostics` packages are exercised through OrgRec's
Swift writer and both independent validators, using reports whose assessed
takes, quality ledger, rank/session evidence, anomaly candidates, and
similarity candidates have real graph referents. The cross-platform suite adds
generated negative mutations for a capability claim without its governed
analysis and for inconsistent collection evidence coverage. Packages and
fixtures that do not claim the optional capability remain valid 0.2 inputs.

`valid/minimal-acoustic-room` is the positive VAO 0.2 acoustics fixture. It
binds an IFC semantic room, explicit source/receiver poses, an AES69 SOFA
response, ISO 3382 metric, spatial audio scene, and tracked 6DoF renderer
contract. Its tiny payload is conformance metadata, not a scientific SOFA test
file; external codec conformance is deliberately separate.

Negative fixtures are generated as mutations of the valid fixture to prevent a
malformed example from being mistaken for a reusable package. The conformance
test names the expected rejection for each mutation, including invalid sample
ranges, tuning duplicates, source binding, frame-clock completeness, unit
identity, coordinate-frame cycles, acoustic provenance, band alignment,
learned-field lineage, collection capability/evidence consistency, and runtime
fallback behavior.
