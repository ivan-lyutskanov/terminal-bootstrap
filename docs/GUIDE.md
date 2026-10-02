# Guide

This is a keyboard-driven terminal workspace made of six small tools that already
compose well. **herdr** holds the panes and keeps them alive, **opencode** is the agent
running in them, **lazygit** does the staging and committing, **yazi** browses,
**micro** edits, and **atuin** remembers what you typed. There is no framework here —
the glue is a few environment variables in `shell/init.sh` and one small script. The
single most important piece of that glue is `$EDITOR`: yazi and lazygit both hand files
to it, so "open this" means the same thing everywhere. It defaults to micro, and defers
to an editor you have already set. What follows is what the pieces are actually for.

---

## Find, edit, stage, commit

Browse with yazi:

```bash
yazi
```

`↑` / `↓` move, `→` enters a directory and `←` goes back up, `.` toggles hidden files.
`Enter` opens the file — in micro, because that is what `$EDITOR` points at. Save with
`Ctrl+s`, quit with `Ctrl+q`, and you are back in yazi where you left off.

Then commit:

```bash
lazygit
```

`Space` stages or unstages the selected file. `Enter` on a file opens the staging view,
where `←` and `→` step between the changes and `Space` stages just the lines under the
cursor.
`c` opens lazygit's own commit panel; `C` writes the message in micro instead. `P` pushes.

One thing worth knowing: `[` and `]` switch tabs in lazygit, not the changes inside a
file — stepping between those is `←` / `→` in the staging view.

---

## Recall a command in this repo

Press **Up Arrow**. atuin answers with history from the current directory only, because
`bootstrap.sh` writes `filter_mode_shell_up_key_binding = "directory"` into
`~/.config/atuin/config.toml` — but only if you do not already have that file. An
existing atuin config is left untouched — the installer prints the line to add when it
skips, and until you add it Up Arrow stays global. In a project you have not touched for a month, the last few
things you ran there are then the first few results.

Press **`Ctrl+r`** for the same search across everything, unscoped.

In either, `↑` and `↓` move through results, `Enter` runs the selection, `Tab` puts it
on the prompt so you can edit it first, and `Esc` cancels — as does `↓` past the newest
result, which drops you back on an untouched prompt.

---

## Keep the workspace alive

```bash
herdr
```

launches the persistent session, or attaches to it if it is already running. The session
is a server that outlives your terminal, so closing the window or dropping an SSH
connection leaves everything exactly as it was — run `herdr` again and you are back in
it. `Ctrl+b` then `q` detaches on purpose.

`Ctrl+b` then `v` splits the pane you are in; `Ctrl+b` then an arrow key moves focus
between panes. herdr itself binds only `h` / `j` / `k` / `l` there; the arrows are added
beside them by this repo, and both stay live. Splits are also scriptable, which is how
you put a new command in a pane you choose rather than the focused one:

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

### herdr

A terminal workspace manager for AI coding agents. Panes, tabs and workspaces backed by a
server that keeps running after you disconnect, with agent state surfaced in the pane
chrome so you can see which agent is working and which is waiting on you.

Everything is prefixed with `Ctrl+b`: then `v` to split · an arrow key to move focus ·
`x` to close a pane · `z` to zoom one to full screen · `q` to detach.

The arrows are this repo's addition, written into `~/.config/herdr/config.toml`. herdr's
own default is `h` / `j` / `k` / `l`, and that keeps working — both are bound.

Docs: <https://herdr.dev>. Press `Ctrl+b` then `?` in the app for the full keymap, and
`herdr --help` for the CLI.

### micro

A terminal text editor with the shortcuts you already know from every GUI editor, so
there is no modal learning curve in the middle of a workflow. Set here as the default
`$EDITOR` and `$VISUAL`, which is what makes yazi and lazygit both open the same thing.
If you already have an editor of your own, that is what stays set and both follow it
instead.

`Ctrl+s` save · `Ctrl+q` quit · `Ctrl+f` find · `Ctrl+z` / `Ctrl+y` undo / redo ·
`Ctrl+e` opens the command bar (`goto 42` to jump to a line).

Docs: <https://micro-editor.github.io/>. Press `Ctrl+g` in the editor for the built-in
help.

### yazi

A fast file manager with previews for images, PDFs and archives. Its job in this bundle
is finding the file — once you press `Enter`, micro takes over.

`↑` / `↓` move · `←` / `→` up / into a directory · `Enter` open · `Space` select ·
`.` toggle hidden files · `q` quit.

`/` finds within the current directory and `n` steps through the matches; `f` filters
the listing down to what matched. `s` searches by name across subdirectories and `S`
searches their contents — those two shell out to `fd` and `ripgrep`, which is why
both are in the Brewfile. `Ctrl+s` cancels a search that is still running.

Docs: <https://github.com/sxyazi/yazi>. Press `~` or `F1` in the TUI for the full keymap.

### lazygit

A git TUI, and the only tool in this bundle that stages anything. Everything you change
ends up here as staged changes and a commit message.

`Space` stage / unstage · `Enter` open the staging view (`←` / `→` between changes) ·
`c` commit · `A` amend · `P` push · `p` pull.

Docs: <https://github.com/jesseduffield/lazygit>. Press `?` in the TUI for the keybinding
menu of whichever panel you are in.

### atuin

A SQLite-backed replacement for shell history that records the directory, exit code and
duration of every command. This repo configures the up-arrow binding to filter by
directory, which is the whole reason it is in the bundle.

`Up Arrow` search this directory · `Ctrl+r` search everywhere · `↑` / `↓` move ·
`Enter` run · `Tab` edit before running · `Esc` cancel.

Docs: <https://docs.atuin.sh>. `atuin --help` lists the CLI, and
`atuin default-config` prints every setting with its accepted values.

### opencode

A terminal-native AI coding agent. `bootstrap.sh` writes it a herdr skill,
version-matched to the installed herdr, and registers it with herdr so its agent state
shows in the pane chrome.

```bash
opencode
```

Docs: <https://opencode.ai/docs>. `opencode --help` lists the subcommands.
