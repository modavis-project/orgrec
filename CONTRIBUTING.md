# Contributing to OrgRec

OrgRec is research software for field recording and preservation work. Changes
must preserve recorded evidence, distinguish measurements from interpretations,
and avoid silently upgrading stored project or VAO data.

Before opening a pull request:

```sh
python3 -m pip install -r requirements-vao05.txt
VAO05_REFERENCE_PYTHON=python3 swift test
swift build -c release
python3 Tools/test_vao_conformance.py
python3 Tools/test_vao03_conformance.py
python3 Tools/test_vao04_conformance.py
python3 Tools/test_vao05_conformance.py
```

Please keep a pull request focused and describe:

- the user or research need;
- any change to persisted data, export, or validation behavior;
- tests and manual checks performed;
- privacy, rights, or security implications;
- migration behavior for existing projects.

Do not add recordings, models, datasets, or generated research outputs unless
their provenance and redistribution terms have been reviewed for the intended
public repository. Use synthetic fixtures where possible.

Changes to the VAO contract follow the additional rules in
[Docs/VAO_CONTRIBUTING.md](Docs/VAO_CONTRIBUTING.md). VAO 0.5.0 is a pinned
external standard release; normative changes belong in the VAO standard
repository rather than an OrgRec pull request. Application compatibility work
must update the declaration in
[Docs/VAO_0.5.0_MIGRATION_PLAN.md](Docs/VAO_0.5.0_MIGRATION_PLAN.md).

Participation is governed by [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
