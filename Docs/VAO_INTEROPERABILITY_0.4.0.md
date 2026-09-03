# VAO 0.4.0 interoperability bindings

VAO composes rather than replaces domain standards:

| Domain | Binding |
| --- | --- |
| Research object | RO-Crate JSON-LD projection |
| Transport/preservation storage | BagIt payload or OCFL inventory/version |
| Citation/repository discovery | DataCite 4 projection; Zenodo remains optional |
| Presentation/alignment | IIIF Presentation 3 and Web Annotation |
| Score/performance | MEI realization and selector identifiers |
| Spatial acoustics | exact AES69-SOFA realization and VAO measurement mapping |
| Object audio | ADM realization and channel/object references |
| Geometry/scenes | glTF realization plus VAO coordinate frame |
| Control | MIDI 1, MIDI 2 UMP/MIDI-CI, OSC, host, electrical, or custom bindings |
| Provenance/measurement | PROV-O, SOSA/SSN, QUDT, CRMsci/CRMdig |
| Cultural governance | CARE and Local Contexts identifiers on rights records |

`Tools/vao04_interop.py` emits RO-Crate, DataCite, IIIF, and OCFL projections. Projections are derivatives: their byte identity and generating Activity are recorded if deposited as VAO realizations. They cannot change the VAO release identity or rights.
