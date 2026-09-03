# VAO 0.2.2 to 0.3.3 migration

`python3 Tools/vaom.py migrate-0.2 SOURCE DESTINATION` performs a non-destructive workspace migration. The source must validate as 0.2.2. The destination must not exist.

For non-Spatial/non-Acoustics packages, the migrator preserves graph, MODAVIS, relation, paradata, analysis, and source-manifest evidence. Every indexed 0.2 asset becomes one `LogicalAsset`, one `Realization`, and one carrier mapping. It creates only an embedded bootstrap group; it does not invent remote files, repository bindings, or materializable profile claims.

A baseline 0.2 Playable interaction migrates without a sample implementation: its interaction entity, properties, active relation, and capability remain the profile's protocol-independent contract. A 0.2 package that claims `sampled-instrument-playback` requires producer enrichment into the closed 0.3.3 sample registries. The reference migrator stops before creating the destination rather than guessing how old parameter sets, samples, loop/release records, tuning, and variant-selection semantics should be partitioned.

An acoustic 0.2.2 workspace requires an explicit enrichment migration because 0.3.3 separates stable logical measurements from realization-specific response indexing and requires exact sample/channel and coordinate-transform facts. The reference command detects such a workspace and stops before creating the destination. A producer must assign measurement IDs, verify source/receiver poses and frame transforms, and derive byte-layout metadata from the actual RIR realization. This is a deliberate safety boundary: the migrator never invents a sample count, SOFA convention, channel mapping, or physical coordinate transform.

The migration report records source and destination manifest hashes, the release ID, and every old asset-to-logical-asset/realization mapping. Representation status is preserved. Because 0.2 rights are not consistently asset-addressable, each migrated realization references all applicable source rights records; the report flags this conservative mapping for editorial review.

Migration is a semantic release change, not an in-place format rewrite. Validate and review the destination before packing or publishing.
