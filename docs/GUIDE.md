# Guide

This is a keyboard-driven terminal workspace made of seven small tools that already
compose well. **herdr** holds the panes and keeps them alive, **hunk** shows a diff you
can annotate, **opencode** is the agent that reads those annotations, **lazygit** does
the staging and committing, **yazi** browses, **micro** edits, and **atuin** remembers
what you typed. There is no framework here — the glue is a few environment variables in
`shell/init.sh` and one small script. The single most important line of that glue is
`EDITOR=micro`: yazi, lazygit and hunk all hand files to `$EDITOR`, so "open this" means
the same thing everywhere. What follows is what the pieces are actually for.

---

## Review a change with your agent

This is the workflow the bundle exists for.

You are inside a herdr session with an agent running in one pane, and it has just
finished a change. Rather than read the diff scrolling past in the agent's transcript,
have it open a review:

```bash
hunk-review-pane
```

That splits a pane to the right of the agent's own pane, runs `hunk diff` in it, and
waits until hunk has registered a live session. It prints the pane it created and the
repository it is reviewing:

```
pane_id=w1:pQ
repo=/Users/you/Projects/example
```

The diff is now in a pane **you** own, next to the agent. Walk it:

| Key | Action |
|-----|--------|
| `]` / `[` | Next / previous hunk |
| `c` | Leave a note on the selected hunk |
| `e` | Open the selected file in `$EDITOR` |
| `r` | Refresh the review |
| `q` | Quit |

Leave a note on each hunk you want changed, then tell the agent to go address them. It
reads your notes back with:

```bash
hunk session comment list --repo . --type user --json
```

Each note carries the file, the hunk index, your text, and the line it is attached to.
The agent edits the code, replies inline so its answer appears next to your note in the
same pane, and reloads the view. Its own generated skill covers that protocol; the skill
this repo installs alongside it, `skills/hunk-review-pane/SKILL.md`, covers reading your
notes and the rule that it must never resolve them on your behalf.

`hunk-review-pane` needs herdr: it reads `HERDR_PANE_ID` to know which pane it was
called from, and refuses outside a session. It also refuses if a hunk session is already
live for the repository, since a second one makes every `--repo` selector ambiguous. To
see what is live:

```bash
hunk session list
```

hunk never stages anything. It is a viewer you can write on. Staging is lazygit's job.

---

## Find, edit, stage, commit

Browse with yazi:

```bash
yazi
```

`j` / `k` move, `l` enters a directory and `h` goes back up, `.` toggles hidden files.
`Enter` opens the file — in micro, because `$EDITOR` is set. Save with `Ctrl+s`, quit
with `Ctrl+q`, and you are back in yazi where you left off.

Then commit:

```bash
lazygit
```

`Space` stages or unstages the selected file. `Enter` on a file opens the staging view,
where `←` and `→` step between hunks and `Space` stages just the lines under the cursor.
`c` opens lazygit's own commit panel; `C` writes the message in micro instead. `P` pushes.

One thing worth knowing: `[` and `]` switch tabs in lazygit. They do not move between
changes, which is what the equivalent keys do in hunk.

---

## Recall a command in this repo

Press **Up Arrow**. atuin answers with history from the current directory only, because
`bootstrap.sh` writes `filter_mode_shell_up_key_binding = "directory"` into
`~/.config/atuin/config.toml` — but only if you do not already have that file. An
existing atuin config is left untouched — the installer prints the line to add when it
skips, and until you add it Up Arrow stays global. In a project you have not touched for a month, the last few
things you ran there are then the first few results.

Press **`Ctrl+r`** for the same search across everything, unscoped.

In either, `Ctrl+j` and `Ctrl+k` move through results, `Enter` runs the selection, `Tab`
puts it on the prompt so you can edit it first, and `Esc` cancels.

---

## Keep the workspace alive

```bash
herdr
```

launches the persistent session, or attaches to it if it is already running. The session
is a server that outlives your terminal, so closing the window or dropping an SSH
connection leaves everything exactly as it was — run `herdr` again and you are back in
it. `Ctrl+b` then `q` detaches on purpose.

`Ctrl+b` then `v` splits the pane you are in; `Ctrl+b` then `h` / `j` / `k` / `l` moves
focus between panes. Splits are also scriptable, which is how `hunk-review-pane` puts
the diff where it does:

