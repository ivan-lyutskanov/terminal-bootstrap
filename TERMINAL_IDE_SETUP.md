# Terminal IDE Setup for macOS & Linux

A complete guide for building a VS Code-like experience in the terminal using micro, yazi, lazygit, hunk, atuin, herdr, and opencode.

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
| **micro** | Modern terminal text editor with syntax highlighting, built-in plugin system, and intuitive keybindings | Code editor |
| **yazi** | Blazing-fast file manager with fuzzy search, builtin preview (images, PDF, archives), and vim-like keybinding | File explorer |
| **lazygit** | Beautiful TUI for Git — stage files, view diffs, commit, push — all with keyboard or mouse | Source Control tab |
| **hunk** | Interactive diff & patch tool — review granular code changes, stage hunks interactively | Inline diff viewer |
| **atuin** | Magical shell history — directory-scoped search with Up Arrow | Searchable history |
| **herdr** | Workspace orchestrator — manages sessions, views docs, runs workflows, coordinates tools | Workspace & session management |
| **opencode** | AI coding agent built for the terminal | AI assistant / Copilot |

**Why this combo?** All tools are:
- Lightweight and blazing fast
- Actively maintained
- Designed to interoperate (yazi opens files in your $EDITOR, hunk stages hunks, herdr orchestrates your workflow)

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

## Part 2: Browse Files — yazi

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

## Part 3: Git Management — lazygit

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

1. Run `lazygit` in a terminal tab or via herdr's workflow orchestration
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

## Part 4: Interactive Diffs — hunk

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

## Part 5: Smart Shell History — atuin

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

## Part 6: AI Coding Agent — opencode

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

## Part 7: Workspace Orchestrator — herdr

herdr is a Markdown TUI reader and workflow orchestrator — it manages your workspace sessions, displays documentation, and coordinates your terminal tools into a unified workflow.

### Installation

```bash
brew install herdr
```

### Why herdr?

- **Workspace orchestration** — Manages sessions and coordinates your tools (editor, git, file manager) into a unified workflow
- **Markdown rendering** — Beautiful terminal-native MD viewer for docs, cheatsheets, and onboarding guides
- **Workflow orchestration** — Run commands, follow steps, track progress
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

## Part 8: Putting It All Together — The Workflow

herdr acts as the central orchestrator for your terminal IDE. It manages your workflow by coordinating the tools you need, when you need them — no manual pane management required.

### The herdr-Centric Workflow

```
┌─────────────────────────────────────────────┐
│                  herdr                       │
│         (workspace orchestrator)             │
│                                              │
│  • Browse & open files → yazi → micro       │
│  • Review changes → hunk                    │
│  • Stage & commit → lazygit                 │
│  • AI assistance → opencode                 │
│  • Recall commands → atuin                  │
│  • View docs & guides → herdr (self)        │
└─────────────────────────────────────────────┘
```

### How It Works

1. **Start herdr** — `herdr` launches the workspace orchestrator
2. **Navigate files** — herdr invokes **yazi** to browse your project; press Enter on a file to open it in **micro**
3. **Edit & save** — Make changes in micro, save with `Ctrl+s`, return to herdr
4. **Review changes** — herdr launches **hunk** to review granular diffs before committing
5. **Stage & commit** — herdr invokes **lazygit** for visual staging, committing, and pushing
6. **AI assistance** — Need help? herdr coordinates with **opencode** for AI-powered coding assistance
7. **Recall commands** — **Atuin** provides directory-scoped history so you can quickly recall previous commands for this project

### Usage Flow

1. Launch `herdr` in your project directory
2. Browse files → open in micro → edit → save
3. Review changes with hunk to ensure correctness
4. Stage and commit via lazygit
5. Push when ready
6. Use Atuin (Up Arrow) to recall commands from this project's history

### Why herdr as the Orchestrator?

- **Purpose-built** — herdr understands your dev workflow, not just terminal windows
- **Tool coordination** — Launches the right tool at the right time instead of static panes
- **Workflow tracking** — Follow guided steps, check off tasks, track progress
- **Less cognitive load** — No need to remember pane layouts or keybindings for window management
- **Documentation-native** — Your setup guides, cheatsheets, and onboarding docs live inside herdr

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
brew install micro yazi lazygit atuin herdr hunk opencode node
```

### Windows (WSL2 recommended)

> *"Set up a terminal IDE environment on Windows via WSL2 equivalent to the macOS setup with micro, yazi, lazygit, hunk, atuin, herdr, and opencode. Provide:*
> 1. *WSL2 Ubuntu install steps*
> 2. *Package manager install commands (apt)*
> 3. *Windows Terminal configuration recommendations*
> 4. *Configuration file contents for micro*
> 5. *Suggested herdr-based workflow for productive development*
> 6. *How to access WSL2 files from Windows and vice versa"*

---

*Maintained by Ivan Lyutskanov*
*See: https://github.com/ivan-lyutskanov/terminal-bootstrap*
