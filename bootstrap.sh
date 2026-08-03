#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${BLUE}==> Starting Dev Setup Bootstrap...${NC}"

# Helper function to check command existence
is_installed() {
    command -v "$1" &> /dev/null
}

# Determine shell RC file early (needed for brew PATH persistence)
SHELL_RC="$HOME/.zshrc"
[[ "$SHELL" == *"/bash"* ]] && SHELL_RC="$HOME/.bashrc"

# 1. Package Manager Setup
if ! is_installed brew; then
    echo -e "${BLUE}==> Installing Homebrew...${NC}"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # After install, detect brew binary and configure PATH for the running shell
    for BREW_BIN in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
        if [ -x "$BREW_BIN" ]; then
            eval "$("$BREW_BIN" shellenv)"
            # Persist to shell RC so future sessions also find brew
            if ! grep -q 'brew shellenv' "$SHELL_RC" 2>/dev/null; then
                {
                    echo ''
                    echo '# Homebrew'
                    echo "eval \"\$($BREW_BIN shellenv)\""
                } >> "$SHELL_RC"
            fi
            break
        fi
    done
fi

# 2. Update Homebrew before installing tools
echo -e "${BLUE}==> Updating Homebrew...${NC}"
brew update

# 3. Core TUI Tools Installation
echo -e "${BLUE}==> Checking and installing TUI tools...${NC}"

TOOLS_TO_BREW=()
for tool in micro yazi lazygit atuin node herdr hunk opencode; do
    if ! is_installed "$tool"; then
        TOOLS_TO_BREW+=("$tool")
    else
        echo -e "${YELLOW}  - $tool is already installed. Skipping.${NC}"
    fi
done

