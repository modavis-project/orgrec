# VAO governance and evolution

> Historical development record. Governance of the public VAO 0.5.0 standard
> belongs to its separate repository and release, not to OrgRec.

## Status and authority

The private VAO 0.2 line was intended to become a public-draft specification
maintained with OrgRec and the VAOM reference implementation. Its proposed
normative release consisted of the specification,
manifest schema, JSON-LD context, RDF vocabulary, profile definitions, and
conformance rules identified by one release manifest. A README, application UI,
paper, or implementation cannot unilaterally redefine the format.

Until a formal governing body is constituted, “maintainers” means the people
authorized to approve changes in the repository that publishes the normative
release. The repository must publish its decision record and must not imply
endorsement by MODAVIS, W3C, IANA, MIMO, or another organization without their
explicit authorization.

## Document maturity

- **Editor's draft:** mutable work; an unpinned working tree must not be used as
  a conformance target.
- **Private implementation snapshot:** a checksum-pinned editor's-draft source
  revision or generated candidate used only for prototypes, controlled exchange,
  and interoperability testing. Claims must name the checksum and must not imply
  public-standard status or future compatibility.
- **Release candidate:** frozen candidate artifacts under conformance review.
  A private candidate can be a conformance target only for the bounded review
  named by its checksum; it is not a public compatibility promise.
- **Public draft:** numbered `0.x` release suitable for implementation and
  feedback; compatibility is limited to its declared minor line.
- **Stable standard:** `1.x` release with frozen public identifiers and formal
  change control.
- **Deprecated:** supported only through the published transition date.
- **Withdrawn:** unsafe or unusable release retained for the historical record.

VAO `0.4.0` was the final private editor's-draft target in this repository.
VAO `0.2.2`, `0.3.3`, and `0.4.0` remain preserved historical development
lines. The public VAO `0.5.0` release supersedes their standard-development
role; its governance files and normative artifacts are maintained separately.

## Change process

A normative change proposal must state the problem, affected requirements and
artifacts, compatibility impact, security/privacy impact, migration behavior,
and conformance tests. It must include concrete before/after manifests when it
changes data shape. Significant proposals should include evidence from at least
two independent consumers or a documented reason why only one exists.

Approval requires:

1. review by a maintainer who did not author the change;
2. passing schema, semantic, archive, security, fixture, Swift, and Python tests;
3. updated specification, schemas, implementations, fixtures, changelog, and
   release metadata in the same change;
4. explicit classification as patch-compatible or compatibility-breaking;
5. a migration note for every breaking or meaning-changing change.

Editorial corrections that cannot change conforming behavior may use the patch
process. A change to required fields, meaning, validation outcome, profile
requirements, identifiers, archive layout, or security behavior is normative.

## Version and compatibility policy

VAO uses `MAJOR.MINOR.PATCH` format versions. Before 1.0, `0.MINOR` is the
compatibility line. Readers for `0.2` accept `0.2.x`, preserve unknown optional
URI-keyed extensions, and reject other minor lines. Patch releases cannot make
a valid earlier package in the same line invalid unless the earlier behavior is
a security vulnerability; such an exception must be documented prominently.

Private, unpublished snapshots are allowed a stricter pre-public contract
revision when the changelog, migration behavior, release metadata, and positive
and negative tests are updated together. That permission does not create a
public compatibility promise. VAO 0.2.0 established the pre-public breaking
minor contract line: it has new schema/context/profile IRIs and requires
explicit migration from prior private manifests. VAO 0.2.1 is a
backward-compatible patch contract revision within that line: it added the
optional empirical-timbre-classification and pitch-dependent-rank-fingerprint
capabilities without invalidating conforming 0.2.0 packages. VAO 0.2.2 is the
next backward-compatible patch: it adds the optional
collection-acoustic-diagnostics capability and its evidence-qualified analysis
without invalidating conforming 0.2.0 or 0.2.1 packages.

