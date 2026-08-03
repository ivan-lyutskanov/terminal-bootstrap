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

# 1. Package Manager Setup
if ! is_installed brew; then
    echo -e "${BLUE}==> Installing Homebrew...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# 2. Core TUI Tools Installation
echo -e "${BLUE}==> Checking and installing TUI tools...${NC}"

TOOLS_TO_BREW=()
for tool in micro yazi lazygit atuin node; do
    if ! is_installed "$tool"; then
        TOOLS_TO_BREW+=("$tool")
    else
        echo -e "${YELLOW}  - $tool is already installed. Skipping.${NC}"
    fi
done

if [ ${#TOOLS_TO_BREW[@]} -ne 0 ]; then
    brew install "${TOOLS_TO_BREW[@]}"
fi

# 3. Rust Toolchain (required to build hunk & herdr)
if ! is_installed cargo; then
    echo -e "${BLUE}==> Installing Rust toolchain (required for hunk/herdr)...${NC}"
    brew install rust
    # Ensure cargo is in PATH
    export PATH="$(brew --prefix rust)/bin:$PATH"
fi

# Install hunk and herdr via Cargo if missing
if ! is_installed hunk; then
    echo -e "${BLUE}==> Installing hunk via Cargo...${NC}"
    cargo install --git https://github.com/modem-dev/hunk
fi

if ! is_installed herdr; then
    echo -e "${BLUE}==> Installing herdr via Cargo...${NC}"
    cargo install --git https://github.com/herdrdev/herdr || true
fi

# 4. OpenCode Agent Setup
if ! is_installed opencode; then
    echo -e "${BLUE}==> Installing OpenCode...${NC}"
    npm install -g opencode-ai
else
    echo -e "${YELLOW}  - opencode is already installed. Skipping.${NC}"
fi

# 5. Set Micro as Default Editor
SHELL_RC="$HOME/.zshrc"
[[ "$SHELL" == *"/bash"* ]] && SHELL_RC="$HOME/.bashrc"

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

# 6. Atuin Directory-Scoped History Setup
mkdir -p "$HOME/.config/atuin"
cat << 'EOF' > "$HOME/.config/atuin/config.toml"
search_mode = "prefix"
up_key_dir_scoped = true
style = "compact"
inline_height = 20
EOF

if ! grep -q "atuin init" "$SHELL_RC" 2>/dev/null; then
    echo -e "${BLUE}==> Wiring Atuin into shell environment...${NC}"
    {
      echo 'eval "$(atuin init zsh --disable-up-arrow)"'
      echo 'bindkey "^[[A" atuin-up-search-vicmd'
      echo 'bindkey "^[[A" atuin-up-search'
    } >> "$SHELL_RC"
fi

# 7. Configure OpenCode Skill: Hunk Agent Workflow
echo -e "${BLUE}==> Configuring OpenCode skill for Hunk review workflow...${NC}"
OPENCODE_SKILLS_DIR="$HOME/.config/opencode/skills"
mkdir -p "$OPENCODE_SKILLS_DIR"

cat << 'EOF' > "$OPENCODE_SKILLS_DIR/hunk_review.md"
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

# 8. Create Onboarding Markdown Guide
GUIDE_PATH="$HOME/.config/herdr/onboarding.md"
mkdir -p "$(dirname "$GUIDE_PATH")"

cat << 'EOF' > "$GUIDE_PATH"
# 🚀 Terminal Environment Cheatsheet

Welcome to your environment setup. All tools are installed natively on your host machine.

---

## 🛠️ Installed CLI Tools

| Tool | Role | Command / Keybinding |
| :--- | :--- | :--- |
| **Micro** | Default Text Editor | `micro <file>` (Ctrl+S Save, Ctrl+Q Quit) |
| **Yazi** | TUI File Manager | `yazi` |
| **LazyGit** | Terminal Git Client | `lazygit` |
| **Atuin** | History Search | **Up Arrow** (scoped to local directory) |
| **Hunk** | Diff & Patch Review | `hunk` |
| **OpenCode** | AI Coding Agent | `opencode` |

---

## 🔑 AI Token Keychain Configuration

Set up platform secrets (OpenAI, Anthropic) using your OS keychain:

### macOS (Native Keychain)
```bash
# Add key to Keychain:
security add-generic-password -a "$USER" -s "OPENAI_API_KEY" -w "your-api-key"

# Read in .zshrc:
export OPENAI_API_KEY=$(security find-generic-password -a "$USER" -s "OPENAI_API_KEY" -w)
```

### Linux (Secret Tool)
```bash
# Store key:
secret-tool store --name="OpenAI Key" service openai username "$USER"

# Retrieve in shell:
export OPENAI_API_KEY=$(secret-tool lookup service openai username "$USER")
```

---

## 🤖 OpenCode Skills Active
- **Hunk Workflow**: `~/.config/opencode/skills/hunk_review.md`

*Press `q` or `Ctrl+C` to close Herdr when finished.*
EOF

echo -e "${GREEN}==> Setup completed successfully! Launching Herdr...${NC}"

# Launch Herdr with the guide, fallback to micro if herdr fails
herdr "$GUIDE_PATH" || micro "$GUIDE_PATH"
