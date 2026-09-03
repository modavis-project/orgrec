# VAO 0.3 Zenodo Sandbox adapter trial

This record is a CC0 conformance fixture for the optional Zenodo repository adapter. It is not a production VAO publication, an approved standard release, or a dependency of VAO Core.

The record demonstrates exact version-DOI, record-ID, and file-key resolution followed by VAO SHA-256 verification. The companion `embedded-private.vao` fixture demonstrates that VAO 0.3 remains fully conforming without a repository, DOI, network, or Zenodo.

Version 1.0.1 corrects a Sandbox-specific DOI namespace discrepancy discovered by the 1.0.0 trial: the draft API advertised `10.5281`, while publication assigned `10.5072`. The earlier bytes were not replaced; this corrected immutable version pins the actual `10.5072` version and concept DOIs.
