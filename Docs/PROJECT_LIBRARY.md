# OrgRec project library

OrgRec treats a recording campaign as an explicit project package, not as a
global mutable session. The macOS application opens on a project library and
groups packages by the organ's stable MODAVIS identifier. A project created
offline receives a local identity until a Navigator specification is attached.

## Recommended workflow

1. Search MODAVIS from the large **Find a pipe organ** entry point.
2. Choose an organ. OrgRec freezes the retrieved Navigator payload and creates
   a separate managed project whose roadmap is compiled from the specification.
3. Review the organ characteristics, compilation warnings, stops, compasses,
   couplers, accessories, and planned registration captures.
4. Configure interfaces and microphone setups, then record and review takes.
5. Export a validated `.vao` as the portable exchange and preservation object.
   Export the editable project only for continued OrgRec field work, or the IAD
   / Navigator projection when a MODAVIS admission review specifically needs it.

When network access is unavailable, **New local project** creates an empty
project shell. Choosing an organ later upgrades that empty shell in place. Its
project ID, title, creation time, interface inventory, microphone setups, and
analysis configuration are preserved while the temporary local organ identity
is replaced by the frozen MODAVIS binding and generated roadmap.

## Managed storage and organ grouping

Managed packages live below:

`~/Library/Application Support/OrgRec/Projects/`

Each package uses the `.orgrec` extension and contains `project.json`, original
and derivative audio, analysis outputs, documentation, manifests, and exports.
The library scans only this managed directory. It does not silently index or
modify arbitrary external folders.

Projects are grouped by `organMDVSID`; local-only projects fall back to their
normalized organ name. Multiple recording campaigns, venues, dates, techniques,
or teams can therefore remain separate projects under the same organ heading.
Opening a project is blocked while recording is active.

## Create, plan, import, and export

- **Create from MODAVIS:** retrieves the specification, stores its checksum-
  verified payload, and compiles the roadmap into a new project.
- **New local project:** creates an offline shell and routes directly to organ
  search for later attachment.
- **Plan:** opens the selected project's roadmap without merging it into the
  currently active project.
- **Import VAO, project, or IAD:** OrgRec-profile VAOs are validated at the
  container, graph, reference, byte-size, and SHA-256 levels before losslessly
  restoring the editable project. Editable projects validate `project.json`.
  Legacy IAD packages retain their existing normalized-index checks.
- **Import existing audio dataset:** inspect before writing, choose the adapter
  and exact source descriptor where one exists, review identity, rights,
  structure, unresolved references and preservation scope, then create a new
  project only after all blocking checks pass. The source remains read-only;
  originals are copied with fixity and the adapter decision record is frozen in
  `Manifests/`.
- **Export VAO:** builds the primary single-file exchange object with the whole
  OrgRec package, typed instrument graph, all original/derived files, sessions,
  takes, configurations, annotations, paradata, analyses, rights, explicit
  MODAVIS binding, and per-asset fixity.
- **Export editable project:** copies the entire `.orgrec` package for backup,
  transfer, or continued work on another Mac.
- **Export IAD / Navigator package:** builds the self-contained dataset with
  original recordings, analysis, annotations, frozen MODAVIS payload, SHA-256
  integrity, and normalized candidate indexes for the MODAVIS audio, media,
  measurement, device, and paradata schemas.
- **Open from Finder:** `.vao` and `.orgrec` are registered macOS document types
  and are routed through their validated import paths.

Existing destinations are never overwritten by export. Imported packages and
new projects receive unique managed names when a package with the same name
already exists.

The complete adapter-independent lifecycle and failure contract are in
[`EXISTING_AUDIO_DATASET_TO_VAO.md`](EXISTING_AUDIO_DATASET_TO_VAO.md).
[`GRANDORGUE_IMPORT.md`](GRANDORGUE_IMPORT.md) defines ODF behavior, and
[`BUREA_GRANDORGUE_VAO_CASE_STUDY.md`](BUREA_GRANDORGUE_VAO_CASE_STUDY.md)
records the executed acceptance case.

## Navigator synchronization boundary

Release 1.1 remains the data contract. OrgRec reads through Navigator and keeps
the retrieved response frozen with the project; it does not write directly to
the MODAVIS database. A future authenticated Navigator API can use the project
ID, MODAVIS organ ID, snapshot hash, capture manifest, and sync receipts for
idempotent synchronization without changing the project-library model.
