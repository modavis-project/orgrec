# OrgRec visual system

OrgRec uses a restrained Japanese-inspired visual language built for long field
sessions. It borrows the principles of *ma* (useful space), *shibui* (quiet,
functional beauty), and seal-mark hierarchy without imitating decorative motifs.
The result is calm, information-dense, and legible in a church loft or control
room.

## Four-color palette

Only four semantic colors are used. Opacity and adaptive light/dark values create
shades; feature views must not introduce additional chromatic accents.

| Token | Light | Dark | Role |
| --- | --- | --- | --- |
| Washi | `#F5F1E8` | `#181815` | Canvas and inverse marks |
| Sumi | `#252521` | `#ECE8DE` | Text, structure, plots |
| Shu-iro | `#B94732` | `#E06A51` | Primary action, recording, warning |
| Ai-iro | `#365D68` | `#78A7B2` | Selection, progress, information, accepted state |

Raised and recessed surfaces are neutral tonal variants of washi and sumi. Thin
sumi rules replace shadows wherever possible.

## Composition

- Preserve generous negative space around screen titles and primary actions.
- Use flat surfaces, one-pixel rules, and restrained 5–7 point corner radii.
- Reserve shu-iro for deliberate action or attention. Do not use it simply to
  decorate selected content; selection and navigation use ai-iro.
- Charts and spectrograms remain within sumi, ai-iro, and shu-iro. Do not use
  rainbow scales because they invent visual boundaries in continuous acoustic
  data.
- Communicate state with an icon and text in addition to color.

## Typography

- Serif system type gives screen and section titles an editorial, archival tone.
- Sans-serif system type remains the primary interface face for fast scanning.
- Monospaced digits are used for time, pitch, levels, hashes, and identifiers.
- Small uppercase eyebrows identify provenance or database context, not ordinary
  hierarchy.

## Interaction hierarchy

1. Shu-iro filled controls are the single primary action in a region.
2. Bordered controls are secondary operations.
3. Plain controls are navigation or low-risk utility actions.
4. Ai-iro identifies the current destination, selected row, progress, and
   informational success.
5. Warnings and recording activity use shu-iro, always paired with a label or
   symbol.

## Implementation

The canonical tokens and reusable modifiers live in
`Sources/OrgRecApp/DesignSystem.swift`. All color decisions should reference
`OrgRecTheme` so light and dark appearances remain consistent.
