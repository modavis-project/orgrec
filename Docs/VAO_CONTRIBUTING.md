# Contributing to the VAO standard

VAO remains a private, unpublished development standard. A normative change
proposal must include:

1. the use case and affected profile;
2. before/after manifests;
3. container, schema, semantic, security, privacy, rights, and migration impact;
4. conformance fixtures and independent-reader behavior;
5. compatibility classification;
6. ontology and vocabulary consequences;
7. provenance and licenses for any borrowed material.

Container rules remain in VAO. Reusable domain semantics should be proposed to
MODAVIS and mapped conservatively. Do not copy draft MODAVIS vocabulary values
into the VAO namespace as substitutes for reviewed concept IRIs.

Run before review:

```sh
python3 Tools/check_vao_release.py
python3 Tools/test_vao_conformance.py
swift test
swift build -c release
```

No contribution, test result, or release-candidate bundle authorizes public
publication. The no-publish gate is recorded in
`Release/vao-release-metadata.json`.
