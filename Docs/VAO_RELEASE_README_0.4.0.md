# VAO 0.4.0 private editor's-draft contents

VAO 0.4.0 is the current development target. It is a breaking successor to the unpublished 0.3.3 snapshot and makes no public compatibility promise. It is implemented for prototypes, scientific evaluation, private exchange, and bounded conformance testing. It is not yet an approved public standard.

Start with:

- `Docs/VAO_STANDARD_0.4.0.md` — normative standard;
- `Docs/VAO_CONFORMANCE_0.4.0.md` — validation and implementation roles;
- `Docs/VAO_SCIENTIFIC_PROFILE_0.4.0.md`;
- `Docs/VAO_MULTIMODAL_PROFILE_0.4.0.md`;
- `Docs/VAO_PHYSICAL_INSTRUMENT_PROFILE_0.4.0.md`;
- `Docs/VAO_PLAYABLE_PROFILE_0.4.0.md` and `Docs/VAO_ACOUSTIC_SCENES_0.4.0.md`;
- `Docs/VAO_INTEROPERABILITY_0.4.0.md`;
- `Schemas/vao-release-bundle-0.4.0.json` — exact normative artifact checksums;
- `Tools/vao04.py` — reference validator, carrier writer, and private migrator;
- `Tools/vao04_runtime.py` — deterministic reference interpreter;
- `Tools/vao04_rdf.py` and `Tools/vao04_interop.py` — linked-data and external projections;
- `Fixtures/VAO04/descriptors/kinoorgel-multimodal-scientific.example.json` — positive integration fixture.

Run:

```sh
python3 Tools/build_vao04_spec.py
python3 Tools/build_vao04_fixture.py
python3 Tools/test_vao04_conformance.py
swift test
swift build -c release
```

The 0.2.2 and 0.3.3 artifacts remain checked in as historical private compatibility lines and regression targets. Public release remains blocked by the unchecked items in `Docs/VAO_RELEASE_CHECKLIST_0.4.0.md`.
