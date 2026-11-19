OrgRec 0.4.0 adds a command for exporting an editable project as a VAO 0.6.0
preservation carrier. The same command can migrate a complete VAO 0.5.0 carrier.
Both operations verify the reference wheel, preserve payload bytes and realization
IDs, and write a migration receipt alongside the result.

The macOS app's Export button writes VAO 0.5.0. Use the VAO 0.6.0 reference
reader to inspect the new carriers. See the
[export guide](https://github.com/modavis-project/orgrec/blob/v0.4.0/Docs/VAO_0.6_EXPORT.md)
for the commands and prerequisites.

This release contains the source archive and its SHA-256 checksum. Build
OrgRec on macOS 14 or later with Xcode 16 or newer. The previous universal
app remains available from the [0.3.2 release](https://github.com/modavis-project/orgrec/releases/tag/v0.3.2).
