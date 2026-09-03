# VAO schema routing

- `vao-manifest-0.5.0.schema.json` and the adjacent 0.5.0 context,
  vocabulary, MODAVIS mapping, SHACL shapes, carrier, release, pack,
  receipt, and repository schemas are exact copies from the final VAO 0.5.0
  release (`v0.5.0`, DOI `10.5281/zenodo.22214248`). Their bytes are pinned by
  `vao-release-bundle-0.5.0.json`. OrgRec writes 0.5.0 and retains exact 0.4.0,
  0.3.3, and 0.2.2 readers for compatibility.

- `orgrec-pod-subset-1.schema.json` is the closed application contract for the
  separately published reduced POD subset derived from Release 1.5. Its `$id`
  is a local URN until a durable OrgRec namespace is issued.

- `vao-manifest-0.4.0.schema.json`, `vao-context-0.4.0.jsonld`,
  `vao-vocabulary-0.4.0.ttl`, and `vao-shapes-0.4.0.ttl` are retained private
  editor's-draft artifacts. The adjacent 0.4.0 descriptor
  schemas and `vao-release-bundle-0.4.0.json` complete the normative bundle.
- 0.4.0 replaces open scientific records with typed provenance, adds multimodal
  clocks/tracks, physical topology, deterministic runtime traces, MIDI 2,
  chunking, consent/community rights, discovery, and lossless RDF projection.

- `vao-manifest.schema.json`, `vao-context.jsonld`, and `vao-vocabulary.ttl`
  remain the VAO 0.2 compatibility-line artifacts.
- `vao-manifest-0.3.schema.json`, `vao-context-0.3.jsonld`, and
  `vao-vocabulary-0.3.ttl` are the VAO 0.3.3 editor's-draft artifacts.
- `vao-carrier-0.3.schema.json`, `vao-release-0.3.schema.json`,
  `vao-pack-manifest-0.3.schema.json`,
  `vao-materialization-receipt-0.3.schema.json` define the separate 0.3
  carrier, repository, pack, and runtime records.
- `vao-zenodo-metadata-0.3.schema.json` defines the optional Zenodo deposit
  metadata projection. It is not required by VAO Core or repository-free use.

The 0.3.3 manifest schema closes the Spatial/Acoustics scene model, including
coordinate frames, poses, geometry bindings, stable source/receiver
measurements, response sets, and realization-specific impulse-response layout.
It also preserves the protocol-independent Playable interaction baseline and
closes the optional sampled-instrument registries for exact regions, loops,
tuning, perspectives, variants, and mappings.

It also closes optional sampled-instrument, complex-interaction, and capture-
lineage contracts, including explicit protocol numbering, guarded state/routing,
bounded processes, transfer functions, and exact derivative provenance.

The 0.3.3 release descriptor defaults to one modular publication record and
can instead declare an exact root/member record family. The same `/0.3` schema,
context, vocabulary, and profile IRIs identify this pre-public compatibility
line; exact artifact dispatch uses `formatVersion: "0.3.3"`.

Version dispatch uses the manifest `formatVersion`; processors must not apply
one VAO compatibility-line schema to another format version.
