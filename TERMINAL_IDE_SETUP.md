# Terminal IDE Setup for macOS & Linux

A complete guide for building a VS Code-like experience in the terminal using tmux, micro, yazi, lazygit, hunk, atuin, and herdr.

---

## Why This Setup?

Traditional IDEs like VS Code are powerful but resource-heavy. This setup gives you a lightning-fast, customizable terminal-based IDE that:

- Uses minimal RAM (perfect for older machines or resource-constrained environment)
- Keeps you in the terminal for your entire workflow
- Provides a consistent experience across macOS and Linux
- Gives you deep control over your tooling

Each tool here is designed to work together seamlessly.

---

## The Tools Explained

Before we install anything, here's what each tool does and why you'd want it:

| Tool | Purpose | VS Code Equivalent |
|------|---------|-------------------|
| **tmux** | Terminal multiplexer — manages multiple terminal sessions, splits windows into pane, and detaches/reattaches remotely | Window/workspace management |
| **micro** | Modern terminal text editor with syntax highlighting, built-in plugin system, and intuitive keybindings | Code editor |
| **yazi** | Blazing-fast file manager with fuzzy search, builtin preview (images, PDF, archives), and vim-like keybinding | File explorer |
| **lazygit** | Beautiful TUI for Git — stage files, view diffs, commit, push — all with keyboard or mouse | Source Control tab |
| **hunk** | Interactive diff & patch tool — review granular code changes, stage hunks interactively | Inline diff viewer |
| **atuin** | Magical shell history — directory-scoped search with Up Arrow | Searchable history |
| **herdr** | Markdown TUI reader & workflow orchestrator — view docs, cheatsheets, onboarding guides | Documentation viewer |

**Why this combo?** All tools are:
- Lightweight and blazing fast
- Actively maintained
- Designed to interoperate (yazi opens files in your $EDITOR, hunk stages hunks, herdr displays guides)

---

## Part 0: Homebrew — The Package Manager

