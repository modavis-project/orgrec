# Security policy for the VAO standard

VAO parsers process untrusted archives. Reports concerning path traversal,
links or special files, ZIP ambiguity, decompression or resource exhaustion,
duplicate paths, hash or CRC bypass, unsafe automatic content execution,
manifest-reference confusion, or privacy disclosure should be handled as
security issues rather than ordinary interoperability questions.

Until a public security address is approved, do not publish exploit details in
an unrestricted issue. Contact the authorized repository maintainers privately
and include the affected version, a minimal reproducer, impact, platform, and
any suggested mitigation.

Historical contract lines remain private development artifacts. A security fix
may intentionally reject content accepted by an earlier snapshot; the release
notes must identify the changed acceptance rule. No package content is trusted
merely because its container or manifest validates.
