# POD 1.6.0 compatibility

OrgRec supports the OrgRec convenience projection from [POD 1.6.0](https://doi.org/10.5281/zenodo.22308263). The public core and other convenience profiles are different products and cannot be substituted for it. The previously pinned OrgRec 1.5.0 projection remains readable with its original release identity.

## Exact release identity

| Property | POD 1.6.0 OrgRec projection |
| --- | --- |
| SQLite filename | `modavis-pod-1.6.0-orgrec.sqlite` |
| Expanded bytes | 5,814,468,608 |
| Expanded SHA-256 | `e8c97e7cc2b9d36a11d66ea317335367175e1cc9542ce0c4275fd27089c8b1e0` |
| Gzip bytes | 1,791,863,814 |
| Gzip SHA-256 | `df6090ab11629cb8894fc088b352d4261ddd4ea83fc438d321b6332ddcbb44a3` |
| Release metadata | `1.6.0` |
| Database contract | `modavis.release-1.6.0-public-preparation/v1` |
| Projection | `orgrec` |

The digests come from the published package manifest. The application validates the compressed archive before expansion, verifies the expanded size and digest, and then performs SQLite integrity, schema, relationship, identifier and search-index checks before atomic cache admission. An unpacked SQLite file can also be selected directly. The source file is opened read-only. Allow space for the 5.8 GB database plus download and temporary cache copies.

## Search and roadmap semantics

POD 1.6.0 has 4,790,379 component rows, of which 4,774,115 belong to the three disclosed label classes: `fact_label_included`, `public_structured_label`, and `structured_source_fact`. Full-text index completeness is checked against this disclosed set, and surplus or missing search rows are rejected. Component FTS row identifiers are assigned after filtering and must not be joined to component-table row identifiers; exact artifact fixity validates the released index. Withheld, excluded, and reference-only component rows cannot enter a recording roadmap.

Source occurrences and historical accounts do not establish a count of distinct physical stops or the current state of an organ. Frozen project snapshots retain release metadata and component provenance; users must review the applicable instrument state and recording targets. Additional 1.6.0 evidence tables are allowed without claiming a complete interface to every research table.

Project snapshots and documented pitch evidence retain the actual source version. Opening a supported 1.5.0 database does not relabel its evidence as 1.6.0.

## Use

In **Data Exchange → POD**, use the prefilled Zenodo URL to download and verify the gzip archive, or select an unpacked SQLite file. After caching, use **Find Organ** to search and create a source-bound recording roadmap. Full-file inspection runs off the main UI actor.

For independent verification:

```sh
ORGREC_POD_DATABASE=/path/to/modavis-pod-1.6.0-orgrec.sqlite swift test --filter PODDatabaseTests
```

Synthetic tests retain legacy 1.5.0 behavior, exercise 1.6.0 release provenance and label restrictions, reject mismatched metadata, and verify both compressed and decoded digests. The external test additionally exercises the complete release file, real catalogue search, and roadmap generation.
