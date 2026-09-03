# MODAVIS specification to recording roadmap

## Selection contract

Choosing an organ in Navigator creates a separate `.orgrec` project. Existing
takes are never cleared. OrgRec freezes the organ and specification responses as
one checksummed snapshot, retains every recognized specification component, and
then compiles the recording roadmap. If no speaking stop or explicit playable
position can be found, selection fails visibly and the current project remains
untouched.

The exact canonical Navigator response is written to
`Manifests/modavis-navigator-payload.json`; its SHA-256 must match the snapshot
record before the project is activated or exported. OrgRec remembers the last
active organ project across launches.

The compiler understands Navigator Release 1.1 component hierarchy groups for
divisions, keyboards, stops, ranks, pipes, couplers, and accessories. It also
recognizes playing aids as accessories and reads source-backed fields from both
the component and its nested `detail` object.

## Exhaustive physical coverage

The completeness baseline is every distinct physical sound target under every
configured microphone technique. A logical console address is the combination
of stop, key, and isolated registration used to reach that target; it is not
necessarily a distinct pipe. OrgRec therefore:

1. reads a stop's exact MIDI range or nested `pipeQuantity.actuationRange`;
2. inherits a documented compass from its division or keyboard;
3. expands the stop into stable logical activation routes for each chromatic key
   selected by the recipe;
4. resolves physical identity only from canonical pipe identifiers, explicit
   pipe mappings, shared-rank positions, or snapshot-bound reviewed assertions;
5. groups routes only when their complete physical pipe sets are equal; and
6. calculates nominal sounding frequency from the documented foot designation,
   marking it as an expectation to be confirmed by CREPE rather than a physical
   length measurement.

For an extended rank, Prinzipal 8′ C3 and Prinzipal 4′ C2 may therefore be two
activation routes to one physical target. The target is queued once per recipe,
technique, and microphone setup. Only the mapped overlap is grouped; unique bass
and treble extensions remain required. Accepting the target covers every alias,
while the take retains the chosen route and all equivalent component locators.

Stop names, footage, expected frequency, and acoustic similarity are never
proof of physical identity. When compatible names and octave pitches suggest an
unmodeled overlap, OrgRec reports a review candidate and keeps all routes
independent. A reviewer may create a reversible assertion tied to the frozen
Navigator SHA-256 before recording begins. Once takes exist, grouping changes
are locked so take and coverage identities cannot be silently rewritten.

Compound stops are conservative: partial pipe-set overlap does not make two
captures equivalent. The complete confirmed emitter sets must match.

Documented tuning pitch (for example A4=442 Hz) is applied to all generated
frequency expectations, and the temperament label is retained as paradata. If
no tuning pitch exists in the specification, the roadmap visibly flags its
A4=440 Hz assumption.

If a compass is absent, the compiler assumes C2–C7 for a manual and C2–G4 for a
pedal division. Every such assumption is counted and shown in the roadmap; it
must be confirmed before fieldwork.

## Couplers, tremulants, and accessories

Couplers and accessories do not sound independently. For each documented
control, OrgRec creates a comparison registration with a relevant base stop and
low, middle, and high representative keys. The roadmap tells the operator which
stop and control to activate. These takes document audible transformation while
the corresponding isolated-stop recordings provide the baseline.

Controls without any speaking stop cannot generate an audio task and remain in
the retained organ-component inventory.

## Hypothetical combinations

An organ with `n` binary stops, couplers, and accessories has `2ⁿ−1` non-empty
switch states before considering keys, chords, expression positions, wind
states, or microphone techniques. Even 60 switches imply more than one
quintillion states. Claiming to pre-record that power set would be misleading.

OrgRec provides both honest completeness layers:

- exhaustive physical-target coverage with every stop/key route retained, plus
  explicit control-effect comparisons; and
- an unrestricted custom registration planner where the user selects any set of
  MODAVIS-linked stops, couplers, and accessories, a MIDI range, and chromatic
  step. Those tasks are appended to the roadmap with a frozen
  `RegistrationState`.

For a selected subset of up to ten switches, the planner can generate every
sound-producing subset automatically. It excludes states containing controls
but no speaking stop and previews the exact registration and capture counts.
Generation is capped at 50,000 capture tasks to keep a field project operable;
any larger individual combination can still be added in normal mode.

The roadmap header reports logical address count, physical target count, shared
alias count, unresolved overlap candidates, theoretical switch-state count,
control inventory, and assumptions. Custom registration coverage is explicitly
distinguished from isolated-stop and control-effect coverage.

## Field navigation

The macOS roadmap does not present the compiled capture matrix as one flat
table. It progressively discloses the hierarchy already present in MODAVIS:

1. the sound navigator groups work by division;
2. each division contains its speaking stops, controls, and custom
   registrations with local coverage;
3. selecting a sound opens an adaptive grid of its chromatic notes; and
4. each note card contains the configured microphone techniques and their
   individual recording states.

A physical target appears once in the recording queue. Its note card lists any
alternate stop/key routes as non-actionable shared aliases. Search includes
those aliases, but **Record next** and completeness operate only on the physical
capture obligations.

Division and sound groups are collapsible, previous/next sound controls support
sequential fieldwork, and **Record next** resolves the next outstanding task in
the current sound. Search can narrow the hierarchy by division, stop, note, or
technique, while the state filter isolates missing, review, or accepted work.
The MODAVIS source summary remains available on demand without consuming the
normal recording workspace.

## Current specification limits

Combination-setter pistons, reversible toe studs, expression shutters,
crescendo rollers, wind-pressure variants, historical stoplist states, and
mutually exclusive or mechanically impossible registrations require structured
constraints from Navigator. They can currently be documented as accessory
states or custom registrations, but OrgRec cannot infer their full state machine
from a label alone. The future dedicated roadmap API should provide activation
constraints, source/destination relations, compass overrides, continuous
control positions, and recommended musically representative registrations.