All tools are installed via [Homebrew](https://brew.sh/), which works on both macOS and Linux (including Apple Silicon). If you don't have it yet:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Important: PATH after fresh install

On a fresh machine, the Homebrew installer does **not** add `brew` to your running shell's PATH. After the install completes, you must evaluate the shellenv manually:

**Apple Silicon Mac:**
```bash
eval "$(/opt/homebrew/bin/brew shellenv)"
```

**Intel Mac:**
```bash
eval "$(/usr/local/bin/brew shellenv)"
```

**Linux (Linuxbrew):**
```bash
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```

To make this permanent, add the matching `eval` line to your `~/.zshrc` (or `~/.bashrc`):

```bash
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc   # Apple Silicon
```

> The `bootstrap.sh` script handles all of this automatically — the PATH is detected, eval'd for the current shell, and persisted to your shell RC file.

---

## Part 1: Install the Editor First — micro

We need an editor before anything else. Micro is a modern, terminal-based editor that's easier to learn than vim but more powerful than nano.

### Installation

```bash
brew install micro
```

### Why micro?

- **Syntax highlighting** — Comes built-in for 50+ languages
- **Intuitive** — If you know Ctrl+C/V/S, you're mostly good
- **Plugin system** — Add filemanager, git, etc. easily
- **Cross-platform** — Works identically on macOS, Linux, Windows

### Basic Usage

| Action | Key |
|--------|-----|
| Open file | `micro filename.ext` |
| Copy | `Ctrl+c` |
| Paste | `Ctrl+v` |
| Save | `Ctrl+s` |
| Quit | `Ctrl+q` |
| Find | `Ctrl+f` |

---

## Part 2: Organize with Sessions — tmux

Now let's install tmux. This is the "glue" that holds your workspace together — it lets you create multiple terminal windows, split them into pane, and detach/reattach from anywhere.

### Installation

```bash
brew install tmux
```

### Why tmux?

- **Split pane** — View multiple things simultaneously (editor + file browser + git)
- **Persist sessions** — Detach and reattach from SSH or after a reboot
- **Session multiplexing** — Run multiple projects in separate sessions
- **Highly configurable** — Your setup, your rules

### Configure tmux

Create or edit your tmux config:

```bash
nano ~/.tmux.conf
```

Paste this starter configuration:

```bash
# --- Core Settings ---
set -g mouse on
setw -g mode-keys vi

# --- Copy Mode Bindings (Space / Enter) ---
# Start selection with Space
bind -T copy-mode-vi Space send -X begin-selection
# Copy to Mac System Clipboard with Enter (macOS)
bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "pbcopy"
# Copy to clipboard on Linux (replace with xclip or wl-copy)
# bind -T copy-mode-vi Enter send-keys -X copy-pipe-and-cancel "xclip -selection clipboard"

# --- Convenience Bindings ---
# Shortcut to reload config: Ctrl+b then r
bind r source-file ~/.tmux.conf \; display "Config Reloaded!"

# --- Plugin Manager (TPM) ---
# List of plugins
set -g @plugin 'tmux-plugin/tpm'
set -g @plugin 'tmux-plugin/tmux-yank'

# Initialize TPM (Keep this at the very bottom!)
run '~/.tmux/plugins/tpm/tpm'
```

### Install TPM (Tmux Plugin Manager)

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

### Apply Changes

Reload config (run this or press `Ctrl+b` then `r` inside tmux):

```bash
tmux source-file ~/.tmux.conf
```

Install plugin (inside tmux):

- Press `Ctrl+b` then `Shift+I`

Watch for the progress bar at the bottom. Done!

### Essential tmux Cheat Sheet

| Action | Command |
|--------|---------|
| Prefix key | `Ctrl+b` |
| New window | `Ctrl+b` then `c` |
| Next window | `Ctrl+b` then `n` |
| Previous window | `Ctrl+b` then `p` |
| Vertical split | `Ctrl+b` then `"` |
| Horizontal split | `Ctrl+b` then `%` |
| Switch pane | `Ctrl+b` then arrow |
| Enter copy mode | `Ctrl+b` then `[` |
| Start selection | `Space` |
| Copy to clipboard | `Enter` |
| Paste | `Ctrl+b` then `]` |
| Reload config | `Ctrl+b` then `r` |
| Detach session | `Ctrl+b` then `d` |
| Reattach | `tmux attach` |

---

## Part 3: Browse Files — yazi

Next up: yazi. This is your file explorer — a blazing-fast alternative to vim's netrw, nnn, or fzf.

### Installation

```bash
brew install yazi
```

### Why yazi?

- **Fast** — Written in Rust, benchmark-faster than fzf, nnn, etc.
- **Rich previews** — Preview image, PDF, zip, tar.gz, markdown, code files — all without opening
- **Fuzzy search** — Find file instantly
- **Vim-like binding** — Feels natural if you've used vim

### Configure: Open Files in micro Instead of Vim

By default, yazi uses `$EDITOR` which is probably vim. Let's change that.

Add to your `~/.zshrc` (or `~/.bashrc`):

```bash
export EDITOR=micro
export VISUAL=micro
```

Apply immediately:

```bash
source ~/.zshrc
```

Now pressing Enter on a file in yazi opens it in micro.

### yazi Key Commands

| Action | Key |
|--------|-----|
| Navigate | Arrow keys or `h/j/k/l` |
| Open file/directory | `Enter` |
| Go back | `h` or `<left>` |
| Go forward | `l` or `<right>` |
| Parent directory | `..` or `<space>..` |
| Select file | `space` |
| Toggle hidden files | `.` |
| Fuzzy search | `/` |
| Quit | `q` or `<esc>` |
| Open settings | `gc` |
| Help | `?` |

### Bonus: Preview Panel

yazi can preview files in a separate pane. Toggle preview with `Ctrl+p`. Best for:
- Image (shows actual image)
- PDF (first page render)
- Markdown (rendered preview)
- Code files (syntax highlighted)

---

## Part 4: Git Management — lazygit

Finally, lazygit. This is your visual Git interface — think of it as the Source Control panel from VS Code but more powerful.

### Installation

```bash
brew install lazygit
```

### Why lazygit?

- **Visual staging** — Stage hunks, not just files
- **Diff view** — See exactly what changed
- **Commit crafting** — Write commits with ease
- **Interactive rebase** — Squash, reorder, edit commits
- **Works with any editor** — Hooks into your $EDITOR for commit messages

### Basic Workflow

1. Run `lazygit` in its own tmux pane (more on layout below)
2. Navigate with arrow keys or mouse
3. Press `?` for help anytime

### Essential lazygit Keys

| Action | Key |
|--------|-----|
| Navigate | Arrow keys / mouse |
| Stage/unstage file | `space` |
| Stage/unstage hunk | `space` (in diff view) |
| Open commit message | `c` |
| Amend last commit | `A` |
| Push | `P` |
| Pull | `p` |
| Fetch | `f` |
| Refresh | `r` |
| Quit | `q` |

### Pro Tips

- **Partial staging** — In diff view, use `space` to stage just the selected hunk
- **Commit signing** — Set `GPG_SIGNING_KEY` in lazygit config to auto-sign commits
- **Custom commands** — Add frequently-used commands in lazygit's `customCommands`

---

## Part 5: Interactive Diffs — hunk

hunk is an interactive diff and patch tool that integrates with your workflow for granular change review.

### Installation

```bash
brew install hunk
```

### Why hunk?

- **Granular diff inspection** — Review changes hunk-by-hunk
- **Interactive staging** — Stage specific changes, not just files
- **Works with any editor** — Integrates with micro, vim, etc.
- **Terminal-native** — Full keyboard-driven experience

### Basic Usage

| Action | Command |
|--------|---------|
| Launch hunk TUI | `hunk` |
| View unstaged changes | `hunk` |
| View staged changes | `hunk --cached` |
| View diff for specific file | `hunk diff <filename>` |
| Create patch | `hunk patch <filename>` |

### Integration with lazygit

hunk pairs beautifully with lazygit:
1. In lazygit, press `]` to open external diff program
2. Configure hunk as your diff program in lazygit config

---

## Part 6: Smart Shell History — atuin

Atuin replaces your shell history with a magical, searchable SQLite-backed history that syncs across machines.

### Installation

```bash
brew install atuin
```

### Why atuin?

- **Directory-scoped search** — Up Arrow searches history only in current directory
- **Sync** — Share history across machines (optional)
- **Cloud backup** — Optional encrypted cloud sync
- **Better search** — Full-text search, not just prefix matching

### Configure Directory-Scoped History

The shell init command differs depending on your shell.

**For zsh** (add to `~/.zshrc`):

```bash
eval "$(atuin init zsh --disable-up-arrow)"
bindkey "^[[A" atuin-up-search-vicmd
bindkey "^[[A" atuin-up-search
```

**For bash** (add to `~/.bashrc`):

```bash
eval "$(atuin init bash)"
```

And configure the Atuin config (`~/.config/atuin/config.toml`):

```toml
search_mode = "prefix"
up_key_dir_scoped = true
style = "compact"
inline_height = 20
```

The key setting `up_key_dir_scoped = true` makes Up Arrow search only within the current directory's history.

> The `bootstrap.sh` script detects your shell automatically and writes the correct init command. It also only writes `config.toml` if it doesn't already exist, making re-runs safe.

### Essential atuin Keys

| Action | Key |
|--------|-----|
| Search history | `Ctrl+r` (global search) |
| Directory-scoped | `Up Arrow` (current dir only) |
| Accept selection | `Enter` |
| Quit search | `Esc` |

---

## Part 7: AI Coding Agent — opencode

opencode is an AI coding agent built for the terminal.

### Installation

```bash
brew install opencode
```

### Usage

```bash
opencode
```

---

## Part 8: Documentation Viewer — herdr

herdr is a Markdown TUI reader and workflow orchestrator—perfect for viewing documentation, cheatsheets, and onboarding guides.

### Installation

```bash
brew install herdr
```

### Why herdr?

- **Markdown rendering** — Beautiful terminal-native MD viewer
- **Workflow orchestration** — Run commands, follow steps
- **Keyboard-driven** — Fully accessible, no mouse needed
- **Cheatsheet mode** — Perfect for quick reference

### Usage

| Action | Command |
|--------|---------|
| Open markdown file | `herdr <filepath>` |
| Open with cheatsheet mode | `herdr --cheatsheet <filepath>` |
| Navigation | Arrow keys / vim bindings |
| Quit | `q` or `Esc` |
| Help | `?` |

### Example: View This Guide

```bash
herdr TERMINAL_IDE_SETUP.md
```

---

## Part 9: Putting It All Together — The Layout

Here's a productive tmux layout that mirrors a traditional IDE:

### The Setup

```
+-----------------+-----------------+
|            |              |
|   Claude   |    yazi      |
|    Code    |   (files)    |
|            |              |
|     AI     +--------------+
|    Agent   |              |
|     CLI    |   lazygit    |
|            |    (git)     |     
|            |              |
+------------+---------------+
```

### Step-by-Step

1. **Open tmux** (`tmux` or `tmux new` if not already)
2. **Create vertical split** — `Ctrl+b` then `"` (gives you left/right, 50/50)
3. **Create horizontal split in right pane** — `Ctrl+b` then `%`

Result:
- Left pane (~60%): Claude Code (or your terminal/editor)
- Right-top pane (~60%): yazi
- Right-bottom pane (~40%): lazygit

### Usage Flow

1. Navigate files in **yazi** (right-top)
2. Press **Enter** on a file → opens in **micro** (same pane)
3. Edit, save (`Ctrl+s`), switch back to yazi (`Ctrl+b` then arrow)
4. Meanwhile, check git status in **lazygit** (right-bottom)
5. Use **hunk** to review granular changes before staging
6. Use **Atuin** to recall commands from this project
7. Make changes → stage in lazygit → commit → push

### Customize the Layout

- **Resize pane:** `Ctrl+b` then `Alt+arrow`
- **Swap pane:** `Ctrl+b` then `{` or `}`
- **Zoom pane:** `Ctrl+b` then `z` (toggle full-screen)

---

## Platform-Specific Notes

### One-liner Bootstrap

The bootstrap script handles everything automatically — Homebrew installation, PATH setup, tool installation, and shell configuration:

```bash
curl -fsSL https://raw.githubusercontent.com/ivan-lyutskanov/terminal-bootstrap/master/bootstrap.sh | bash
```

The script detects your OS and shell, installs all tools via Homebrew (a single package manager for everything), and configures your shell RC file.

### Linux (Ubuntu/Debian)

If bootstrapping manually on Linux, install Homebrew first (Linuxbrew), then:

```bash
# All tools via Homebrew
brew install micro tmux yazi lazygit atuin herdr hunk opencode node
```

### Windows (WSL2 recommended)

> *"Set up a terminal IDE environment on Windows via WSL2 equivalent to the macOS setup with tmux, micro, yazi, lazygit, hunk, atuin, and herdr. Provide:*
> 1. *WSL2 Ubuntu install steps*
> 2. *Package manager install commands (apt)*
> 3. *Windows Terminal configuration recommendations*
> 4. *Configuration file contents for tmux and micro*
> 5. *Suggested tmux layout for a productive workflow*
> 6. *How to access WSL2 files from Windows and vice versa"*

---

*Maintained by Ivan Lyutskanov*
*See: https://github.com/ivan-lyutskanov/terminal-bootstrap*