if [ ${#TOOLS_TO_BREW[@]} -ne 0 ]; then
    brew install "${TOOLS_TO_BREW[@]}"
fi

# 4. Set Micro as Default Editor
if ! grep -q 'EDITOR="micro"' "$SHELL_RC" 2>/dev/null; then
    echo -e "${BLUE}==> Configuring Micro as default editor in $SHELL_RC...${NC}"
    {
      echo ''
      echo '# Custom Editor Settings'
      echo 'export EDITOR="micro"'
      echo 'export VISUAL="micro"'
      echo 'alias vim="micro"'
    } >> "$SHELL_RC"
    export EDITOR="micro"
    export VISUAL="micro"
fi

# 5. Atuin Directory-Scoped History Setup
mkdir -p "$HOME/.config/atuin"

# Only write config if it doesn't already exist (idempotent)
if [ ! -f "$HOME/.config/atuin/config.toml" ]; then
    cat << 'EOF' > "$HOME/.config/atuin/config.toml"
search_mode = "prefix"
up_key_dir_scoped = true
style = "compact"
inline_height = 20
EOF
fi

if ! grep -q "atuin init" "$SHELL_RC" 2>/dev/null; then
    echo -e "${BLUE}==> Wiring Atuin into shell environment...${NC}"
    if [[ "$SHELL" == *"/bash"* ]]; then
        { echo 'eval "$(atuin init bash)"'; } >> "$SHELL_RC"
    else
        {
            echo 'eval "$(atuin init zsh --disable-up-arrow)"'
            echo 'bindkey "^[[A" atuin-up-search-vicmd'
            echo 'bindkey "^[[A" atuin-up-search'
        } >> "$SHELL_RC"
    fi
fi

# 6. Configure OpenCode Skill: Hunk Agent Workflow
echo -e "${BLUE}==> Configuring OpenCode skill for Hunk review workflow...${NC}"
OPENCODE_SKILL_DIR="$HOME/.config/opencode/skills/hunk-review"
mkdir -p "$OPENCODE_SKILL_DIR"

if [ ! -f "$OPENCODE_SKILL_DIR/SKILL.md" ]; then
    cat << 'EOF' > "$OPENCODE_SKILL_DIR/SKILL.md"
# Skill: Interactive Diff & Chunk Review via Hunk

This workflow instructs OpenCode on how to inspect staged/unstaged changes using `hunk`.

## Workflow Guidelines
1. **Interactive Inspection:**
   - Run `hunk` to launch the TUI for reviewing granular code diffs.
   - Use `hunk diff` or `hunk patch` to review specific hunks before making modifications or committing.

2. **Patch & Staging Strategy:**
   - Do not stage entire files blindly with `git add .`.
   - Use `hunk` interactive staging to split changes into logical units.
   - When summarizing edits to the user, group changes by the specific hunks/patches modified.

3. **Editor Preference:**
   - Default terminal editor is `micro`. Never spawn `vim` or `nano` subshells.
EOF
else
    echo -e "${YELLOW}  - Hunk review skill already exists. Skipping.${NC}"
fi

# 7. Create Onboarding Markdown Guide
GUIDE_PATH="$HOME/.config/herdr/onboarding.md"
mkdir -p "$(dirname "$GUIDE_PATH")"

cat << 'EOF' > "$GUIDE_PATH"
# 🚀 Terminal IDE — Welcome

Your terminal IDE is ready. All tools installed natively via Homebrew.

---

## 🛠️ Tools & Key Shortcuts

### micro — Text Editor
Syntax highlighting, intuitive Ctrl shortcuts. Your default `$EDITOR`.

| Shortcut | Action |
|----------|--------|
| `Ctrl+s` / `Ctrl+q` | Save / Quit |
| `Ctrl+f` | Find |
| `Ctrl+z` / `Ctrl+y` | Undo / Redo |
| `Ctrl+g` | Go to line |
| `Ctrl+k` | Cut line |

### yazi — File Manager
Fast file browser with previews (images, PDFs, archives). Vim-like navigation.

| Shortcut | Action |
|----------|--------|
| `h` / `l` | Parent / enter dir |
| `j` / `k` | Down / up |
| `Enter` | Open file (in micro) |
| `/` | Fuzzy search |
| `.` | Toggle hidden |
| `q` | Quit |

### lazygit — Git TUI
Visual staging, commits, push/pull, interactive rebase.

| Shortcut | Action |
|----------|--------|
| `Space` | Stage / unstage |
| `c` | Commit |
| `P` / `p` | Push / Pull |
| `?` | Help |
| `q` | Quit |

### hunk — Interactive Diffs
Granular hunk-by-hunk diff review and selective staging.

| Command | Action |
|---------|--------|
| `hunk` | Review unstaged |
| `hunk --cached` | Review staged |

### atuin — Shell History
Directory-scoped history search. **Up Arrow** finds commands from current dir.

| Shortcut | Action |
|----------|--------|
| `Up Arrow` | Search (this dir) |
| `Ctrl+r` | Search (global) |

### opencode — AI Coding Agent
Terminal-native AI assistant. Run `opencode` to start.

### herdr — Workspace Orchestrator
Markdown reader & workflow coordinator. Run `herdr <file>` to view docs.

---

## 🔑 AI Token Keychain

Set up API keys using your OS keychain:

**macOS:**
```bash
security add-generic-password -a "$USER" -s "OPENAI_API_KEY" -w "your-key"
# In .zshrc:
export OPENAI_API_KEY=$(security find-generic-password -a "$USER" -s "OPENAI_API_KEY" -w)
```

**Linux:**
```bash
secret-tool store --name="OpenAI Key" service openai username "$USER"
# In shell:
export OPENAI_API_KEY=$(secret-tool lookup service openai username "$USER")
```

---

## 📚 Full Guide

`herdr ~/.config/herdr/TERMINAL_IDE_SETUP.md`

*Press `q` to close.*
EOF

SETUP_GUIDE="$HOME/.config/herdr/TERMINAL_IDE_SETUP.md"
cp "$(dirname "$0")/TERMINAL_IDE_SETUP.md" "$SETUP_GUIDE" 2>/dev/null || true

echo -e "${GREEN}==> Setup completed successfully!${NC}"
echo -e ""
echo -e "${BLUE}📚 Complete Setup Guide:${NC} ${YELLOW}$SETUP_GUIDE${NC}"
echo -e "${BLUE}🔗 Or view online:${NC} https://github.com/ivan-lyutskanov/terminal-bootstrap/blob/master/TERMINAL_IDE_SETUP.md"
echo -e ""