VAO 0.3 is a separate pre-public breaking line. Version 0.3.3 supersedes the
unpublished 0.3.0–0.3.2 snapshots under the private-snapshot exception above.
The 0.3.3 complex-interaction records are optional and structurally additive,
but exact draft dispatch changed without a public compatibility promise.
Historical published Sandbox evidence remains immutable.
The 0.3 line introduces immutable
semantic releases, carrier-specific embedding, exact byte realizations,
optional repository distributions, and materialization receipts. Repository
use is optional: development, testing, private sharing, and preservation MAY be
fully embedded. Zenodo is one optional adapter and MUST NOT be a Core
requirement. Its publication default is one modular record, with an explicit
related record family only where operational or rights boundaries justify it.

Every new minor or major line receives new schema, context, and profile IRIs.
Vocabulary terms keep stable IRIs when their meaning is unchanged. A term whose
meaning changes is superseded by a new term; existing term meaning is not
silently rewritten. Released artifacts are immutable.

The `revision` inside a manifest describes revisions of one VAO and is unrelated
to the format version. The MODAVIS ontology version and VAO-to-MODAVIS mapping
version are also independent and must remain explicit.

## Extension and profile policy

Extensions use absolute IRIs controlled by their publisher. An extension must
not weaken core validation, redefine a standard field, hide payload content, or
cause active content to execute on open. Required capabilities are declared in
profiles. An implementation that lacks one must report the profile as
unsupported rather than treating the package as corrupt.

A profile proposal documents its use case, dependency profiles, required
entities/relations/assets/paradata, codec or protocol requirements, privacy and
rights implications, and executable conformance checks. Private profiles must
not use the VAO namespace without allocation by the maintainers.

The allocated experiential/XR profile at
`https://w3id.org/modavis/vao/profile/experiential/0.2` is a modular
capability profile rather than an application manifest. New standard
experiential capabilities require stable capability and graph-term IRIs,
dependency declarations, executable positive and negative cases, and evidence
that they are not inferred from filenames or tied to one runtime. Adding an
optional capability or entity kind in the `0.2` line is patch-compatible only
when old packages remain valid and consumers can preserve the unknown
URI-keyed graph. Tightening an existing capability's required graph or changing
a property shape is meaning-changing and requires either a security exception
with migration guidance or a new compatibility line.

An optional scientific capability must name its governed analysis type,
required observations, units and aggregation methods, and evidence/provenance
requirements. Its applicability and insufficient-evidence behavior are part of
the contract. Review candidates remain analytical results: a similarity or
anomaly candidate must not be promoted into physical identity, shared-pipe,
construction, fault, or documentary component relations without independently
qualified source or curator evidence.

## Namespace, registries, and media type

Before claiming public deployment, maintainers must control and test redirects
for every `https://w3id.org/modavis/vao/` version, profile, vocabulary, and
latest-version IRI. Persistent responses should content-negotiate human-readable
documentation and machine-readable artifacts where practical.

`application/vnd.modavis.vao+zip` is provisional in 0.2. Distribution metadata
must not say it is IANA-registered until registration is accepted. The `.vao`
extension is conventional and should be registered in relevant operating-system
and repository registries without taking ownership of unrelated prior uses.

## Security and disclosure

Archive-processing vulnerabilities, hash-validation bypasses, unsafe active
content, privacy leaks, or ambiguous rights behavior may justify an expedited
patch. Reports follow `Docs/VAO_SECURITY.md`. A security patch may tighten acceptance
within a compatibility line when accepting the old form would be unsafe; the
release notes must name the previously accepted condition.

## Path to 1.0

The stable 1.0 milestone requires public and tested namespaces, approved
licensing, a resolved media-type strategy, at least two independent readers and
writers, representative fixtures for non-organ instrument classes and every
normative profile, documented preservation review, security review, real-world
round trips, and a migration specification from the last `0.x` line.
