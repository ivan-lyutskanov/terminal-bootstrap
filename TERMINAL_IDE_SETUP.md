# Terminal IDE Cheatsheet

A lightweight, terminal-native IDE: **micro** (editor), **yazi** (files), **lazygit** (git), **hunk** (diffs), **atuin** (history), **opencode** (AI), and **herdr** (orchestrator). All installed via Homebrew — run `bootstrap.sh` once and you're set.

---

## micro — Text Editor

Modern terminal editor with syntax highlighting for 50+ languages. Intuitive Ctrl-based shortcuts (no vim learning curve). Set as your default `$EDITOR` so yazi and lazygit open files in it.

| Shortcut | Action |
|----------|--------|
| `Ctrl+s` | Save |
| `Ctrl+q` | Quit |
| `Ctrl+c` | Copy (selection) |
| `Ctrl+v` | Paste |
| `Ctrl+f` | Find |
| `Ctrl+z` | Undo |
| `Ctrl+y` | Redo |
| `Ctrl+g` | Go to line |
| `Ctrl+a` | Select all |
| `Ctrl+k` | Cut line |
| `Ctrl+d` | Duplicate line |
| `Alt+g` | Toggle line numbers |

---

## yazi — File Manager

Blazing-fast Rust-based file browser with image/PDF/archive previews, fuzzy search, and vim-like navigation. Press `Enter` on a file to open it in `$EDITOR` (micro).

| Shortcut | Action |
|----------|--------|
| `h` / `l` | Parent / enter directory |
| `j` / `k` | Navigate down / up |
| `Enter` | Open file or directory |
| `q` | Quit |
| `.` | Toggle hidden files |
| `/` | Fuzzy search |
| `Space` | Select file |
| `y` | Yank (copy) selection |
| `x` | Cut selection |
| `p` | Paste |
| `d` | Delete (trash) |
| `~` | Go to home |

---

## lazygit — Git TUI

Visual Git interface: stage hunks, craft commits, push/pull, interactive rebase — all keyboard-driven. Uses `$EDITOR` for commit messages.

| Shortcut | Action |
|----------|--------|
| `Space` | Stage / unstage file or hunk |
| `c` | Open commit message |
| `A` | Amend last commit |
| `P` | Push |
| `p` | Pull |
| `f` | Fetch |
| `r` | Refresh |
| `[` / `]` | Previous / next hunk in diff |
| `Enter` | View diff / enter panel |
| `?` | Help (all keybindings) |
| `q` | Quit |

---

## hunk — Interactive Diff & Patch

Granular diff reviewer: inspect changes hunk-by-hunk, stage selectively, generate patches. Pairs with lazygit for detailed code review before committing.

| Command | Action |
|---------|--------|
| `hunk` | Launch TUI (unstaged changes) |
| `hunk --cached` | View staged changes |
| `hunk diff <file>` | Diff for specific file |
| `hunk patch <file>` | Create patch from file |

---

## atuin — Shell History

SQLite-backed shell history with directory-scoped search. Up Arrow finds commands from the current directory only; Ctrl+R searches globally.

| Shortcut | Action |
|----------|--------|
| `Up Arrow` | Search history (current dir) |
| `Ctrl+r` | Search history (global) |
| `Enter` | Accept selection |
| `Esc` | Cancel search |
| `Ctrl+j` | Next result |
| `Ctrl+k` | Previous result |

---

## opencode — AI Coding Agent

Terminal-native AI coding assistant. Launches an interactive session for code generation, refactoring, and Q&A.

| Command | Action |
|---------|--------|
| `opencode` | Launch interactive session |

---

## herdr — Workspace Orchestrator

Markdown TUI reader and workflow coordinator. Manages sessions, renders docs/cheatsheets, and launches the right tool at the right time.

| Command / Key | Action |
|---------------|--------|
| `herdr <file>` | Open markdown file |
| `herdr --cheatsheet <file>` | Open in cheatsheet mode |
| `Arrow keys` / `h/j/k/l` | Navigate |
| `q` / `Esc` | Quit |
| `?` | Help |

---

## Quick Reference

| Task | Command |
|------|---------|
| Open this guide | `herdr ~/.config/herdr/TERMINAL_IDE_SETUP.md` |
| Recall previous command | `Up Arrow` (Atuin, directory-scoped) |
| Browse files | `yazi` |
| Edit a file | `micro <file>` |
| Git workflow | `lazygit` |
| Review diffs | `hunk` |
| AI assistance | `opencode` |
| Set default editor | `export EDITOR=micro` (already in `~/.zshrc`) |

---

*Maintained by Ivan Lyutskanov · [GitHub](https://github.com/ivan-lyutskanov/terminal-bootstrap)*
