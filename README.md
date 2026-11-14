# Terminal Environment Bootstrap

A terminal-native, keyboard-driven development workstation for macOS and Linux. Six
tools, installed and wired together so that browsing, editing, staging and committing
is one workflow rather than four programs, with directory-scoped history and persistent
agent panes to carry it.

**[Read the guide](docs/GUIDE.md)** for the three workflows this exists to support.

## 🛠️ What Gets Installed & Configured

| Tool | What it is | What this repo does with it |
| :--- | :--- | :--- |
| **[micro](https://micro-editor.github.io/)** | Terminal text editor with the `Ctrl` shortcuts you already know | Set as the default `$EDITOR` and `$VISUAL`, this is the glue — an editor you already set is left alone |
| **[yazi](https://github.com/sxyazi/yazi)** | Fast TUI file manager | `Enter` on a file hands it to `$EDITOR` |
| **[lazygit](https://github.com/jesseduffield/lazygit)** | Git TUI, and the only tool here that stages anything | `e` opens the file in `$EDITOR`; `C` writes the commit message there |
| **[atuin](https://docs.atuin.sh)** | SQLite-backed shell history | Up Arrow scoped to the current directory via `filter_mode_shell_up_key_binding` |
| **[herdr](https://herdr.dev)** | Terminal workspace manager for AI coding agents | Registered to report opencode's agent state in the pane UI; pane focus on `Ctrl+b` + arrow keys as well as `hjkl` |
| **[opencode](https://github.com/anomalyco/opencode)** | Terminal AI coding agent | Given a herdr skill, version-matched to the installed herdr, so it can drive the panes and workspaces around it |

---

## 🚀 Quick Start

```bash
git clone --depth 1 https://github.com/ivan-lyutskanov/terminal-bootstrap.git ~/.terminal-bootstrap
~/.terminal-bootstrap/bootstrap.sh
```

The clone is the install location — configuration is sourced from it, so updating is
`git -C ~/.terminal-bootstrap pull` and uninstalling is removing the
`# terminal-bootstrap` block from your `~/.zshrc`. Any clone path works;
`~/.terminal-bootstrap` is just the convention.

---

## ⚙️ How It Works

1. **One sourced file.** All shell configuration lives in `shell/init.sh` inside the
   clone. `bootstrap.sh` writes a single guarded `source` line into a
   `# terminal-bootstrap` block in your `~/.zshrc` (or `~/.bash_profile` on macOS bash,
   `~/.bashrc` elsewhere). Later runs find that block by its marker, so moving the clone
   and re-running repoints the block you already have rather than leaving a second one
   behind it. Updating is `git pull`; uninstalling is deleting the block.
2. **Tools from a Brewfile, installed one at a time.** The tool list is the `Brewfile`,
   but each formula is installed in its own `brew install` so that one unavailable
   package cannot abort the rest of setup. Anything that fails is reported at the end
   and retried on the next run.
3. **Directory-scoped history.** `~/.config/atuin/config.toml` gets
   `filter_mode_shell_up_key_binding = "directory"`, so Up Arrow searches only what you
   ran here while `Ctrl+r` still searches everything. This is only written when you do
   not already have that file — an existing atuin config is never overwritten. When it
   skips, the installer says so at the end, with the line to add yourself. atuin's own
   init keeps its keymaps; nothing is rebound by hand.
4. **Arrow keys for herdr panes.** `~/.config/herdr/config.toml` gets `Ctrl+b` + an
   arrow key for pane focus, added *alongside* herdr's own `h` / `j` / `k` / `l` rather
   than in place of it — each action is bound to a list of two keys. Nothing is
   displaced: no herdr default binds an arrow behind the prefix. The block is only
   appended to a config with no `[keys]` table of its own, and only after herdr itself
   validates the result; otherwise the file is left untouched and the lines to add are
   printed at the end.
5. **A herdr skill for opencode, version-matched.** `~/.config/opencode/skills/herdr/SKILL.md`
   is written as a managed file fetched from the tag matching the installed herdr, so
   the skill and the binary can never drift; re-running after a herdr upgrade re-fetches
   and converges. herdr must be at least 0.8.0 for the skill to exist, so the installer
   upgrades herdr in place to reach that floor (a floor, not a pin) and reports it at
   the end; if it cannot reach it, the skill is skipped and reported. The opencode
   integration is reinstalled after any upgrade, as herdr requires.

---

## 🔑 Post-Installation: Keychain Setup for AI Tokens

To keep your API keys secure without hardcoding them in your shell:

### macOS

Store the key. Omitting the value after `-w` makes `security` prompt for it, so the
secret never lands in argv — and therefore never in your atuin history:

```bash
security add-generic-password -a "$USER" -s ANTHROPIC_API_KEY -w
```

Read it back in your shell:

```bash
echo 'export ANTHROPIC_API_KEY=$(security find-generic-password -a "$USER" -s ANTHROPIC_API_KEY -w)' >> ~/.zshrc
```

Swap `ANTHROPIC_API_KEY` for `OPENAI_API_KEY` or `GOOGLE_API_KEY` as needed.

### Linux (`libsecret` / `secret-tool`)

`secret-tool store` always prompts for the value — it never takes it as an argument:

```bash
secret-tool store --label="Anthropic Key" service anthropic username "$USER"
echo 'export ANTHROPIC_API_KEY=$(secret-tool lookup service anthropic username "$USER")' >> ~/.zshrc
```

Note: this blocks on a locked keyring. On a headless or SSH session with no keyring
daemon, set the variable another way rather than putting the lookup in your shell rc.

Swap `anthropic` for `openai` or `google` in the `service` value of both commands, and `ANTHROPIC_API_KEY` for the matching variable name, as needed.
