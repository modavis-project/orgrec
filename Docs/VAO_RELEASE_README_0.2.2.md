# Planned VAO 0.2.2 release contents

VAO 0.2.2 is a historical private compatibility-line candidate. It adds the
optional collection-acoustic-diagnostics contract to 0.2.0 and 0.2.1 without
invalidating conforming packages from those versions. It is not a public or
stable standard.

The candidate bundle contains:

- the 0.2 specification, implementation guide, conformance rules, governance,
  changelog, and release checklist;
- the manifest schema, JSON-LD context, vocabulary, and provisional MODAVIS
  audio-loop terms;
- Python and Swift reference implementations;
- minimal core, playable, experiential, and acoustic-room fixtures;
- checksum-indexed release metadata and guarded build tooling.

Run:

```sh
python3 Tools/check_vao_release.py
python3 Tools/test_vao_conformance.py
python3 Tools/build_vao_release.py
```

Public release remains blocked by `Release/vao-release-metadata.json`. A newer
private format line does not retroactively publish this historical candidate.
