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
workflow assumes. It refuses if a session is already live for this repo; drive that
one instead.

## Read the user's notes

The user attaches a note by selecting a hunk and pressing `c` in the TUI.

    hunk session comment list --repo . --type user --json

Returns `{"comments":[...]}` where each entry carries `noteId`, `source`, `filePath`,
`hunkIndex`, `body`, `author`, `createdAt`, `editable`, and a range: `newRange` for a
note on an added line, `oldRange` for one on a deleted line. Unset fields are omitted,
so read whichever range is present.

Poll `--type user`, not `--type all` — `all` returns your own comments back to you.
The user's notes are the ones with `editable: true`; yours come back `editable: false`.

## Respond

- Edit the code to address the note.
- Reply inline so the user sees it in the TUI, on the same side as the note they left:
  `--new-line <n>` for a `newRange` note, `--old-line <n>` for an `oldRange` one.
  `hunk session comment add --repo . --file <filePath> --new-line <n> --summary "<what you did>"`
- Refresh the pane: `hunk session reload --repo . -- diff`
- Walk the user forward: `hunk session navigate --repo . --next-comment`

Remove only your own comments, with `hunk session comment rm --repo . <commentId>`,
using the id `comment add` printed. `rm` will delete a user note too if you hand it
one — the user's notes are theirs to clear, so never resolve them on their behalf.

## Everything else

hunk ships its own generated skill covering the full session protocol, and it is
authoritative. Read it at the path printed by `hunk skill path` before using any
`hunk session` subcommand not listed above.
