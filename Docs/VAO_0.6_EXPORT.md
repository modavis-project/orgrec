# Export to VAO 0.6.0

Use the source checkout to export an OrgRec project to VAO 0.6.0 or to migrate
a complete 0.5.0 carrier made with the app. The macOS app's export button still
writes 0.5.0. Use the [VAO 0.6.0 reference reader](https://github.com/modavis-project/vao-standard/releases/tag/v0.6.0)
to inspect the new carrier. OrgRec's native importers cover the earlier formats
listed in the [compatibility guide](VAO_0.5.0_MIGRATION_PLAN.md).

Build the dataset tool and install the reference validator's dependencies
in a Python virtual environment:

```sh
swift build --product OrgRecDatasetTool
orgrec_tool="$(swift build --show-bin-path)/OrgRecDatasetTool"
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements-vao05.txt
```

Download `vao_standard_tools-0.6.0-py3-none-any.whl` from the
[VAO v0.6.0 release](https://github.com/modavis-project/vao-standard/releases/tag/v0.6.0).
The export command checks the wheel's SHA-256 before loading its migrator,
schemas, and validator. With the wheel in your current directory:

```sh
vao_wheel=vao_standard_tools-0.6.0-py3-none-any.whl
python3 Tools/export_vao06.py export Recording.orgrec Recording-0.6 \
  --orgrec-tool "$orgrec_tool" --reference-wheel "$vao_wheel"
```

For a carrier already exported as VAO 0.5.0, use `migrate`:

```sh
python3 Tools/export_vao06.py migrate Recording.vao Recording-0.6 \
  --orgrec-tool "$orgrec_tool" --reference-wheel "$vao_wheel"
```

Choose a new directory under an existing parent, outside the project. The
command writes the verified carrier and `migration-receipt.json` there. Keep
both files. The receipt records the old and new manifest hashes, release
identities, and the retained realization IDs. The migration copies the original
payload bytes and leaves the project or source carrier intact.

The migration requires every realization of the original VAO release to be
embedded. Materialize partial carriers before running it. It preserves existing
provenance and adds a migration activity. MMIC authoring requires a separate
review of the source and its capabilities. See the
[VAO migration contract](https://github.com/modavis-project/vao-standard/blob/v0.6.0/Docs/MIGRATION_0.5_TO_0.6.0.md).

The test makes a small synthetic project and uses the actual export commands.
It compares source and output payloads and realization IDs, then checks refusal
of a changed wheel, a damaged carrier, and an existing output directory:

```sh
python3 Tools/test_vao06_export.py \
  --orgrec-tool "$orgrec_tool" --reference-wheel "$vao_wheel"
```
