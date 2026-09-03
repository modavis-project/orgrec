# Field QA, consistency, and paradata

OrgRec separates three questions that are easy to conflate during fieldwork:

1. Is this capture ready to start?
2. Is the project internally consistent?
3. Is the project sufficiently documented for checked Navigator export?

The **Field QA** workspace answers all three and links each finding to the screen
where it can be resolved.

## Visual guidance

The Roadmap shows coverage cards per organ division, including accepted,
review, and missing counts. Its MODAVIS banner reports component hierarchy,
tuning, temperament, builder/date, action/wind facts, source count, and stop-
count reconciliation when those values exist.

Record shows a readiness panel before the signal controls. Blocking issues
disable recording. The capture protocol has a time-position indicator across
room tone, sustain, and release-tail phases. Live channel meters, clipping state,
and operator key events remain visible throughout capture.

Field QA shows a project score, blocker/warning totals, the five-stage workflow,
current-capture readiness, the active session form, and the complete issue list.
Issues carry scope, evidence, remediation, and optional roadmap/take identifiers.

## Recording sessions

A project has one active recording session. Opening an older project creates a
new active session without rewriting old takes. A session records:

- session code and timestamps;
- operator and institution;
- scientific purpose and rights/consent statement;
- IANA timezone and clock source;
- venue condition and notes;
- temperature, relative humidity, and atmospheric pressure.
- an optional frozen, revisioned surrounding-noise assessment with confirmed
  venue coordinates, search radius, source attribution, query fingerprint,
  mapped findings, review disposition, priority, and operator notes;
- structured noise incidents observed during capture, linked to the take and
  its elapsed timeline position.

Starting a new session closes the prior session. Captures require an active
session with an operator.

## Immutable take provenance

At recording start, OrgRec copies the relevant mutable project state into the
take. Later setup or roadmap edits cannot alter the historical interpretation.
The snapshot includes:

- complete session context and environment;
- the session-plan identity/revision and frozen surrounding-noise assessment;
- capture recipe and version;
- microphone setup, revision, geometry, gains, phantom-power state, and routing;
- activated stop/coupler/accessory registration;
- MODAVIS component and locator;
- Release 1.1 binding and frozen Navigator payload checksum;
- organ identity and OrgRec provenance contract version.

Human accept/reject actions append review events with author, time, reason, and
the analysis algorithm version. Automated output and manual marker corrections
remain separate assertions.

## Consistency rules

Blockers include:

- missing or changed Navigator payloads;
- an empty roadmap or a capture package with no recorded takes;
- roadmap locators bound to another organ or snapshot;
- duplicate or orphaned roadmap/take identifiers;
- accepted coverage without an accepted take;
- missing original audio or checksum drift;
- missing setup/interface/microphone references;
- invalid channel routing;
- dropped buffers, discontinuities, or writer faults;
- accepted takes without analysis;
- accepted take and roadmap states that disagree.

Warnings include missing environmental fields, equipment serials or setup
photographs, MODAVIS count disagreements, assumed compasses/reference pitch,
clipping, large pitch deviation, nonchronological transient markers, legacy
takes without frozen provenance, recording sessions without a surrounding-noise
assessment, and legacy review decisions without history. Invalid plan, Roadmap,
or assessment references are blockers.

## Export

Navigator capture export reruns the audit against files on disk and refuses to
build while blockers remain. Successful contract-1.1 exports contain:

- `consistency-report.json` and its SHA-256 entry;
- the consistency score in `capture-package.json`;
- per-take immutable provenance and review history;
- existing audio, BWF, analysis, partial, annotation, project, MODAVIS snapshot,
  frozen Navigator payload, and integrity-manifest content.

Warnings are preserved in the report so a receiving research workflow can apply
its own acceptance policy without losing local evidence.
