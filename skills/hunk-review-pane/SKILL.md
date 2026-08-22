---
name: hunk-review-pane
description: Use when the user asks to review changes side by side, or after finishing a change the user should look at. Opens hunk in a herdr pane beside you and reads the user's inline notes back.
---

# Side-by-side review with hunk in a herdr pane

Opens the current diff in a hunk TUI beside your pane, then reads the notes the user
leaves on individual hunks.

## Open the review

    hunk-review-pane

Prints `pane_id=<id>` and `repo=<path>`. Do not run `hunk diff` yourself — the script
places the TUI in a pane the *user* owns, which is the arrangement the rest of this
workflow assumes.

## Read the user's notes

The user attaches a note by selecting a hunk and pressing `c` in the TUI.

    hunk session comment list --repo . --type user --json

Returns `{"comments":[...]}` where each entry carries `noteId`, `source`, `filePath`,
`hunkIndex`, `newRange` and `body`.

Poll `--type user`, not `--type all` — `all` returns your own comments back to you.

## Respond

- Edit the code to address the note.
- Reply inline so the user sees it in the TUI:
  `hunk session comment add --repo . --file <filePath> --new-line <n> --summary "<what you did>"`
- Refresh the pane: `hunk session reload --repo . -- diff`
- Walk the user forward: `hunk session navigate --repo . --next-comment`

Remove only your own comments, with `hunk session comment rm --repo . <commentId>`,
using the id `comment add` printed. The user's notes are theirs to clear — never
resolve them on their behalf.

## Everything else

hunk ships its own generated skill covering the full session protocol, and it is
authoritative. Read it at the path printed by `hunk skill path` before using any
`hunk session` subcommand not listed above.