```bash
herdr pane split --pane "$HERDR_PANE_ID" --direction right --ratio 0.5 --cwd "$PWD" --no-focus
```

`--pane "$HERDR_PANE_ID"` is the load-bearing part: it splits off the pane the command is
running in, rather than whichever pane happens to be focused — which is not the same pane
when an agent is working in the background.

Named sessions keep separate workspaces apart:

```bash
herdr --session work
herdr session list
```

---

## Tool reference

What each tool is for, the keys the workflows above need, and where the rest lives.

### hunk

A review-first diff viewer for agent-authored changesets. It renders a diff and lets you
attach notes to individual hunks that an agent can read through a local daemon; it does
not stage, and it is not a replacement for `git add -p`.

```bash
hunk diff             # working tree
hunk diff --staged    # staged changes
hunk session list     # what is currently live
```

`]` / `[` next / previous hunk · `c` leave a note · `e` open the file in `$EDITOR` ·
`r` refresh · `q` quit.

Docs: <https://hunk.dev/docs>. Press `?` in the TUI for the full keymap.

### hunk-review-pane

This repository's own command, installed to `~/.local/bin`. It is the two tools wired
together: split a pane off the caller's own pane, start `hunk diff` in it, and confirm
hunk registered a session before returning, so an agent can drive the review immediately.

It takes one optional argument, the split ratio, defaulting to `0.5`. The script is
`bin/hunk-review-pane` in this repository and the agent-facing skill is
`skills/hunk-review-pane/SKILL.md`.

### herdr

A terminal workspace manager for AI coding agents. Panes, tabs and workspaces backed by a
server that keeps running after you disconnect, with agent state surfaced in the pane
chrome so you can see which agent is working and which is waiting on you.

Everything is prefixed with `Ctrl+b`: then `v` to split · `h` / `j` / `k` / `l` to move
focus · `x` to close a pane · `z` to zoom one to full screen · `q` to detach.

Docs: <https://herdr.dev>. Press `Ctrl+b` then `?` in the app for the full keymap, and
`herdr --help` for the CLI.

### micro

A terminal text editor with the shortcuts you already know from every GUI editor, so
there is no modal learning curve in the middle of a workflow. Set here as `$EDITOR` and
`$VISUAL` and aliased to `vim`, which is what makes yazi, lazygit and hunk all open the
same thing.

`Ctrl+s` save · `Ctrl+q` quit · `Ctrl+f` find · `Ctrl+z` / `Ctrl+y` undo / redo ·
`Ctrl+e` opens the command bar (`goto 42` to jump to a line).

Docs: <https://micro-editor.github.io/>. Press `Ctrl+g` in the editor for the built-in
help.

### yazi

A fast file manager with previews for images, PDFs and archives. Its job in this bundle
is finding the file — once you press `Enter`, micro takes over.

`j` / `k` move · `h` / `l` up / into a directory · `Enter` open · `Space` select ·
`.` toggle hidden files · `q` quit.

Docs: <https://github.com/sxyazi/yazi>. Press `~` or `F1` in the TUI for the full keymap.

### lazygit

A git TUI, and the only tool in this bundle that stages anything. Everything the review
loop decides ends up here as staged hunks and a commit message.

`Space` stage / unstage · `Enter` open the staging view (`←` / `→` between changes) ·
`c` commit · `A` amend · `P` push · `p` pull.

Docs: <https://github.com/jesseduffield/lazygit>. Press `?` in the TUI for the keybinding
menu of whichever panel you are in.

### atuin

A SQLite-backed replacement for shell history that records the directory, exit code and
duration of every command. This repo configures the up-arrow binding to filter by
directory, which is the whole reason it is in the bundle.

`Up Arrow` search this directory · `Ctrl+r` search everywhere · `Ctrl+j` / `Ctrl+k` move
· `Enter` run · `Tab` edit before running · `Esc` cancel.

Docs: <https://docs.atuin.sh>. `atuin --help` lists the CLI, and
`atuin default-config` prints every setting with its accepted values.

### opencode

A terminal-native AI coding agent, and the intended occupant of the pane next to your
review. `bootstrap.sh` gives it the `hunk-review-pane` skill plus hunk's own generated
one, and registers it with herdr so its state shows in the pane chrome.

```bash
opencode
```

Docs: <https://opencode.ai/docs>. `opencode --help` lists the subcommands.
